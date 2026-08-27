// SPDX-License-Identifier: Apache-2.0
// DirectActionPlan.swift - the decisions a direct action makes *around* the model.
//
// A direct action is one generation per file plus a lot of arithmetic: which folders the
// proposals collapse into, which renames are actually renames, which names would collide.
// None of that needs a model, and none of it should live where a test cannot reach it —
// nothing under `Plugins/` is compiled into a test target, and the session that calls this
// is behind `#if canImport(FoundationModels)` and `@available(macOS 26)`, so a machine
// without Apple Intelligence could not exercise it there either.
//
// So it lives here, beside `PlanRows`, which draws the rows these invocations become.

import Foundation

public enum DirectActionPlan {

    // MARK: - Organising a folder

    /// One file and the subfolder the model put it in.
    public struct Assignment: Sendable, Equatable {
        public let path: String
        public let subfolder: String
        public let reason: String
        public init(path: String, subfolder: String, reason: String) {
            self.path = path; self.subfolder = subfolder; self.reason = reason
        }
    }

    /// One subfolder and everything going into it — the shape `move` takes.
    public struct Group: Sendable, Equatable {
        public let subfolder: String
        public let sources: [String]
        public init(subfolder: String, sources: [String]) {
            self.subfolder = subfolder; self.sources = sources
        }
    }

    /// Collapse per-file assignments into one group per subfolder.
    ///
    /// Order is the order the folders were first proposed, and within a folder the order the
    /// files were assigned. Both matter: the sheet shows this list, and a reader checking a
    /// tidy-up against the panel is comparing two orderings.
    ///
    /// Assignments whose subfolder is empty are dropped — the caller sanitises before it gets
    /// here, so an empty one means the model produced nothing usable for that file, and leaving
    /// the file where it is is the right answer.
    public static func group(_ assignments: [Assignment]) -> [Group] {
        var order: [String] = []
        var byFolder: [String: [String]] = [:]
        for a in assignments {
            let folder = a.subfolder.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !folder.isEmpty else { continue }
            if byFolder[folder] == nil { order.append(folder); byFolder[folder] = [] }
            byFolder[folder]?.append(a.path)
        }
        return order.map { Group(subfolder: $0, sources: byFolder[$0] ?? []) }
    }

    /// A folder holding one file has not been organised, it has been buried.
    ///
    /// Splitting forty files into forty folders is the failure mode of this feature, and it is
    /// what a model does when it names a folder after each file. Groups below `minimum` are
    /// dropped so those files simply stay where they are.
    /// - Parameter of: how many files the run looked at, so the mirror-image failure can be caught
    ///   too — see below. Left unset, only the per-group minimum applies.
    public static func groupsWorthMaking(_ groups: [Group], minimum: Int = 2,
                                         of considered: Int = 0) -> [Group] {
        let worth = groups.filter { $0.sources.count >= minimum }
        // The other half of the same idea. One folder holding *every* file has not organised them
        // either — it has renamed the folder they were already in, one level deeper. Measured
        // against the on-device model: over four files that split cleanly into invoices and
        // minutes, three runs in four proposed both categories, and the fourth proposed the single
        // category "projekte" and filed all four under it. That run is the harmful one, because
        // unlike a shrug it moves files, and the folder it moves them to describes none of them.
        //
        // Deliberately arithmetic rather than a better prompt: the same wobble was chased through
        // three prompt revisions elsewhere in this file before a counting rule settled it.
        if considered > 1, worth.count == 1, worth[0].sources.count == considered { return [] }
        return worth
    }

    /// The one folder a file name plainly belongs to, or nil when the names do not settle it.
    ///
    /// A rescue for a measured miss, not a second opinion. `assignFolder` answers with an empty
    /// name about one time in five even when the right category is on the list it was handed:
    /// over four files split into invoices and minutes, `rechnung-dach.txt` came back unfiled
    /// while `rechnungen` was sitting in the list. The file then stays put and the tidy-up is
    /// half done.
    ///
    /// Lexical on purpose, and only where the answer is unambiguous. The categories were derived
    /// from these very names, so a name whose word is the stem of exactly one category belongs
    /// there and no model is needed to see it — the same reasoning as `commonPrefixCategory`.
    /// Two candidates mean the names do not settle it, and then nothing is chosen: a file left
    /// where it is costs a second run, a file in the wrong folder costs a search.
    public static func lexicalFolder(forFileNamed name: String, among folders: [String]) -> String? {
        let stem = ((name as NSString).deletingPathExtension).lowercased()
        let words = stem.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard !words.isEmpty else { return nil }
        var hits: [String] = []
        for folder in folders {
            let key = folder.lowercased()
            // Either direction: a folder "rechnungen" holds a file word "rechnung", and a folder
            // "scan" holds "scan001". Four characters, so a stray "de" or "abc" cannot carry it.
            if words.contains(where: { w in
                let (short, long) = w.count <= key.count ? (w, key) : (key, w)
                return short.count >= 4 && long.hasPrefix(short)
            }) {
                hits.append(folder)
            }
        }
        return hits.count == 1 ? hits[0] : nil
    }

