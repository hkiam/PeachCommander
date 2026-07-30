// AIChatViewController.swift - the AI assistant, as an embeddable view.
//
// The chat lives in a docked side panel (right column of the main window), not a
// floating window: it sits next to the file panels, picks up the active folder /
// selection as context automatically, and its clickable path results navigate the
// panel beside it. It runs over a SessionManager (parallel, persisted sessions) with
// a switcher (New / Rename… / Delete), plan-then-confirm for gated writes, and a
// hard-stoppable, time-bounded run loop so a slow or stuck model can never freeze the
// UI. Fully localized. Provider-agnostic; the opener injects the provider.

import AppKit
import PCAutomation
import Speech
import AVFoundation

/// A Sendable bridge so a native (Apple) tool session — built in a `@Sendable` factory
/// before the view exists — can route plan-then-confirm to the chat view once it does.
final class ConfirmationRelay: ConfirmationBroker, @unchecked Sendable {
    weak var target: AIChatViewController?
    func confirmPlan(_ plan: String) async -> Bool { await target?.confirmPlan(plan) ?? false }
    func reportProgress(_ toolName: String) async { await target?.nativeActivity(toolName) }
    func reportPartial(_ text: String) async { await target?.streamPartial(text) }
}

@MainActor
final class AIChatViewController: NSViewController, NSTextFieldDelegate, NSTextViewDelegate, ConfirmationBroker {
    private let manager: SessionManager
    private let providerName: String
    private let contextProvider: (@MainActor () async -> ChatContext?)?
    private let onOpenPath: (@MainActor (String) -> Void)?
    /// Supplies the current autonomy policy so a Settings change takes effect on the
    /// next turn (the policy is otherwise fixed when a session is built).
    private let policyProvider: (@MainActor () async -> PermissionPolicy)?

    private var currentSession: AgentSession?
    private var currentSessionId: String?
    private var sessions: [SessionInfo] = []
    private var pendingTokens: [String] = []
    private var attachments: [String] = []

    // Run state: a generation token lets a Stop or timeout free the UI immediately and
    // makes any late result from an un-cancellable model call be discarded as stale.
    private var busy = false
    private var runGeneration = 0
    private var currentRunId: String?
    private var watchdog: Task<Void, Never>?
    private static let runTimeout: UInt64 = 120 * 1_000_000_000   // 120s watchdog
    // Native (Apple) plan-then-confirm suspends the turn here until the user decides.
    private var nativeConfirm: CheckedContinuation<Bool, Never>?
    // Streaming: index in the transcript where the growing assistant answer body starts
    // (nil = no answer streaming right now).
    private var streamBodyStart: Int?

    private let sessionPopup = NSPopUpButton()
    private let deletePopup = NSPopUpButton()
    private let attachButton = NSPopUpButton()
    private let attachLabel = NSTextField(labelWithString: "")
    private let transcript = NSTextView()
    private let input = NSTextField()
    private let sendButton = NSButton()
    private let stopButton = NSButton()
    private let micButton = NSButton()
    // Voice input (dictation into the input field).
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var dictating = false
    private let spinner = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")
    private let confirmBar = NSStackView()

    init(manager: SessionManager, providerName: String,
         contextProvider: (@MainActor () async -> ChatContext?)? = nil,
         onOpenPath: (@MainActor (String) -> Void)? = nil,
         policyProvider: (@MainActor () async -> PermissionPolicy)? = nil) {
        self.manager = manager
        self.providerName = providerName
        self.contextProvider = contextProvider
        self.onOpenPath = onOpenPath
        self.policyProvider = policyProvider
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }

    // MARK: - Lifecycle

    /// Load the session index (creating one if none), select the first, and render it.
    func start() async {
        await manager.loadIndex()
        var list = await manager.list()
        if list.isEmpty { _ = await manager.create(title: Self.newChatTitle); list = await manager.list() }
        sessions = list
        rebuildPopup()
        if let first = list.first { await switchTo(id: first.id) }
    }

