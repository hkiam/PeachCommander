// SPDX-License-Identifier: Apache-2.0
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

/// One "AI ▸" action to run over several files.
struct BatchRequest {
    let skill: Skill
    let paths: [String]
    let title: String
}

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
    /// The tick list for a plan that has rows, above the Confirm bar (F-450). Empty for a plan that
    /// cannot be divided, and then nothing is shown — the plan text alone is what it always was.
    private let planRowsBox = NSStackView()
    /// One checkbox per row, tagged with its token and id so Confirm can collect what was unticked.
    private var planRowChecks: [(token: String, id: String, box: NSButton)] = []
    private var attachments: [String] = []
    /// A proposal on offer (rename). Accepting it is what carries it out.
    private var pendingSuggestion: AgentSession.Suggestion?

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
    private let actionsPopup = NSPopUpButton()
    private let attachButton = NSPopUpButton()
    private let attachLabel = NSTextField(labelWithString: "")
    /// Built on TextKit 1 deliberately: the answers contain tables, and `NSTextTable` (the
    /// only way to lay one out inside a text view) exists in TextKit 1 alone. A plain
    /// `NSTextView()` would be TextKit 2, where the table paragraph style is ignored and a
    /// table silently comes out as its cells in a column.
    private let transcript: NSTextView = {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer()
        container.widthTracksTextView = true
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let view = NSTextView(frame: .zero, textContainer: container)
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        return view
    }()
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
    /// Shown when the assistant proposes something applicable, with the proposal spelled out
    /// on the button: a suggestion the user has to retype is not a suggestion.
    private let suggestionBar = NSStackView()
    private let suggestionLabel = NSTextField(labelWithString: "")
    private let applyButton = NSButton()

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

    /// The conversation currently on screen, so a rebuild (after a settings change) can
    /// reopen the same one instead of dropping the user into the first in the list.
    var currentSessionIdentifier: String? { currentSessionId }

    /// Load the session index (creating one if none), select `resuming` if it is still there,
    /// otherwise the first, and render it.
    func start(resuming sessionId: String? = nil) async {
        await manager.loadIndex()
        var list = await manager.list()
        if list.isEmpty { _ = await manager.create(title: Self.newChatTitle); list = await manager.list() }
        sessions = list
        rebuildPopup()
        if let sessionId, list.contains(where: { $0.id == sessionId }) {
            await switchTo(id: sessionId)
        } else if let first = list.first {
            await switchTo(id: first.id)
        }
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

    /// DEBUG: show `markdown` as an assistant answer, then write a PNG of the chat panel.
    ///
    /// `PC_AI_PROBE` sends a real question to a real model, which is the right check for the
    /// conversation but the wrong one for the rendering: an image only appears in an answer that
    /// contains one, and no model was ever going to write the path of a file on this machine. So
    /// the text is *given* here, and what comes out is looked at — the transcript is drawn in this
    /// process, so the view can hand over its own picture without asking the machine for screen
    /// recording rights.
    func renderProbe(_ markdown: String, pngPath: String) {
        append(role: assistantLabel, text: markdown)
        view.layoutSubtreeIfNeeded()
        if let container = transcript.textContainer { transcript.layoutManager?.ensureLayout(for: container) }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            NSLog("[airender] no bitmap rep"); return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            NSLog("[airender] no png"); return
        }
        do {
            try png.write(to: URL(fileURLWithPath: pngPath))
            NSLog("[airender] wrote %.0fx%.0f to %@", view.bounds.width, view.bounds.height, pngPath)
        } catch {
            NSLog("[airender] write failed: %@", error.localizedDescription)
        }
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
        // What the assistant did, and taking it back. In the chat rather than in Settings,
        // because it is read in the moment something looks wrong.
        actionsPopup.pullsDown = true
        actionsPopup.addItems(withTitles: [
            String(localized: "Actions ▾", comment: "AI: actions menu"),
            String(localized: "Show what the assistant did…", comment: "AI: show the action log"),
            String(localized: "Undo the last change", comment: "AI: undo the last AI change")])
        actionsPopup.bezelStyle = .rounded
        actionsPopup.target = self
        actionsPopup.action = #selector(actionsMenuChanged)

        let topRow = NSStackView(views: [sessionPopup, newButton, renameButton, deletePopup, actionsPopup])
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

        suggestionBar.orientation = .horizontal
        suggestionBar.spacing = 8
        suggestionBar.isHidden = true
        suggestionLabel.font = .systemFont(ofSize: 11)
        suggestionLabel.lineBreakMode = .byTruncatingMiddle
        suggestionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applySuggestionTapped)
        let discardButton = NSButton(title: String(localized: "Discard", comment: "AI: discard a suggestion"),
                                     target: self, action: #selector(discardSuggestionTapped))
        discardButton.bezelStyle = .rounded
        suggestionBar.addArrangedSubview(suggestionLabel)
        suggestionBar.addArrangedSubview(discardButton)
        suggestionBar.addArrangedSubview(applyButton)

        planRowsBox.orientation = .vertical
        planRowsBox.alignment = .leading
        planRowsBox.spacing = 2
        planRowsBox.isHidden = true

        var rows: [NSView] = [topRow]
        if contextProvider != nil { rows.append(attachRow) }
        rows += [statusRow, scroll, suggestionBar, planRowsBox, confirmBar, inputRow]
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
        clearSuggestion()
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
        clearSuggestion()   // a new question replaces an unanswered proposal
        append(role: youLabel, text: userText, markdown: false)
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
        clearPlanRows()
        append(role: assistantLabel, text: String(localized: "Okay, I won’t make those changes.", comment: "AI: declined changes"))
    }

    /// Programmatic send (used by the DEBUG automation verb for verification).
    func sendProgrammatically(_ text: String) async {
        if currentSession == nil { await start() }
        await submit(text)
    }

    @objc private func actionsMenuChanged() {
        let idx = actionsPopup.indexOfSelectedItem
        actionsPopup.selectItem(at: 0)
        if idx == 1 { showActionLog() }
        else if idx == 2 { undoLastChange() }
    }

    /// The recorded actions, as a list. Read through the same tool the assistant uses, so what
    /// the user sees is what was actually recorded — not a second, parallel account of it.
    private func showActionLog() {
        Task {
            let entries = await manager.recentActions(limit: 40)
            let alert = NSAlert()
            alert.messageText = String(localized: "What the assistant did", comment: "AI: action log title")
            if entries.isEmpty {
                alert.informativeText = String(localized: "Nothing has been changed yet.",
                                               comment: "AI: empty action log")
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .medium
                let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 260))
                text.isEditable = false
                text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                text.string = entries.map { entry in
                    let when = formatter.string(from: Date(timeIntervalSince1970: entry.at))
                    let mark = entry.isUndoable ? "↩︎ " : "   "
                    return "\(mark)\(when)  \(entry.summary)"
                }.joined(separator: "\n")
                let scroll = NSScrollView(frame: text.frame)
                scroll.documentView = text
                scroll.hasVerticalScroller = true
                scroll.borderType = .bezelBorder
                alert.accessoryView = scroll
                alert.informativeText = String(localized: "↩︎ marks a change that can still be undone.",
                                               comment: "AI: action log legend")
            }
            alert.addButton(withTitle: String(localized: "Close", comment: "AI: close the log"))
            alert.runModal()
        }
    }

    /// Take back the last undoable change. Runs through the session, so the autonomy policy
    /// applies: a read-only assistant cannot undo either, and says so.
    private func undoLastChange() {
        guard !busy else { NSSound.beep(); return }
        clearSuggestion()
        append(role: youLabel, text: String(localized: "Undo the last change",
                                            comment: "AI: undo request"), markdown: false)
        beginRun { try await $0.undoLastChange() }
    }

    /// Put a proposal on offer. The button says exactly what pressing it does.
    private func offer(_ suggestion: AgentSession.Suggestion) {
        pendingSuggestion = suggestion
        let current = (suggestion.path as NSString).lastPathComponent
        switch suggestion.kind {
        case .rename:
            suggestionLabel.stringValue = String(
                format: String(localized: "Rename %1$@ to %2$@?", comment: "AI: rename suggestion"),
                current, suggestion.value)
            applyButton.title = String(localized: "Rename", comment: "AI: apply a rename suggestion")
        }
        suggestionLabel.textColor = theme.text
        suggestionBar.isHidden = false
    }

    private func clearSuggestion() {
        pendingSuggestion = nil
        suggestionBar.isHidden = true
    }

    @objc private func applySuggestionTapped() {
        guard !busy, let suggestion = pendingSuggestion else { return }
        clearSuggestion()
        beginRun { try await $0.apply(suggestion) }
    }

    @objc private func discardSuggestionTapped() {
        clearSuggestion()
        append(role: assistantLabel, text: String(localized: "Okay, I’ll leave the name as it is.",
                                                  comment: "AI: suggestion discarded"))
    }

    /// "Suggest a name" action → its own fresh chat, ending in a proposal that can be applied.
    func sendRenameRequest(path: String, displayName: String) {
        Task {
            let session = await manager.create(title: String(
                format: String(localized: "Name: %@", comment: "AI: rename chat title"), displayName))
            sessions = await manager.list()
            rebuildPopup()
            await switchTo(id: session.id)
            append(role: youLabel, text: String(
                format: String(localized: "Suggest a name for %@", comment: "AI: rename request"), displayName))
            beginRun { try await $0.suggestRename(path: path, displayName: displayName) }
        }
    }

    /// Put a line in the current conversation from the plugin itself (not from the model).
    func showNotice(_ text: String) {
        append(role: assistantLabel, text: text, markdown: false)
    }

    /// Run one skill over several files: its own chat, one result per file, in order.
    ///
    /// Sequential on purpose. The on-device model is one resource, the actions may be writes
    /// that need approving one at a time, and a user watching forty files go past wants to be
    /// able to stop after the third — which Stop does, between files.
    func sendBatchSkill(_ request: BatchRequest) {
        guard !busy else { NSSound.beep(); return }
        Task {
            let session = await manager.create(title: request.title)
            sessions = await manager.list()
            rebuildPopup()
            await switchTo(id: session.id)
            guard let agent = currentSession, let id = currentSessionId else { return }

            busy = true
            runGeneration += 1
            let gen = runGeneration
            currentRunId = id
            setBusyUI(true)
            Task { await agent.setProgressHandler { [weak self] name in await self?.showActivity(name, gen: gen) } }
            if let p = await policyProvider?() { await agent.setPolicy(p) }

            var done = 0
            for path in request.paths {
                guard gen == runGeneration else { break }   // Stop, or another run took over
                let name = (path as NSString).lastPathComponent
                done += 1
                statusLabel.stringValue = String(
                    format: String(localized: "Model: %1$@ — file %2$d of %3$d: %4$@",
                                   comment: "AI: batch progress"),
                    providerName, done, request.paths.count, name)
                append(role: youLabel, text: request.skill.title + " – " + name, markdown: false)
                armWatchdog(gen: gen, id: id)
                do {
                    let result = try await agent.send(request.skill.prompt(name: name, path: path))
                    guard gen == runGeneration else { break }
                    render(result)
                    // A file whose turn needs approval stops the run: the next file must not
                    // scroll the question off the screen before it is answered.
                    if case .needsConfirmation = result { break }
                } catch {
                    guard gen == runGeneration else { break }
                    append(role: assistantLabel,
                           text: String(format: String(localized: "Error: %@", comment: "AI: error line"),
                                         error.localizedDescription))
                }
                await manager.persist(id: id)
            }
            watchdog?.cancel(); watchdog = nil
            if gen == runGeneration {
                busy = false
                setBusyUI(false)
                append(role: assistantLabel, text: String(
                    format: String(localized: "Done — %1$d of %2$d files.", comment: "AI: batch summary"),
                    done, request.paths.count))
            }
        }
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

    /// Host colour theme (F-338). The chat is a sidebar panel sitting beside the file panels, so
    /// it follows the theme; a standalone window would stay in system colours.
    private var theme = PluginTheme.systemFallback

    /// Not `static` any more: the body colour depends on the theme, and a static would freeze
    /// whatever the theme was when the class was first touched.
    private var bodyAttrs: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: theme.text]
    }
    private var labelAttrs: [NSAttributedString.Key: Any] {
        [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: theme.secondaryText]
    }

    /// Apply the host theme, including to messages already on screen.
    ///
    /// Remapping the existing runs matters: without it a theme switch leaves the transcript in two
    /// colour schemes at once — old messages in the previous theme, new ones in the current — which
    /// looks like a rendering bug. The two colours this view ever sets are known, so old → new is
    /// an exact substitution rather than a guess.
    func applyTheme(_ services: PcHostServices?) {
        let old = theme
        theme = PluginTheme(services)
        transcript.backgroundColor = theme.background
        transcript.insertionPointColor = theme.text
        transcript.selectedTextAttributes = [.backgroundColor: theme.selectionBackground,
                                             .foregroundColor: theme.selectionText]
        guard old.id != theme.id || old.isDark != theme.isDark else { return }
        guard let ts = transcript.textStorage, ts.length > 0 else { return }
        // Re-render rather than recolour. A rendered answer carries table borders, code
        // backgrounds and link colours; substituting the two text colours left the rest in the
        // previous theme, which reads as a rendering bug.
        if !renderedHistory.isEmpty { renderHistory(renderedHistory); return }
        ts.beginEditing()
        ts.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: ts.length)) { value, range, _ in
            guard let c = value as? NSColor else { return }
            if c == old.text { ts.addAttribute(.foregroundColor, value: theme.text, range: range) }
            else if c == old.secondaryText { ts.addAttribute(.foregroundColor, value: theme.secondaryText, range: range) }
        }
        ts.endEditing()
    }

    /// Stream the assistant's answer live: start an assistant bubble on the first partial,
    /// then replace its body with each cumulative snapshot.
    func streamPartial(_ text: String) {
        guard busy, let ts = transcript.textStorage else { return }
        if streamBodyStart == nil {
            ts.append(NSAttributedString(string: "\(assistantLabel):\n", attributes: labelAttrs))
            streamBodyStart = ts.length
        }
        let start = streamBodyStart ?? ts.length
        let range = NSRange(location: start, length: max(0, ts.length - start))
        ts.replaceCharacters(in: range, with: NSAttributedString(string: text, attributes: bodyAttrs))
        transcript.scrollToEndOfDocument(nil)
    }

    /// Close off a streamed bubble. If `replaceWith` is given, the body is replaced with
    /// that final text; otherwise the partial text so far is kept. Returns true if a
    /// stream was in progress (so the caller shouldn't append the answer again).
    @discardableResult
    private func finalizeStreamIfActive(replaceWith finalText: String? = nil) -> Bool {
        guard let start = streamBodyStart, let ts = transcript.textStorage else { return false }
        if let finalText {
            // The partials stream as plain text (they are half-written Markdown most of the
            // way); the finished answer replaces them, rendered.
            let shown = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(location: start, length: max(0, ts.length - start))
            let rendered: NSAttributedString = shown.isEmpty
                ? NSAttributedString(string: String(localized: "I couldn’t produce a clear answer. Please try again or rephrase.",
                                                    comment: "AI: empty answer fallback"), attributes: bodyAttrs)
                : ChatMarkdown.render(shown, style: markdownStyle)
            ts.replaceCharacters(in: range, with: rendered)
        }
        ts.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
        streamBodyStart = nil
        transcript.scrollToEndOfDocument(nil)
        return true
    }

    private func showActivity(_ toolName: String, gen: Int) {
        guard gen == runGeneration, busy else { return }
        // Progress re-arms the watchdog. It is there to free the UI from a model that is stuck,
        // and a turn that reads a long file in slices takes a generation per slice — without this
        // it would be cut off at two minutes and reported as too slow while it was working.
        if let id = currentRunId, nativeConfirm == nil { armWatchdog(gen: gen, id: id) }
        statusLabel.stringValue = String(format: String(localized: "Model: %1$@ — %2$@", comment: "AI: model + current activity"),
                                          providerName, Self.friendlyActivity(toolName))
    }

    private static func friendlyActivity(_ tool: String) -> String {
        // "summarize_file:3/10" — the folding counts its slices, so a long read shows movement
        // instead of a spinner that looks like nothing is happening.
        if tool.hasPrefix("summarize_file") {
            let parts = tool.split(separator: ":").last.map { $0.split(separator: "/") } ?? []
            if parts.count == 2, let n = Int(parts[0]), let m = Int(parts[1]) {
                return String(format: String(localized: "reading section %1$d of %2$d…",
                                              comment: "AI activity: one slice of a long file"), n, m)
            }
            return String(localized: "reading the whole file…", comment: "AI activity")
        }
        switch tool {
        case "get_context":     return String(localized: "checking the current folder…", comment: "AI activity")
        case "list_directory":  return String(localized: "listing files…", comment: "AI activity")
        case "read_file":       return String(localized: "reading a file…", comment: "AI activity")
        case "search":          return String(localized: "searching…", comment: "AI activity")
        case "stat_path":       return String(localized: "inspecting a file…", comment: "AI activity")
        case "semantic_search": return String(localized: "searching…", comment: "AI activity")
        case "get_config", "list_commands", "list_plugins", "recall", "list_recent_actions":
                                return String(localized: "looking things up…", comment: "AI activity")
        case "copy", "move", "rename", "make_directory", "set_config", "move_to_trash",
             "delete_permanently", "write_file", "merge_files", "set_comment", "undo_last_action":
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
        case .suggestion(let text, let action):
            append(role: assistantLabel, text: text)
            offer(action)
        case .needsConfirmation(let plans):
            pendingTokens = plans.map(\.token)
            let header = String(localized: "I’d like to:", comment: "AI: plan header")
            let footer = String(localized: "Confirm to proceed.", comment: "AI: plan footer")
            append(role: assistantLabel,
                   text: header + "\n" + plans.map { "• \($0.plan)" }.joined(separator: "\n") + "\n\n" + footer)
            confirmBar.isHidden = false
            // A plan made of items gets a tick list, so the answer can be "yes, except those" instead of
            // only all or nothing (F-450). Asked for after the plan is on screen: the rows come from the
            // host over a blocking call, and the plan should not wait for them.
            Task { @MainActor [weak self] in await self?.showPlanRows(for: plans.map(\.token)) }
        }
    }

    /// Build the tick list for the pending plans, all ticked. Nothing is shown when no plan has rows.
    private func showPlanRows(for tokens: [String]) async {
        guard let agent = currentSession else { return clearPlanRows() }
        var rows: [(token: String, item: PlanItem)] = []
        for token in tokens {
            rows += await agent.planItems(token: token).map { (token, $0) }
        }
        renderPlanRows(rows)
    }

    /// Draw the tick list, separately from fetching it.
    ///
    /// Split for a reason that is still unfinished business: the rows and what striking one out skips are
    /// proved through the host's ABI, but whether the checkboxes are on screen can only be shown by a
    /// picture — and nothing in the automation harness types into this chat, so getting a plan on screen
    /// needs a language model to choose to propose one, which is not something a check can depend on.
    /// With the drawing separated, a harness that can reach this method can photograph it (F-450).
    private func renderPlanRows(_ rows: [(token: String, item: PlanItem)]) {
        clearPlanRows()
        for row in rows {
            let box = NSButton(checkboxWithTitle: row.item.text, target: nil, action: nil)
            box.state = NSControl.StateValue.on
            planRowChecks.append((row.token, row.item.id, box))
            planRowsBox.addArrangedSubview(box)
        }
        // Only worth a list when there is a choice to make: one row is the whole plan, and Confirm and
        // Cancel already say yes and no to that.
        guard planRowChecks.count > 1 else { return clearPlanRows() }
        planRowsBox.isHidden = false
        confirmBar.isHidden = false
    }

    private func clearPlanRows() {
        planRowChecks.forEach { $0.box.removeFromSuperview() }
        planRowChecks = []
        planRowsBox.isHidden = true
    }

    /// What the user unticked, keyed by the plan it belongs to. Per token, because a row id is only
    /// unique inside its own plan.
    private func rejectedRows() -> [String: Set<String>] {
        var out: [String: Set<String>] = [:]
        for row in planRowChecks where row.box.state != NSControl.StateValue.on {
            out[row.token, default: []].insert(row.id)
        }
        return out
    }

    /// The messages last rendered, so a theme change can redraw them rather than recolour
    /// them in place (the rendered answers carry more colours than a substitution can track).
    private var renderedHistory: [ModelMessage] = []

    private func renderHistory(_ messages: [ModelMessage]) {
        renderedHistory = messages
        transcript.textStorage?.setAttributedString(NSAttributedString(string: ""))
        // Tool results are the model's working material, not the conversation: a restored chat
        // used to show pages of raw JSON between the messages. What the assistant did with them
        // is in its answers, and every call is in the AI activity log.
        let visible = messages.filter { $0.role == .user || $0.role == .assistant }
            .filter { !$0.content.hasPrefix("[tool calls:") }
        if visible.isEmpty {
            append(role: assistantLabel, text: String(localized: "Hi! Tell me what to do with your files. I’ll show a plan before making any changes.",
                                                      comment: "AI: greeting"))
            return
        }
        for m in visible {
            let isUser = m.role == .user
            // The user's own line is shown as typed; only the assistant writes Markdown.
            append(role: isUser ? youLabel : assistantLabel,
                   text: isUser ? ChatComposer.stripPaths(m.content) : m.content,
                   markdown: !isUser)
        }
    }

    /// The style the renderer draws with, following the host theme.
    private var markdownStyle: ChatMarkdownStyle {
        ChatMarkdownStyle(theme: theme, maxImageWidth: transcriptTextWidth)
    }

    /// The transcript's usable text width, which is how wide an inline image may be drawn.
    /// The container tracks the view, so this follows the pane as it is dragged; before the
    /// first layout it is zero, and a fixed figure is better than an image of no width.
    private var transcriptTextWidth: CGFloat {
        let width = (transcript.textContainer?.size.width ?? 0) - transcript.textContainerInset.width * 2
        return width > 80 ? width : 320
    }

    /// Append one message. The body goes through the Markdown renderer, so a table is a
    /// table, a fenced block is a code block, and a path is clickable — the model writes
    /// Markdown, and showing it raw was the reason "Make a table" produced pipe characters.
    private func append(role: String, text: String, markdown: Bool = true) {
        let m = NSMutableAttributedString()
        // The label gets its own line. Inline, a body that opens with a block element — a
        // table, a code block — continues the label's paragraph, and the table's first cell
        // ends up beside the word "Assistant" instead of in the table.
        m.append(NSAttributedString(string: "\(role):\n", attributes: labelAttrs))
        if markdown {
            m.append(ChatMarkdown.render(text, style: markdownStyle))
        } else {
            let plain = NSMutableAttributedString(string: text, attributes: bodyAttrs)
            ChatMarkdown.linkPaths(in: plain, style: markdownStyle)
            m.append(plain)
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