    /// Where a classified file belongs, relative to the folder it is in — or nil when its
    /// classification says nothing to file it by.
    ///
    /// Built from what `Classify` has already worked out, so filing costs no further generation:
    /// the kind is the folder, and the year below it when the document states a date. A file
    /// without a date is filed by kind alone rather than under a guessed year — mixed depth in one
    /// run is the honest outcome, and the preview shows every row, so nobody has to deduce it.
    ///
    /// The year is taken from the date rather than from the file system on purpose. `Classify`
    /// only records a date the document itself states (see `dateSupported`), and "the year this
    /// was last written to" is a different fact that would file a 2019 contract under 2026 because
    /// someone opened it.
    public static func filingPath(kind: String, date: String) -> String? {
        let folder = sanitize(folder: kind, matching: [])
        guard !folder.isEmpty, !isPlaceholder(folder) else { return nil }
        let year = String(date.prefix(4))
        guard year.count == 4, year.allSatisfy(\.isNumber), let value = Int(year),
              value >= 1900, value <= 2200 else { return folder }
        return folder + "/" + year
    }

    // MARK: - Renaming a selection

    /// Why a proposed rename is not in the batch. Reported, never silently dropped: a reader
    /// who selected forty files and sees thirty-eight rows needs to know about the other two.
    public struct Skipped: Sendable, Equatable {
        public enum Reason: String, Sendable, Equatable {
            case unchanged   // the model proposed the name the file already has
            case unusable    // empty after sanitising
            case duplicate   // two files would end up with one name
        }
        public let name: String
        public let reason: Reason
        public init(name: String, reason: Reason) { self.name = name; self.reason = reason }
    }

    /// The arguments for one `rename_batch` call, plus what did not make it in.
    public struct RenameBatch: Sendable, Equatable {
        public let directory: String
        public let oldNames: [String]
        public let newNames: [String]
        public let skipped: [Skipped]
        public var isEmpty: Bool { oldNames.isEmpty }
        public init(directory: String, oldNames: [String], newNames: [String], skipped: [Skipped]) {
            self.directory = directory; self.oldNames = oldNames
            self.newNames = newNames; self.skipped = skipped
        }
    }

    /// Line up proposed renames into the two parallel lists `rename_batch` requires.
    ///
    /// The catalogue entry is explicit that "the two lists must line up one to one, and nothing
    /// is renamed if any name is unusable" — so a batch that reaches the tool with one bad pair
    /// renames *nothing*. Filtering here is what turns forty proposals with two collisions into
    /// thirty-eight renames and two reported skips, instead of an all-or-nothing refusal the
    /// reader cannot act on.
    ///
    /// `occupied` is the names already in the folder that are not part of this batch; a proposal
    /// landing on one of them would collide with a file nobody asked to touch.
    public static func renameBatch(directory: String,
                                   proposals: [(old: String, new: String)],
                                   occupied: Set<String> = []) -> RenameBatch {
        var oldNames: [String] = []
        var newNames: [String] = []
        var skipped: [Skipped] = []
        // Case-insensitively, because the file systems this ships on mostly are: proposing
        // "Report.pdf" while "report.pdf" stays put is a collision, not a rename.
        var taken = Set(occupied.map { $0.lowercased() })
        let renamed = Set(proposals.map { $0.old.lowercased() })
        taken.subtract(renamed)

        for p in proposals {
            let new = p.new.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !new.isEmpty, !new.contains("/"), new != ".", new != ".." else {
                skipped.append(Skipped(name: p.old, reason: .unusable)); continue
            }
            guard new != p.old else {
                skipped.append(Skipped(name: p.old, reason: .unchanged)); continue
            }
            guard taken.insert(new.lowercased()).inserted else {
                skipped.append(Skipped(name: p.old, reason: .duplicate)); continue
            }
            oldNames.append(p.old)
            newNames.append(new)
        }
        return RenameBatch(directory: directory, oldNames: oldNames,
                           newNames: newNames, skipped: skipped)
    }