    /// When the panel is hidden/closed: cancel any run and prune empty sessions so
    /// unused "New chat" entries don't pile up on disk.
    func panelDidHide() {
        cancelActiveRun()
        let keep = currentSessionId
        Task { await manager.deleteEmptySessions(keeping: keep); sessions = await manager.list(); rebuildPopup() }
    }

    func focusInput() { view.window?.makeFirstResponder(input) }

    /// DEBUG: dump the current transcript + model label to the log (host verification).
    func dumpTranscriptToLog() {
        NSLog("[aidump] provider=%@ BEGIN\n%@\n[aidump] END", providerName, transcript.string)
    }

    // DEBUG: drive the confirm bar from the automation hook (host verification of the
    // plan-then-confirm flow). Each logs whether a confirmation was actually pending.
    func debugConfirm() { NSLog("[aidebug] confirm (pending=%@)", nativeConfirm != nil ? "yes" : "no"); confirmTapped() }
    func debugCancel()  { NSLog("[aidebug] cancel (pending=%@)",  nativeConfirm != nil ? "yes" : "no"); cancelTapped() }
    func debugStop()    { NSLog("[aidebug] stop"); stopTapped() }

    func cancelActiveRun() {
        guard busy else { return }
        runGeneration += 1
        watchdog?.cancel(); watchdog = nil
        resolveNativeConfirm(false)
        finalizeStreamIfActive()
        busy = false
        setBusyUI(false)
    }

    private static let newChatTitle = String(localized: "New chat", comment: "AI: default session title")

    // MARK: - View

