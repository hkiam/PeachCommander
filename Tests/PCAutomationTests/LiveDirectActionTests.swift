// SPDX-License-Identifier: Apache-2.0
// LiveDirectActionTests.swift - the direct actions, against the real on-device model.
//
// The direct actions exist because of one measurement: the 32-tool chat session spends 3442 of
// the on-device model's 4096 tokens on tool schemas before a word is exchanged, so a 4 KB file
// slice cannot fit. A direct action offers the model no tools at all, which is what puts the
// window back at the disposal of the file's content.
//
// That is a claim about a model, not about code, so it is checked against the model. Live and
// gated like its neighbours: PC_AI_LIVE=1.

import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import PCAutomation

#if canImport(FoundationModels)
import FoundationModels

final class LiveDirectActionTests: XCTestCase {

    /// A sandbox holding `files`, removed when the test ends.
    private func sandbox(_ files: [String: String]) throws -> String {
        let root = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pc-direct-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(atPath: root) }
        for (name, body) in files {
            try body.write(toFile: (root as NSString).appendingPathComponent(name),
                           atomically: true, encoding: .utf8)
        }
        return root
    }

    @available(macOS 26, *)
    private func session(root: String, store: SummaryStore? = nil) -> AppleNativeToolSession {
        AppleNativeToolSession(
            directActionsOn: DefaultAutomationCore(bridge: RealFSBridge(root: root)),
            policy: .standard, summaryStore: store)
    }

    // MARK: - The measurement this change came from

    func test_live_aFullReadSliceFitsTheWindow() async throws {
        guard #available(macOS 26.4, *) else { throw XCTSkip("tokenCount needs macOS 26.4") }
        try LiveModel.requireEnabled()
        // This is the property every direct action rests on, and the one the retired chat could
        // not satisfy: with no tools offered, a full read slice plus its instruction fits, with
        // room left for the answer. The chat spent 3442 of these 4096 tokens on tool schemas
        // before the file was opened — which is why there are no tools here and no chat.
        let model = SystemLanguageModel.default
        let slice = String(repeating: "Ein Satz aus einem Wartungsbericht über die Dachreparatur. ",
                           count: NativeToolContext.readBudget / 58)
        let used = try await model.tokenCount(
            for: "Summarise the following beginning of a file in two or three sentences.\n\n" + slice)
        XCTAssertLessThan(used, model.contextSize / 2,
                          "a full \(NativeToolContext.readBudget)-byte slice costs \(used) of "
                          + "\(model.contextSize) tokens; the fold needs room for the answer too")
    }

    // MARK: - Summarising

    func test_live_summarize_handlesAFileLongerThanOneSlice() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // Comfortably over NativeToolContext.readBudget, so the slicing and the fold both run.
        // In the 32-tool session a single 4 KB slice overflowed the window outright.
        let body = String(repeating: "The quarterly maintenance report records the roof repair, "
                          + "the boiler service and the annual lift inspection. ", count: 90)
        let root = try sandbox(["report.txt": body])
        let out = await session(root: root)
            .summarize(file: (root as NSString).appendingPathComponent("report.txt"))
        XCTAssertFalse(out.isEmpty)
        XCTAssertFalse(out.contains("could not be summarised"), "got: \(out)")
    }

    func test_live_summarize_answersInTheLanguageOfTheFile() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // The reported symptom was an English answer to a German question. Under context pressure
        // the language instruction is the first thing the model drops; with no tools competing for
        // the window it should hold.
        let body = String(repeating: "Der Wartungsbericht hält die Dachreparatur, die Wartung der "
                          + "Heizungsanlage und die jährliche Prüfung des Aufzugs fest. ", count: 60)
        let root = try sandbox(["bericht.txt": body])
        let out = await session(root: root)
            .summarize(file: (root as NSString).appendingPathComponent("bericht.txt"))
        XCTAssertEqual(NativeToolContext.languageName(of: out), "German", "got: \(out)")
    }

    func test_live_summarize_isKeptForThePanelColumn() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // The AI Summary column reads what a summary run leaves behind. Until now only a chat turn
        // ever wrote it, which is why the column was empty for anyone who did not chat.
        let root = try sandbox(["notes.txt": "The lift inspection is due in March. "
                                + "The roof repair was completed in January."])
        let storeURL = URL(fileURLWithPath: (root as NSString).appendingPathComponent("summaries.json"))
        let store = SummaryStore(url: storeURL)
        let path = (root as NSString).appendingPathComponent("notes.txt")
        _ = await session(root: root, store: store).summarize(file: path)

        let a = try FileManager.default.attributesOfItem(atPath: path)
        let stamp = SummaryStore.fingerprint(
            path: path,
            size: (a[.size] as? NSNumber)?.int64Value ?? 0,
            modified: (a[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0)
        XCTAssertNotNil(SummaryStore(url: storeURL).summary(for: stamp),
                        "a summary must survive the run that produced it")
    }

    // MARK: - Comments and tags

    func test_live_suggestComment_isOneSentenceAndUsableTags() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        let root = try sandbox(["invoice-2024-03.txt":
            "Invoice 4711, dated 12 March 2024, for roof repair work. Total 2,480 EUR, net 30 days."])
        let (comment, tags) = try await session(root: root)
            .suggestComment(path: (root as NSString).appendingPathComponent("invoice-2024-03.txt"))
        XCTAssertFalse(comment.isEmpty)
        XCTAssertLessThanOrEqual(tags.count, 4)
        for tag in tags {
            XCTAssertFalse(tag.contains(" "), "a tag is a word, not a phrase: \(tag)")
            XCTAssertEqual(tag, tag.lowercased())
        }
    }

    func test_live_suggestFileName_namesAGermanFileInGerman() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // A German invoice came back as "Repair_Bill_4711.txt" while the instructions only implied
        // the language. Naming it is what this model follows — the same finding the folding code
        // records at `languageClause`.
        let root = try sandbox(["dokument1.txt":
            "Rechnung Nr. 4711 über die Dachreparatur am Nordfluegel. "
            + "Gesamtbetrag 2.480,00 EUR, zahlbar innerhalb von 30 Tagen ohne Abzug."])
        let out = try await session(root: root)
            .suggestFileName(path: (root as NSString).appendingPathComponent("dokument1.txt"))
        XCTAssertTrue(out.newName.hasSuffix(".txt"), "got: \(out.newName)")
        let ascii = out.newName.replacingOccurrences(of: ".txt", with: "")
        XCTAssertFalse(ascii.lowercased().contains("bill"), "an English name for a German file: \(out.newName)")
        XCTAssertFalse(ascii.lowercased().contains("invoice"), "an English name for a German file: \(out.newName)")
        // A name is a name. Left to itself the model answered with the whole invoice —
        // "rechnung_nr_4711_dachreparatur_nordfluegel_2480_00_eur_faellig_30_tage.txt".
        XCTAssertLessThanOrEqual(out.newName.count, 80, "not a name, a summary: \(out.newName)")
    }

    // MARK: - The short facts

    func test_live_facts_readAGermanInvoice() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        let root = try sandbox(["dokument1.txt":
            "Rechnung Nr. 4711 vom 12. März 2024 für die Dachreparatur am Nordflügel. 2.480,00 EUR."])
        let f = try await session(root: root).facts(
            forFile: (root as NSString).appendingPathComponent("dokument1.txt"),
            among: ["Rechnungen", "Reisen"])
        XCTAssertEqual(f.kind, "Rechnungen")
        XCTAssertEqual(f.date, "2024-03-12")
        XCTAssertFalse(f.topic.isEmpty)
        XCTAssertFalse(f.topic.contains(" "), "a topic goes into a file name: \(f.topic)")
    }

    func test_live_facts_inventNoDateForASeason() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // Measured: "Reisenotizen Kreta, Sommer 2023" came back as 2023-07-01. A date invented in
        // a file name outlives every chance of noticing it, so nothing is the only right answer.
        let root = try sandbox(["notizen.txt": "Reisenotizen Kreta, Sommer 2023: Chania, Samaria."])
        let f = try await session(root: root).facts(
            forFile: (root as NSString).appendingPathComponent("notizen.txt"),
            among: ["Reisen"])
        XCTAssertEqual(f.date, "", "invented a day and month from a season")
    }

    func test_live_proposeFolders_nameCategoriesInTheFilesOwnLanguage() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // Detecting the language from a list of file names produced Polish categories for German
        // files ("tekstowe"), because a recognizer handed tokens rather than prose guesses.
        let names = ["rechnung-dachdecker.txt", "rechnung-heizung.txt", "urlaub-kreta.txt"]
        let root = try sandbox(Dictionary(uniqueKeysWithValues: names.map { ($0, "Text.") }))
        let folders = try await session(root: root).proposeFolders(forNames: names)
        XCTAssertFalse(folders.isEmpty)
        for f in folders {
            XCTAssertNil(NativeToolContext.languageName(of: f).flatMap { $0 == "Polish" ? $0 : nil },
                         "category in a language nobody asked for: \(folders)")
        }
    }

    func test_live_groupTopics_putsEachTopicInACategory() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // Categories come from the topics, not the file names: over `dokument1.txt` and friends the
        // only honest category is "Dokument" and every file gets it. Over the topics it has to
        // separate them — and each topic has to find its category by snapping, with no further
        // generation.
        // Two of these belong together and two do not — demanding fewer categories than topics
        // for three unrelated ones was this test's own mistake, and one category each was the
        // honest answer it rejected.
        let topics = ["rechnung", "quittung", "reise", "arbeitsvertrag"]
        let root = try sandbox(["a.txt": "x"])
        let mapping = try await session(root: root).groupTopics(topics)
        for topic in topics {
            XCTAssertNotNil(mapping[topic], "no category for \(topic): \(mapping)")
        }
        XCTAssertLessThan(Set(mapping.values).count, topics.count,
                          "an invoice and a receipt belong together: \(mapping)")
        // And in the topics' own language: English categories for German topics is what asking
        // for "the same language as the topics" produced before the language was named outright.
        for category in Set(mapping.values) {
            XCTAssertNotEqual(category.lowercased(), "financial", "English category: \(mapping)")
            XCTAssertNotEqual(category.lowercased(), "travel", "English category: \(mapping)")
        }
    }

    // MARK: - Pictures

    /// A PNG with `text` on it, standing in for a scan.
    private func scan(_ text: String, named name: String) throws -> String {
        let root = try sandbox([:])
        let path = (root as NSString).appendingPathComponent(name)
        let width = 900, height = 220
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw XCTSkip("no bitmap context") }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Helvetica" as CFString, 56, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text, attributes: [.font: font,
                                       .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)]))
        context.textPosition = CGPoint(x: 25, y: 90)
        CTLineDraw(line, context)
        guard let image = context.makeImage(),
              let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                                         UTType.png.identifier as CFString, 1, nil)
        else { throw XCTSkip("no image") }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw XCTSkip("could not write the png") }
        return path
    }

    func test_live_suggestFileName_readsAScan() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // The point of the whole image step: Apple Intelligence cannot see a picture, so Vision
        // reads the words off it and the model names the file from those. `scan_0042.png` is the
        // file a scanner leaves behind and the one a file manager can do nothing with.
        let path = try scan("Rechnung 4711 Dachdecker", named: "scan_0042.png")
        let root = (path as NSString).deletingLastPathComponent
        let out = try await session(root: root).suggestFileName(path: path)
        XCTAssertTrue(out.newName.hasSuffix(".png"), "got: \(out.newName)")
        XCTAssertTrue(out.newName.lowercased().contains("4711")
                      || out.newName.lowercased().contains("rechnung"),
                      "named from the pixels rather than from what is on them: \(out.newName)")
        // The scanner's own name says nothing and must not survive into the new one.
        XCTAssertFalse(out.newName.lowercased().contains("scan_0042"),
                       "kept a meaningless prefix: \(out.newName)")
        // And in the document's language: an English scaffolding sentence in front of the OCR text
        // was enough to make a German invoice come back as "receipt".
        XCTAssertFalse(out.newName.lowercased().contains("receipt"),
                       "named a German document in English: \(out.newName)")
    }

    func test_live_facts_readAScan() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // The flow Classify actually uses: no categories here, because they are worked out from
        // the topics afterwards. An earlier version of this test passed a category list — which the
        // action never does — and chased a wobble that only that call produced. Handed
        // ["Rechnungen", "Fotos"] and a file ending in .png, this model answers "Fotos" for a
        // scanned invoice however the question is phrased, and it is not wrong about the file,
        // only about the thing. The topic was right every single run.
        let path = try scan("Rechnung 4711 Dachdecker", named: "scan_0042.png")
        let root = (path as NSString).deletingLastPathComponent
        let f = try await session(root: root).facts(forFile: path, among: [])
        XCTAssertTrue(f.topic.contains("rechnung") || f.topic.contains("dachdecker"),
                      "the words on the scan did not reach the topic: \(f)")
    }

    // MARK: - A table out of a file

    func test_live_tabulate_readsTheRowsThatAreThere() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // Guided generation is what makes this worth attempting on a small model: a table asked
        // for as text arrives with a missing separator row or a sentence after it often enough to
        // be useless, and a typed schema cannot.
        let root = try sandbox(["messung.txt": """
            Wartungsprotokoll Heizung
            12.03.2024  Vorlauf 62 C  Rücklauf 48 C  Druck 1,8 bar  Bemerkung: normal
            19.03.2024  Vorlauf 64 C  Rücklauf 47 C  Druck 1,7 bar  Bemerkung: Entlüftet
            26.03.2024  Vorlauf 61 C  Rücklauf 49 C  Druck 1,8 bar  Bemerkung: normal
            """])
        let out = try await session(root: root)
            .tabulate(file: (root as NSString).appendingPathComponent("messung.txt"))
        XCTAssertFalse(out.table.isEmpty)
        XCTAssertGreaterThanOrEqual(out.table.rows.count, 3, "rows that are in the file: \(out.table)")
        XCTAssertGreaterThanOrEqual(out.table.headers.count, 3)
        for row in out.table.rows {
            XCTAssertEqual(row.count, out.table.headers.count, "a short row shifts the CSV")
        }
        // A decimal comma is the case that decides whether the CSV survives being opened.
        let csv = DirectActionPlan.csv(out.table)
        XCTAssertFalse(csv.isEmpty)
        if csv.contains("1,8") { XCTAssertTrue(csv.contains("\"1,8"), "unquoted comma: \(csv)") }
    }

    // MARK: - Organising

    func test_live_proposeFolders_areCategoriesAndNotFileNames() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // The failure this replaced: asked per file with a growing list, the model answered with
        // the first file's own base name and then filed everything else under it.
        let names = ["rechnung-a.txt", "rechnung-b.txt", "urlaub-kreta.txt", "urlaub-norwegen.txt"]
        let root = try sandbox(Dictionary(uniqueKeysWithValues: names.map { ($0, "x") }))
        let folders = try await session(root: root).proposeFolders(forNames: names)
        XCTAssertFalse(folders.isEmpty)
        XCTAssertLessThanOrEqual(folders.count, 6)
        let fileKeys = Set(names.map { DirectActionPlan.foldingKey(($0 as NSString).deletingPathExtension) })
        for folder in folders {
            XCTAssertFalse(fileKeys.contains(DirectActionPlan.foldingKey(folder)),
                           "\(folder) is one of the files, not a category")
            XCTAssertFalse(folder.contains("/"))
        }
    }

    func test_live_proposeFolders_survivesASmallSetOfOneKind() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // Two files of one kind is the case a reader hits first when they mark a couple and ask
        // for a tidy-up. Asked for "as few folders as sensibly possible", the model can answer
        // with the two file names — both are then dropped as non-categories and the whole action
        // reports that nothing groups. Pinned because it is the smallest useful input.
        let names = ["urlaub-kreta.txt", "urlaub-norwegen.txt"]
        let root = try sandbox(Dictionary(uniqueKeysWithValues: names.map { ($0, "Reisenotizen.") }))
        let folders = try await session(root: root).proposeFolders(forNames: names)
        XCTAssertFalse(folders.isEmpty, "no usable category for two files of one kind")
        // Bounded by the file count rather than by the model's restraint: two files can justify
        // exactly one category, and that is arithmetic rather than something to ask for.
        XCTAssertEqual(folders.count, 1, "one folder per file is not a grouping: \(folders)")
    }

    func test_live_assignFolder_sortsIntoTheCategoriesItIsGiven() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        // With good categories in hand, the assignment is the part that has to work. A closed list
        // is the ask small models are best at — and an answer outside it means "none fits", which
        // leaves the file where it is rather than inventing a folder.
        let root = try sandbox([
            "rechnung-a.txt": "Rechnung Nr. 1001, Dachdecker Meier, 480,00 EUR, faellig 30 Tage.",
            "urlaub-kreta.txt": "Reisenotizen Kreta, Sommer 2023: Chania, Samaria-Schlucht.",
        ])
        let folders = ["Rechnungen", "Reisen"]
        let s = session(root: root)
        let invoice = try await s.assignFolder(
            forFile: (root as NSString).appendingPathComponent("rechnung-a.txt"), among: folders)
        let trip = try await s.assignFolder(
            forFile: (root as NSString).appendingPathComponent("urlaub-kreta.txt"), among: folders)
        XCTAssertEqual(invoice.subfolder, "Rechnungen")
        XCTAssertEqual(trip.subfolder, "Reisen")
    }

    func test_live_assignFolder_withNoFoldersChoosesNothing() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        let root = try sandbox(["a.txt": "anything"])
        let out = try await session(root: root)
            .assignFolder(forFile: (root as NSString).appendingPathComponent("a.txt"), among: [])
        XCTAssertEqual(out.subfolder, "")
    }
}
#endif