    // MARK: - Making model output usable

    /// Tags as a file manager can store them: short, lower case, unique, at most `limit`.
    /// The model is asked for four short tags and sometimes answers with a sentence per tag.
    public static func sanitize(tags: [String], limit: Int = 4) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in tags {
            let tag = raw.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet.punctuationCharacters)
            guard !tag.isEmpty, tag.count <= 24, !tag.contains(" "),
                  seen.insert(tag).inserted else { continue }
            out.append(tag)
            if out.count == limit { break }
        }
        return out
    }

    /// A model-proposed folder has to be usable as one: a single component, no separators — and
    /// snapped to a folder already chosen when it differs from it only in case or spacing.
    ///
    /// The snapping is what stops "Invoices", "invoices" and "Invoices " becoming three folders.
    /// The model is told to reuse an existing name and mostly does; this is what happens when it
    /// nearly does.
    public static func sanitize(folder: String, matching existing: [String]) -> String {
        var candidate = (folder as NSString).lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        while candidate.hasPrefix(".") { candidate.removeFirst() }
        guard !candidate.isEmpty else { return "" }
        let key = foldingKey(candidate)
        if let match = existing.first(where: { foldingKey($0) == key }) { return match }
        return String(candidate.prefix(60))
    }

    /// The proposed folder names that are actually usable as categories.
    ///
    /// Two rules, both learned from a run: a name that is one of the files is not a category — the
    /// model answered "rechnung-a" for `rechnung-a.txt` and every other file was then filed under
    /// it — and two spellings of one folder are one folder. Capped, because a tidy-up into more
    /// folders than a reader can hold in mind has not tidied anything.
    /// - Parameter limit: an upper bound on how many categories are worth having. The caller's
    ///   value is narrowed to half the file count, because a category needs at least two files to
    ///   be a grouping: two files can only ever justify one category, and asked to sort two the
    ///   model sometimes offers two — after which every group holds one file and the whole action
    ///   reports that nothing groups. Measured as a coin toss on the same pair across runs.
    public static func usableFolders(_ proposed: [String], fileNames: [String],
                                     limit: Int = 6) -> [String] {
        let limit = max(1, min(limit, fileNames.count / 2))
        let fileKeys = Set(fileNames.map { foldingKey(($0 as NSString).deletingPathExtension) })
        var seen = Set<String>()
        var out: [String] = []
        for raw in proposed {
            let folder = sanitize(folder: raw, matching: out)
            guard !folder.isEmpty else { continue }
            let key = foldingKey(folder)
            guard !fileKeys.contains(key), seen.insert(key).inserted else { continue }
            out.append(folder)
            if out.count == limit { break }
        }
        return out
    }

    /// Files an organise must never touch, whatever the model says about them.
    ///
    /// `descript.ion` is the comment sidecar the host writes — and `set_comment` had just created
    /// it, so the first tidy-up after commenting a file proposed moving the comments away from the
    /// files they describe. Dot-files are excluded by the caller; these are the ones with ordinary
    /// names and a meaning that belongs to the folder rather than to the reader.
    public static let sidecarNames: Set<String> = ["descript.ion", "descript.ion.bak", "folder.jpg"]

    /// Is this a file an organise may move?
    public static func isOrganisable(_ name: String) -> Bool {
        !name.hasPrefix(".") && !sidecarNames.contains(name.lowercased())
    }

    /// File types a picture-reading pass can make sense of.
    ///
    /// By extension rather than by sniffing the bytes, because the caller is deciding which of two
    /// tools to reach for and a wrong guess costs a wasted read, not a wrong answer. PDFs are not
    /// here: they carry their own text and `read_file` already gets it.
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp",
    ]

    /// Is this a file whose meaning is in its pixels rather than its bytes?
    public static func isImage(_ name: String) -> Bool {
        imageExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    // MARK: - A table pulled out of a file

    /// A table the assistant read out of a file: a header row and the rows under it.
    ///
    /// Structured rather than a block of Markdown, because the reader wants it in two shapes —
    /// pasted into a document and saved as a spreadsheet — and turning Markdown back into cells
    /// to get the second one would be parsing something we had just finished formatting.
    public struct Table: Sendable, Equatable {
        public let headers: [String]
        public let rows: [[String]]
        public init(headers: [String], rows: [[String]]) {
            self.headers = headers
            self.rows = rows
        }
        public var isEmpty: Bool { headers.isEmpty || rows.isEmpty }
    }

    /// Every row padded or trimmed to the header count, and rows that say nothing dropped.
    ///
    /// The model fills a typed schema, so a table always arrives well-formed in the sense that it
    /// parses — but not in the sense that every row has as many cells as there are columns. A short
    /// row would silently shift the remaining values one column left in the CSV.
    public static func table(headers: [String], rows: [[String]]) -> Table {
        let clean = headers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !clean.isEmpty else { return Table(headers: [], rows: []) }
        let sized = rows.map { row -> [String] in
            let cells = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            return cells.count >= clean.count ? Array(cells.prefix(clean.count))
                                              : cells + Array(repeating: "", count: clean.count - cells.count)
        }
        return Table(headers: clean, rows: sized.filter { $0.contains { !$0.isEmpty } })
    }

    /// The table as Markdown, for reading and for pasting into a document.
    public static func markdown(_ t: Table) -> String {
        guard !t.isEmpty else { return "" }
        // A pipe inside a cell would end the column early, and a newline would end the row.
        func cell(_ v: String) -> String {
            v.replacingOccurrences(of: "|", with: "\\|")
                .replacingOccurrences(of: "\n", with: " ")
        }
        var md = "| " + t.headers.map(cell).joined(separator: " | ") + " |\n"
        md += "| " + t.headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
        for row in t.rows { md += "| " + row.map(cell).joined(separator: " | ") + " |\n" }
        return md
    }

    /// The table as CSV (RFC 4180), for a spreadsheet.
    public static func csv(_ t: Table) -> String {
        guard !t.isEmpty else { return "" }
        func cell(_ v: String) -> String {
            guard v.contains(",") || v.contains("\"") || v.contains("\n") else { return v }
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return ([t.headers] + t.rows).map { $0.map(cell).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    /// Words a model reaches for when it has nothing to say, which must not become a value.
    ///
    /// "none" arrived as a *topic* and would have become a file called `none-2024-04-03.txt`. A
    /// model handed a field it cannot fill answers with the nearest word it can see, so the guard
    /// belongs here rather than in a prompt.
    static let placeholderWords: Set<String> = [
        "none", "n/a", "na", "unknown", "unspecified", "empty", "null", "nil", "-", "?",
        "keine", "unbekannt", "leer", "kein", "aucun", "ninguno", "nessuno", "geen", "brak",
    ]

    /// Is this the model saying "I don't know" rather than an answer?
    public static func isPlaceholder(_ value: String) -> Bool {
        let v = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty || placeholderWords.contains(v)
    }

    /// A topic as a file name can carry it: lower case, a few words, joined by hyphens.
    ///
    /// This ends up inside a rename mask, so anything a file name cannot hold has to go here
    /// rather than surface as a rename that fails. Three words at most — the mask supplies the
    /// date and the extension, and a topic that repeats the whole document is not a topic.
    public static func sanitize(topic: String) -> String {
        guard !isPlaceholder(topic) else { return "" }
        let words = topic.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
        return String(words.prefix(3).joined(separator: "-").prefix(40))
    }

    /// `YYYY-MM-DD`, or nothing. A model asked for a document's date will offer "March 2024",
    /// "12.03.2024" or a sentence; only the one shape belongs in a file name, and a date that
    /// cannot be read is better absent than guessed — an invented date in a file name outlives
    /// every chance of noticing it.
    public static func sanitize(date: String) -> String {
        let digits = date.split(whereSeparator: { !$0.isNumber }).map(String.init)
        guard digits.count == 3, digits[0].count == 4,
              let year = Int(digits[0]), let month = Int(digits[1]), let day = Int(digits[2]),
              (1000...9999).contains(year), (1...12).contains(month), (1...31).contains(day)
        else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// The word every one of these file names begins with, if there is one worth using.
    ///
    /// The last resort when the model will not name a category. On a small set it answers with the
    /// file names themselves often enough to be unreliable — measured, the same two files passed
    /// one run and failed the next — and `urlaub-kreta.txt` beside `urlaub-norwegen.txt` needs no
    /// model to see that "Urlaub" is the category. Deterministic, so the small case stops being a
    /// coin toss.
    ///
    /// Nil unless every name shares the leading word and it is long enough to mean something.
    public static func commonPrefixCategory(of names: [String]) -> String? {
        guard names.count > 1 else { return nil }
        func firstWord(_ name: String) -> String {
            let base = (name as NSString).deletingPathExtension
            return base.split(whereSeparator: { !$0.isLetter }).first.map(String.init)?.lowercased() ?? ""
        }
        let words = names.map(firstWord)
        guard let first = words.first, first.count >= 3, words.allSatisfy({ $0 == first }) else {
            return nil
        }
        return first.prefix(1).uppercased() + first.dropFirst()
    }

    /// Does the text actually support this date, or did the model fill in the gaps?
    ///
    /// Asking nicely does not settle this. Told twice, in the instructions and in the field's own
    /// guide, that a season is not a date, the model still answered `2023-07-01` for "Reisenotizen
    /// Kreta, Sommer 2023" — a plausible day and month, invented whole, on its way into a file
    /// name where nobody would ever catch it.
    ///
    /// So the text decides. Either route is enough, and each covers what the other cannot:
    ///
    /// 1. Every part appears as a number — year, month and day. The month was missing from this
    ///    check, and that is not a hypothetical: a Classify run gave an invoice `2024-08-12` where
    ///    the paper says `12.03.2024`. Both "2024" and "12" are in the text, so the date passed a
    ///    check that never looked at the month, and a wrong date went on its way into a rename mask.
    /// 2. `NSDataDetector` found exactly this date in the text. That is what keeps a date written
    ///    in words — "1. April 2019" — which has no "04" anywhere for route 1 to find.
    ///
    /// Only detector matches whose own text carries a four-digit year count. The detector resolves
    /// "due in 14 days" against today and returns a real date for it, which says nothing about the
    /// document and would hand back the very answer the instructions forbid.
    ///
    /// This can only ever *remove* a date, which is the safe direction — a missing date leaves a
    /// gap in a rename mask, an invented one leaves a lie in a file name.
    public static func dateSupported(_ date: String, by text: String) -> Bool {
        let parts = date.split(separator: "-").map(String.init)
        guard parts.count == 3, let day = Int(parts[2]), let month = Int(parts[1]) else { return false }
        let digits = Set(text.split(whereSeparator: { !$0.isNumber }).map(String.init))
        // The day and month may be written with or without a leading zero; in a date the text
        // spells out in full ("2024-03-09") they appear padded.
        func present(_ padded: String, _ bare: Int) -> Bool {
            digits.contains(padded) || digits.contains(String(bare))
        }
        if digits.contains(parts[0]), present(parts[1], month), present(parts[2], day) { return true }
        return detectedDates(in: text).contains(date)
    }

    /// The dates `NSDataDetector` reads out of `text`, as `yyyy-MM-dd`, skipping any match that
    /// does not spell a year out itself. UTC, because the answer is a calendar date and not a moment.
    static func detectedDates(in text: String) -> Set<String> {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        var out: Set<String> = []
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let date = match.date, let range = Range(match.range, in: text) else { continue }
            let run = text[range]
            guard run.split(whereSeparator: { !$0.isNumber }).contains(where: { $0.count == 4 })
            else { continue }
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            out.insert(String(format: "%04lld-%02lld-%02lld",
                              Int64(c.year ?? 0), Int64(c.month ?? 0), Int64(c.day ?? 0)))
        }
        return out
    }

    /// Match a model's answer to one of the folders it was given, or nil when none of them fits.
    ///
    /// Exact-equality was too strict to be useful: asked to file "urlaub-kreta.txt" under the one
    /// category it had just proposed, "Reisenotizen", the model answered "Reisen" — a paraphrase,
    /// not a refusal — and the whole tidy-up reported that nothing groups. So a candidate also
    /// matches when one name contains the other, and a single-category list is taken as the answer
    /// whatever came back, because there was nothing else it could have meant.
    public static func snap(_ answer: String, to folders: [String]) -> String? {
        guard !folders.isEmpty, !isPlaceholder(answer) else { return nil }
        let key = foldingKey(answer)
        if !key.isEmpty {
            if let exact = folders.first(where: { foldingKey($0) == key }) { return exact }
            if let near = folders.first(where: {
                let f = foldingKey($0)
                return !f.isEmpty && (f.contains(key) || key.contains(f))
            }) { return near }
        }
        return folders.count == 1 ? folders[0] : nil
    }

    /// Case, spacing and word separators removed, so two spellings of one folder compare equal.
    public static func foldingKey(_ name: String) -> String {
        name.lowercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
    }
}