    override func loadView() {
        let content = NSView()

        sessionPopup.target = self
        sessionPopup.action = #selector(sessionPopupChanged)
        let newButton = NSButton(title: String(localized: "New", comment: "AI: new session"),
                                 target: self, action: #selector(newChatTapped))
        newButton.bezelStyle = .rounded
        let renameButton = NSButton(title: String(localized: "Rename…", comment: "AI: rename session"),
                                    target: self, action: #selector(renameTapped))
        renameButton.bezelStyle = .rounded
        deletePopup.pullsDown = true
        deletePopup.addItems(withTitles: [
            String(localized: "Delete ▾", comment: "AI: delete menu"),
            String(localized: "Delete this chat", comment: "AI: delete current session"),
            String(localized: "Delete all chats", comment: "AI: delete all sessions")])
        deletePopup.bezelStyle = .rounded
        deletePopup.target = self
        deletePopup.action = #selector(deleteMenuChanged)
        let topRow = NSStackView(views: [sessionPopup, newButton, renameButton, deletePopup])
        topRow.orientation = .horizontal
        topRow.spacing = 6
        sessionPopup.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Attach-context row: attach the current selection / active folder to the next
        // message so the assistant acts on them without the user typing paths.
        attachButton.pullsDown = true
        attachButton.addItems(withTitles: [
            String(localized: "Attach ▾", comment: "AI: attach context menu"),
            String(localized: "Current selection", comment: "AI: attach the selected files"),
            String(localized: "Active folder", comment: "AI: attach the active folder")])
        attachButton.target = self
        attachButton.action = #selector(attachChanged)
        attachLabel.textColor = .secondaryLabelColor
        attachLabel.font = .systemFont(ofSize: 11)
        attachLabel.lineBreakMode = .byTruncatingMiddle
        let attachRow = NSStackView(views: [attachButton, attachLabel])
        attachRow.orientation = .horizontal
        attachRow.spacing = 8
        attachLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        statusLabel.stringValue = modelStatus(thinking: false)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        let statusRow = NSStackView(views: [spinner, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        transcript.isEditable = false
        transcript.isRichText = true
        transcript.isSelectable = true
        transcript.delegate = self
        transcript.textContainerInset = NSSize(width: 8, height: 8)
        let scroll = NSScrollView()
        scroll.documentView = transcript
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        input.placeholderString = String(localized: "Ask the assistant to do something…", comment: "AI: input placeholder")
        input.delegate = self
        input.target = self
        input.action = #selector(sendTapped)
        sendButton.title = String(localized: "Send", comment: "AI: send button")
        sendButton.bezelStyle = .rounded
        sendButton.target = self
        sendButton.action = #selector(sendTapped)
        sendButton.keyEquivalent = "\r"
        stopButton.title = String(localized: "Stop", comment: "AI: stop the running request")
        stopButton.bezelStyle = .rounded
        stopButton.target = self
        stopButton.action = #selector(stopTapped)
        stopButton.isHidden = true
        micButton.title = "🎤"
        micButton.bezelStyle = .rounded
        micButton.setButtonType(.pushOnPushOff)
        micButton.toolTip = String(localized: "Voice input", comment: "AI: dictation button")
        micButton.target = self
        micButton.action = #selector(micTapped)
        micButton.isHidden = (speechRecognizer == nil)   // hide if speech isn't available
        let inputRow = NSStackView(views: [input, micButton, sendButton, stopButton])
        inputRow.orientation = .horizontal
        inputRow.spacing = 8
        input.setContentHuggingPriority(.defaultLow, for: .horizontal)

        confirmBar.orientation = .horizontal
        confirmBar.spacing = 8
        confirmBar.isHidden = true
        confirmBar.addArrangedSubview(NSTextField(labelWithString:
            String(localized: "The assistant wants to make changes.", comment: "AI: confirm prompt")))
        confirmBar.addArrangedSubview(NSButton(title: String(localized: "Cancel", comment: "AI: cancel changes"),
                                               target: self, action: #selector(cancelTapped)))
        let confirmButton = NSButton(title: String(localized: "Confirm & run", comment: "AI: confirm changes"),
                                     target: self, action: #selector(confirmTapped))
        confirmButton.bezelStyle = .rounded
        confirmBar.addArrangedSubview(confirmButton)

        var rows: [NSView] = [topRow]
        if contextProvider != nil { rows.append(attachRow) }
        rows += [statusRow, scroll, confirmBar, inputRow]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        self.view = content
    }

    private func modelStatus(thinking: Bool) -> String {
        thinking
            ? String(format: String(localized: "Model: %@ — thinking…", comment: "AI: busy status"), providerName)
            : String(format: String(localized: "Model: %@", comment: "AI: idle status"), providerName)
    }

    private func rebuildPopup() {
        sessionPopup.removeAllItems()
        sessionPopup.addItems(withTitles: sessions.map(\.title))
        selectCurrentInPopup()
    }
    private func selectCurrentInPopup() {
        if let id = currentSessionId, let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessionPopup.selectItem(at: idx)
        }
    }

    // MARK: - Session actions

    @objc private func sessionPopupChanged() {
        let idx = sessionPopup.indexOfSelectedItem
        guard sessions.indices.contains(idx) else { return }
        let id = sessions[idx].id
        Task { await switchTo(id: id) }
    }

    @objc private func newChatTapped() {
        Task {
            let session = await manager.create(title: Self.newChatTitle)
            sessions = await manager.list()
            rebuildPopup()
            await switchTo(id: session.id)
            focusInput()
        }
    }

    @objc private func renameTapped() {
        guard let id = currentSessionId else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Rename session", comment: "AI: rename dialog title")
        let field = NSTextField(string: sessions.first { $0.id == id }?.title ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: String(localized: "Rename", comment: "AI: rename confirm"))
        alert.addButton(withTitle: String(localized: "Cancel", comment: "AI: cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Task {
            await manager.rename(id: id, to: title)
            sessions = await manager.list()
            rebuildPopup()
        }
    }

    @objc private func deleteTapped() {
        guard let id = currentSessionId else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Delete this conversation?", comment: "AI: delete confirm title")
        alert.informativeText = String(localized: "This permanently removes the conversation and its history.",
                                       comment: "AI: delete confirm body")
        alert.addButton(withTitle: String(localized: "Delete", comment: "AI: delete session"))
        alert.addButton(withTitle: String(localized: "Cancel", comment: "AI: cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        cancelActiveRun()
        Task {
            await manager.delete(id: id)
            var list = await manager.list()
            if list.isEmpty { _ = await manager.create(title: Self.newChatTitle); list = await manager.list() }
            sessions = list
            rebuildPopup()
            if let first = list.first { await switchTo(id: first.id) }
        }
    }

    @objc private func deleteMenuChanged() {
        let idx = deletePopup.indexOfSelectedItem
        deletePopup.selectItem(at: 0)   // reset the pull-down title
        if idx == 1 { deleteTapped() }
        else if idx == 2 { deleteAllTapped() }
    }

    @objc private func deleteAllTapped() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Delete all chats?", comment: "AI: delete all confirm title")
        alert.informativeText = String(localized: "This permanently removes every conversation and its history.",
                                       comment: "AI: delete all confirm body")
        alert.addButton(withTitle: String(localized: "Delete all chats", comment: "AI: delete all sessions"))
        alert.addButton(withTitle: String(localized: "Cancel", comment: "AI: cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        cancelActiveRun()
        Task {
            await manager.deleteAll()
            let fresh = await manager.create(title: Self.newChatTitle)
            sessions = await manager.list()
            rebuildPopup()
            await switchTo(id: fresh.id)
        }
    }

    /// Start a FRESH chat with the given title and send `prompt` into it — used by the
    /// "AI ▸" context-menu actions so each is its own conversation (not piled into one).
    func sendInNewChat(_ prompt: String, title: String) {
        Task {
            let session = await manager.create(title: title)
            sessions = await manager.list()
            rebuildPopup()
            await switchTo(id: session.id)
            await submit(prompt)
        }
    }

    private func switchTo(id: String) async {
        // Don't tear a conversation out from under a running request.
        cancelActiveRun()
        pendingTokens = []; confirmBar.isHidden = true
        guard let session = await manager.session(id: id) else { return }
        currentSession = session
        currentSessionId = id
        renderHistory(await session.history)
        selectCurrentInPopup()
    }

    // MARK: - Sending

    @objc private func sendTapped() {
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !busy else {
            NSSound.beep()   // clear feedback that a request is already running
            return
        }
        input.stringValue = ""
        Task { await submit(text) }
    }

    // MARK: - Voice input (dictation)

    @objc private func micTapped() {
        if dictating { stopDictation() } else { startDictation() }
    }

    private func startDictation() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { NSSound.beep(); return }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                guard status == .authorized else { self.micButton.state = .off; NSSound.beep(); return }
                do { try self.beginAudio(recognizer) } catch { self.micButton.state = .off; NSSound.beep() }
            }
        }
    }

    private func beginAudio(_ recognizer: SFSpeechRecognizer) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buf, _ in request?.append(buf) }
        audioEngine.prepare()
        try audioEngine.start()
        dictating = true
        micButton.state = .on
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result { self.input.stringValue = result.bestTranscription.formattedString }
            if error != nil || (result?.isFinal ?? false) { self.stopDictation() }
        }
    }

    private func stopDictation() {
        guard dictating else { return }
        dictating = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        micButton.state = .off
        view.window?.makeFirstResponder(input)
    }

    @objc private func attachChanged() {
        let idx = attachButton.indexOfSelectedItem
        attachButton.selectItem(at: 0)
        Task {
            guard let ctx = await contextProvider?() else { return }
            if idx == 1 { attachments = ctx.selection }
            else if idx == 2 { attachments = [ctx.folder] }
            updateAttachLabel()
        }
    }

    private func updateAttachLabel() {
        if attachments.isEmpty { attachLabel.stringValue = ""; return }
        let names = attachments.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
        attachLabel.stringValue = String(format: String(localized: "Attached: %@", comment: "AI: attached files label"), names)
    }

    /// Compose the user's text with context + attachments, show it, and run the turn.
    private func submit(_ userText: String) async {
        guard !busy else { return }
        append(role: youLabel, text: userText)
        let context = await contextProvider?()
        let attached = attachments
        attachments = []; updateAttachLabel()
        let composed = ChatComposer.compose(userText: userText, context: context, attachments: attached)
        beginRun { try await $0.send(composed) }
    }

    @objc private func confirmTapped() {
        // Native path: a turn is suspended awaiting this decision.
        if nativeConfirm != nil { resolveNativeConfirm(true); return }
        // Text path: resume the loop with confirmed tokens.
        guard !busy, !pendingTokens.isEmpty else { return }
        let tokens = pendingTokens
        pendingTokens = []
        confirmBar.isHidden = true
        beginRun { try await $0.confirm(tokens: tokens) }
    }

    @objc private func cancelTapped() {
        if nativeConfirm != nil { resolveNativeConfirm(false); return }
        pendingTokens = []
        confirmBar.isHidden = true
        append(role: assistantLabel, text: String(localized: "Okay, I won’t make those changes.", comment: "AI: declined changes"))
    }

    /// Programmatic send (used by the DEBUG automation verb for verification).
    func sendProgrammatically(_ text: String) async {
        if currentSession == nil { await start() }
        await submit(text)
    }

    /// "Make a table" action → its own fresh chat (read a file, show a guided table).
    func sendTableRequest(path: String, displayName: String) {
        Task {
            let session = await manager.create(title: String(format: String(localized: "Table: %@", comment: "AI: table chat title"), displayName))
            sessions = await manager.list()
            rebuildPopup()
            await switchTo(id: session.id)
            append(role: youLabel, text: String(format: String(localized: "Make a table from %@", comment: "AI: table request"), displayName))
            beginRun { try await $0.makeTableFromFile(path, displayName: displayName) }
        }
    }

    // MARK: - Run loop (time-bounded, hard-stoppable)

    private enum RunOutcome { case result(AgentSession.Result); case failed(Error); case timedOut }

    /// Start an agent turn against the current session. A watchdog and the Stop button
    /// both free the UI immediately via the generation token; a late result from an
    /// un-cancellable model call is discarded as stale.
    private func beginRun(_ work: @escaping (AgentSession) async throws -> AgentSession.Result) {
        guard !busy, let session = currentSession, let id = currentSessionId else { return }
        busy = true
        runGeneration += 1
        let gen = runGeneration
        currentRunId = id
        setBusyUI(true)
        armWatchdog(gen: gen, id: id)

        // Live activity: surface each tool the assistant runs in the status line.
        Task { await session.setProgressHandler { [weak self] name in await self?.showActivity(name, gen: gen) } }
        // Stream the final answer live on the text/cloud path (native path streams via the relay).
        Task { await session.setPartialHandler { [weak self] text in await self?.streamPartial(text) } }
        Task { [weak self] in
            do {
                // Refresh the policy so a Settings autonomy change applies to this turn.
                if let p = await self?.policyProvider?() { await session.setPolicy(p) }
                await self?.finish(gen: gen, id: id, outcome: .result(try await work(session)))
            } catch { await self?.finish(gen: gen, id: id, outcome: .failed(error)) }
        }
    }

    /// (Re)arm the timeout watchdog. Paused while awaiting the user's confirmation so
    /// think-time never counts against the model's time budget.
    private func armWatchdog(gen: Int, id: String) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            // IMPORTANT: distinguish a real timeout from cancellation. `try?` would
            // swallow the CancellationError and fall through to finish(.timedOut), so a
            // cancel (e.g. pausing for confirmation) would spuriously fire the timeout.
            do { try await Task.sleep(nanoseconds: Self.runTimeout) } catch { return }
            if Task.isCancelled { return }
            await self?.finish(gen: gen, id: id, outcome: .timedOut)
        }
    }

    private func finish(gen: Int, id: String, outcome: RunOutcome) async {
        guard gen == runGeneration, busy else { return }   // stale: stopped / superseded / already done
        watchdog?.cancel(); watchdog = nil
        busy = false
        setBusyUI(false)
        switch outcome {
        case .result(let result):
            // A streamed answer is already shown live; just finalize the bubble.
            if case .answer(let text) = result, streamBodyStart != nil {
                finalizeStreamIfActive(replaceWith: text)
            } else {
                render(result)
            }
            await manager.persist(id: id)
        case .failed(let error):
            finalizeStreamIfActive()   // close any partial bubble
            append(role: assistantLabel, text: String(format: String(localized: "Error: %@", comment: "AI: error line"),
                                                       error.localizedDescription))
        case .timedOut:
            finalizeStreamIfActive()
            append(role: assistantLabel, text: String(localized: "The assistant took too long, so I stopped. Please try again or rephrase.",
                                                       comment: "AI: timeout message"))
        }
    }

    @objc private func stopTapped() {
        guard busy else { return }
        runGeneration += 1   // invalidate the in-flight run
        watchdog?.cancel(); watchdog = nil
        resolveNativeConfirm(false)   // unblock a suspended native turn (if any)
        finalizeStreamIfActive()      // close any partial streamed bubble
        busy = false
        setBusyUI(false)
        append(role: assistantLabel, text: String(localized: "Stopped.", comment: "AI: stopped by user"))
    }

    // MARK: - Native (Apple) plan-then-confirm broker

    /// Resolve a pending native confirmation, re-arming the watchdog if the turn resumes.
    private func resolveNativeConfirm(_ ok: Bool) {
        guard let cont = nativeConfirm else { return }
        nativeConfirm = nil
        confirmBar.isHidden = true
        if ok, busy, let id = currentRunId { armWatchdog(gen: runGeneration, id: id) }
        cont.resume(returning: ok)
    }

    private func setBusyUI(_ on: Bool) {
        sendButton.isHidden = on
        stopButton.isHidden = !on
        input.isEnabled = !on
        sessionPopup.isEnabled = !on
        if on { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
        statusLabel.stringValue = modelStatus(thinking: on)
    }

    /// Update the status line with the tool the assistant is currently running. Ignored
    /// once the run is superseded/stopped (stale generation).
    /// Progress from a native (Apple) turn, routed via the relay; shown if this is the
    /// live run.
    func nativeActivity(_ toolName: String) { showActivity(toolName, gen: runGeneration) }

    private static let bodyAttrs: [NSAttributedString.Key: Any] =
        [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor]

    /// Stream the assistant's answer live: start an assistant bubble on the first partial,
    /// then replace its body with each cumulative snapshot.
    func streamPartial(_ text: String) {
        guard busy, let ts = transcript.textStorage else { return }
        if streamBodyStart == nil {
            ts.append(NSAttributedString(string: "\(assistantLabel): ", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor]))
            streamBodyStart = ts.length
        }
        let start = streamBodyStart ?? ts.length
        let range = NSRange(location: start, length: max(0, ts.length - start))
        ts.replaceCharacters(in: range, with: NSAttributedString(string: text, attributes: Self.bodyAttrs))
        transcript.scrollToEndOfDocument(nil)
    }

    /// Close off a streamed bubble. If `replaceWith` is given, the body is replaced with
    /// that final text; otherwise the partial text so far is kept. Returns true if a
    /// stream was in progress (so the caller shouldn't append the answer again).
    @discardableResult
    private func finalizeStreamIfActive(replaceWith finalText: String? = nil) -> Bool {
        guard let start = streamBodyStart, let ts = transcript.textStorage else { return false }
        if let finalText {
            let shown = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(location: start, length: max(0, ts.length - start))
            ts.replaceCharacters(in: range, with: NSAttributedString(
                string: shown.isEmpty ? String(localized: "I couldn’t produce a clear answer. Please try again or rephrase.", comment: "AI: empty answer fallback") : shown,
                attributes: Self.bodyAttrs))
        }
        ts.append(NSAttributedString(string: "\n\n", attributes: Self.bodyAttrs))
        streamBodyStart = nil
        transcript.scrollToEndOfDocument(nil)
        return true
    }

    private func showActivity(_ toolName: String, gen: Int) {
        guard gen == runGeneration, busy else { return }
        statusLabel.stringValue = String(format: String(localized: "Model: %1$@ — %2$@", comment: "AI: model + current activity"),
                                          providerName, Self.friendlyActivity(toolName))
    }

    private static func friendlyActivity(_ tool: String) -> String {
        switch tool {
        case "get_context":     return String(localized: "checking the current folder…", comment: "AI activity")
        case "list_directory":  return String(localized: "listing files…", comment: "AI activity")
        case "read_file":       return String(localized: "reading a file…", comment: "AI activity")
        case "search":          return String(localized: "searching…", comment: "AI activity")
        case "stat":            return String(localized: "inspecting a file…", comment: "AI activity")
        case "get_config", "list_commands", "list_plugins":
                                return String(localized: "looking things up…", comment: "AI activity")
        case "copy", "move", "rename", "make_directory", "set_config", "move_to_trash", "delete_permanently":
                                return String(localized: "preparing changes…", comment: "AI activity")
        default:                return String(localized: "working…", comment: "AI activity")
        }
    }

    // MARK: - Render

    private var youLabel: String { String(localized: "You", comment: "AI: user role label") }
    private var assistantLabel: String { String(localized: "Assistant", comment: "AI: assistant role label") }

    private func render(_ result: AgentSession.Result) {
        switch result {
        case .answer(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            append(role: assistantLabel, text: trimmed.isEmpty
                   ? String(localized: "I couldn’t produce a clear answer. Please try again or rephrase.",
                            comment: "AI: empty answer fallback")
                   : trimmed)
        case .stopped(let reason): append(role: assistantLabel, text: reason)
        case .needsConfirmation(let plans):
            pendingTokens = plans.map(\.token)
            let header = String(localized: "I’d like to:", comment: "AI: plan header")
            let footer = String(localized: "Confirm to proceed.", comment: "AI: plan footer")
            append(role: assistantLabel,
                   text: header + "\n" + plans.map { "• \($0.plan)" }.joined(separator: "\n") + "\n\n" + footer)
            confirmBar.isHidden = false
        }
    }

    private func renderHistory(_ messages: [ModelMessage]) {
        transcript.textStorage?.setAttributedString(NSAttributedString(string: ""))
        let visible = messages.filter { $0.role != .system }
        if visible.isEmpty {
            append(role: assistantLabel, text: String(localized: "Hi! Tell me what to do with your files. I’ll show a plan before making any changes.",
                                                      comment: "AI: greeting"))
            return
        }
        for m in visible {
            let label: String
            switch m.role {
            case .user: label = youLabel
            case .tool: label = String(format: String(localized: "Tool (%@)", comment: "AI: tool role label"), m.toolName ?? "")
            default: label = assistantLabel
            }
            append(role: label, text: m.content)
        }
    }

    private func append(role: String, text: String) {
        let m = NSMutableAttributedString()
        m.append(NSAttributedString(string: "\(role): ", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor]))
        let bodyStart = m.length
        m.append(NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor]))
        for match in PathDetector.detect(in: text) {
            guard let encoded = match.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "pcfile://" + encoded) else { continue }
            m.addAttribute(.link, value: url,
                           range: NSRange(location: bodyStart + match.range.location, length: match.range.length))
        }
        m.append(NSAttributedString(string: "\n\n", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
        transcript.textStorage?.append(m)
        transcript.scrollToEndOfDocument(nil)
    }

    // MARK: - ConfirmationBroker (native path)

    /// Called from inside a native turn when a gated action needs approval. Shows the
    /// plan + confirm bar and suspends the turn until the user decides.
    func confirmPlan(_ plan: String) async -> Bool {
        watchdog?.cancel(); watchdog = nil   // don't time user think-time
        pendingTokens = []
        let header = String(localized: "I’d like to:", comment: "AI: plan header")
        let footer = String(localized: "Confirm to proceed.", comment: "AI: plan footer")
        append(role: assistantLabel, text: header + "\n• " + plan + "\n\n" + footer)
        confirmBar.isHidden = false
        return await withCheckedContinuation { cont in nativeConfirm = cont }
    }

    // Clicking a file link opens it in the active panel (or reveals it in Finder).
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        let url = (link as? URL) ?? (link as? String).flatMap { URL(string: $0) }
        guard let url, url.scheme == "pcfile" else { return false }
        let path = url.path
        guard !path.isEmpty else { return false }
        if let onOpenPath { onOpenPath(path) }
        else { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
        return true
    }
}
