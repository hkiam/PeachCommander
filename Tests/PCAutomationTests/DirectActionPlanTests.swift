// SPDX-License-Identifier: Apache-2.0
// DirectActionPlanTests.swift - the arithmetic a direct action does around the model.
//
// A direct action asks the model once per file and then decides everything else itself: which
// folders the answers collapse into, which proposed renames are renames at all, and which would
// put two files on one name. None of that involves a model, so all of it is pinned here — which
// is the point of the logic living in PCAutomation rather than in the plugin.
//
// The `rename_batch` cases matter most. Its two lists are positional and the tool renames nothing
// if any pair is unusable, so a single bad proposal in a selection of forty either loses the whole
// batch or — far worse — shifts the remaining pairs onto the wrong names.

import XCTest
@testable import PCAutomation

final class DirectActionPlanTests: XCTestCase {

    private func assignment(_ path: String, _ folder: String) -> DirectActionPlan.Assignment {
        DirectActionPlan.Assignment(path: path, subfolder: folder, reason: "because")
    }

    // MARK: - Organising a folder

    func testFilesCollapseIntoOneGroupPerFolder() {
        let groups = DirectActionPlan.group([
            assignment("/f/a.pdf", "Invoices"),
            assignment("/f/b.jpg", "Photos"),
            assignment("/f/c.pdf", "Invoices"),
        ])
        XCTAssertEqual(groups.map(\.subfolder), ["Invoices", "Photos"])
        XCTAssertEqual(groups.first?.sources, ["/f/a.pdf", "/f/c.pdf"])
    }

    func testGroupOrderIsTheOrderTheFoldersWereFirstProposed() {
        // The sheet shows this list and the reader checks it against the panel, so the ordering
        // is part of the answer rather than an implementation detail.
        let groups = DirectActionPlan.group([
            assignment("/f/z.txt", "Later"),
            assignment("/f/a.txt", "Earlier"),
            assignment("/f/y.txt", "Later"),
        ])
        XCTAssertEqual(groups.map(\.subfolder), ["Later", "Earlier"])
    }

    func testAFileWithNoUsableFolderIsLeftWhereItIs() {
        let groups = DirectActionPlan.group([
            assignment("/f/a.pdf", ""),
            assignment("/f/b.pdf", "   "),
            assignment("/f/c.pdf", "Invoices"),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.sources, ["/f/c.pdf"])
    }

    func testTwoFilesCanOnlyJustifyOneCategory() {
        // A category needs two files to be a grouping. Offered two for two files, every group
        // would hold one and the action would report that nothing groups at all.
        XCTAssertEqual(DirectActionPlan.usableFolders(["Reisen", "Notizen"],
                                                      fileNames: ["a.txt", "b.txt"]), ["Reisen"])
        XCTAssertEqual(DirectActionPlan.usableFolders(["Reisen", "Notizen", "Rechnungen"],
                                                      fileNames: ["a", "b", "c", "d"]).count, 2)
    }

    func testNamesSharingTheirFirstWordNameTheirOwnCategory() {
        // The last resort when the model will not name one. Measured as a coin toss on two files:
        // the same pair passed one run and failed the next, and no prompt settled it.
        XCTAssertEqual(DirectActionPlan.commonPrefixCategory(
            of: ["urlaub-kreta.txt", "urlaub-norwegen.txt"]), "Urlaub")
        XCTAssertEqual(DirectActionPlan.commonPrefixCategory(
            of: ["rechnung_1.pdf", "rechnung 2.pdf", "Rechnung-3.pdf"]), "Rechnung")
    }

    func testNoSharedWordMeansNoCategory() {
        // Better nothing than a category invented out of a coincidence.
        XCTAssertNil(DirectActionPlan.commonPrefixCategory(of: ["a-x.txt", "b-y.txt"]))
        XCTAssertNil(DirectActionPlan.commonPrefixCategory(of: ["im-a.txt", "im-b.txt"]))  // too short
        XCTAssertNil(DirectActionPlan.commonPrefixCategory(of: ["only-one.txt"]))
    }

    func testAFolderHoldingOneFileIsNotWorthMaking() {
        // Forty folders for forty files is this feature's failure mode, and it is exactly what a
        // model does when it names a folder after each file.
        let groups = DirectActionPlan.group([
            assignment("/f/a.pdf", "Invoices"),
            assignment("/f/b.pdf", "Invoices"),
            assignment("/f/c.pdf", "Odd One"),
        ])
        let worth = DirectActionPlan.groupsWorthMaking(groups)
        XCTAssertEqual(worth.map(\.subfolder), ["Invoices"])
    }

    func testOneFolderHoldingEverythingIsNotAGrouping() {
        // The mirror of the rule above, and the one that actually moves files when it is missing:
        // the model proposed the single category "projekte" for two invoices and two sets of
        // minutes, and all four would have been filed under it. Nothing is grouped by that — the
        // folder is the one they were already in, one level down.
        let groups = DirectActionPlan.group([
            assignment("/f/a.pdf", "Projekte"),
            assignment("/f/b.pdf", "Projekte"),
            assignment("/f/c.pdf", "Projekte"),
        ])
        XCTAssertEqual(DirectActionPlan.groupsWorthMaking(groups, of: 3), [])
    }

    func testOneFolderTakingSomeOfTheFilesIsStillAGrouping() {
        // The case the rule must not eat: a mixed folder where the invoices group and the rest
        // stay put is exactly what a tidy-up is for, even though it makes only one folder.
        let groups = DirectActionPlan.group([
            assignment("/f/a.pdf", "Invoices"),
            assignment("/f/b.pdf", "Invoices"),
        ])
        XCTAssertEqual(DirectActionPlan.groupsWorthMaking(groups, of: 5).map(\.subfolder),
                       ["Invoices"])
    }

    func testTheRuleIsOffWhenTheCountIsNotGiven() {
        // Callers that do not pass `of:` keep the old behaviour rather than silently losing groups.
        let groups = DirectActionPlan.group([
            assignment("/f/a.pdf", "Projekte"), assignment("/f/b.pdf", "Projekte"),
        ])
        XCTAssertEqual(DirectActionPlan.groupsWorthMaking(groups).map(\.subfolder), ["Projekte"])
    }

    // MARK: - Filing a file the model declined to file

    func testANameThatMatchesExactlyOneCategoryIsFiledThere() {
        // The measured miss: "rechnungen" was on the list and the model still answered nothing.
        XCTAssertEqual(DirectActionPlan.lexicalFolder(forFileNamed: "rechnung-dach.txt",
                                                      among: ["protokolle", "rechnungen"]),
                       "rechnungen")
        XCTAssertEqual(DirectActionPlan.lexicalFolder(forFileNamed: "protokoll-juni.txt",
                                                      among: ["protokolle", "rechnungen"]),
                       "protokolle")
    }

    func testANameMatchingTwoCategoriesIsLeftAlone() {
        // Ambiguous means the names do not settle it. A file left where it is costs a second run;
        // a file in the wrong folder costs a search.
        XCTAssertNil(DirectActionPlan.lexicalFolder(forFileNamed: "rechnung-protokoll.txt",
                                                    among: ["protokolle", "rechnungen"]))
    }

    func testANameMatchingNothingIsLeftAlone() {
        XCTAssertNil(DirectActionPlan.lexicalFolder(forFileNamed: "IMG_4021.heic",
                                                    among: ["protokolle", "rechnungen"]))
    }

    func testAShortWordCannotCarryTheMatch() {
        // Without the four-character floor, "de" in a name would file it under "Design".
        XCTAssertNil(DirectActionPlan.lexicalFolder(forFileNamed: "de-01.txt", among: ["Design"]))
    }

    func testTheFolderMayBeTheShorterOfTheTwo() {
        // The other direction: a folder "scan" takes "scan001.png".
        XCTAssertEqual(DirectActionPlan.lexicalFolder(forFileNamed: "scan001.png",
                                                      among: ["scan", "briefe"]),
                       "scan")
    }

    func testTheExtensionIsNotAWord() {
        // Otherwise every .txt in a folder with a "Text" category would be filed by its extension.
        XCTAssertNil(DirectActionPlan.lexicalFolder(forFileNamed: "a.text", among: ["Texte"]))
    }

    // MARK: - Renaming a selection

    func testTheTwoListsLineUpOneToOne() {
        let batch = DirectActionPlan.renameBatch(
            directory: "/f", proposals: [("a.txt", "alpha.txt"), ("b.txt", "beta.txt")])
        XCTAssertEqual(batch.oldNames, ["a.txt", "b.txt"])
        XCTAssertEqual(batch.newNames, ["alpha.txt", "beta.txt"])
        XCTAssertTrue(batch.skipped.isEmpty)
    }

    func testASkippedPairDoesNotShiftTheOnesAfterIt() {
        // The failure this whole type exists to prevent: drop "b" from one list only and "c"
        // is renamed to "beta.txt". It applies cleanly and renames the wrong file.
        let batch = DirectActionPlan.renameBatch(directory: "/f", proposals: [
            ("a.txt", "alpha.txt"),
            ("b.txt", "b.txt"),           // unchanged — not a rename
            ("c.txt", "gamma.txt"),
        ])
        XCTAssertEqual(batch.oldNames, ["a.txt", "c.txt"])
        XCTAssertEqual(batch.newNames, ["alpha.txt", "gamma.txt"])
        XCTAssertEqual(batch.skipped, [.init(name: "b.txt", reason: .unchanged)])
    }

    func testTwoFilesAreNeverSentToOneName() {
        let batch = DirectActionPlan.renameBatch(directory: "/f", proposals: [
            ("a.txt", "report.txt"), ("b.txt", "report.txt"),
        ])
        XCTAssertEqual(batch.oldNames, ["a.txt"])
        XCTAssertEqual(batch.skipped, [.init(name: "b.txt", reason: .duplicate)])
    }

    func testACollisionIsJudgedTheWayTheFileSystemWould() {
        // The disks this ships on are mostly case-insensitive, so "Report.txt" beside
        // "report.txt" is a collision even though the strings differ.
        let batch = DirectActionPlan.renameBatch(directory: "/f", proposals: [
            ("a.txt", "Report.txt"), ("b.txt", "report.txt"),
        ])
        XCTAssertEqual(batch.oldNames, ["a.txt"])
        XCTAssertEqual(batch.skipped.map(\.reason), [.duplicate])
    }

    func testAProposalLandingOnAFileNobodyAskedToTouchIsRefused() {
        let batch = DirectActionPlan.renameBatch(
            directory: "/f", proposals: [("a.txt", "notes.txt")],
            occupied: ["notes.txt", "a.txt"])
        XCTAssertTrue(batch.isEmpty)
        XCTAssertEqual(batch.skipped, [.init(name: "a.txt", reason: .duplicate)])
    }

    func testAFileMayTakeANameBeingVacatedInTheSameBatch() {
        // "a" becomes "b" while "b" becomes "c" — legal, because rename_batch applies the batch
        // as one step. Treating the occupied "b.txt" as a blocker would refuse a valid rotation.
        let batch = DirectActionPlan.renameBatch(
            directory: "/f", proposals: [("b.txt", "c.txt"), ("a.txt", "b.txt")],
            occupied: ["a.txt", "b.txt"])
        XCTAssertEqual(batch.oldNames, ["b.txt", "a.txt"])
        XCTAssertEqual(batch.newNames, ["c.txt", "b.txt"])
        XCTAssertTrue(batch.skipped.isEmpty)
    }

    func testANameWithAPathInItIsUnusable() {
        let batch = DirectActionPlan.renameBatch(directory: "/f", proposals: [
            ("a.txt", "../elsewhere/a.txt"), ("b.txt", ""), ("c.txt", "  "),
        ])
        XCTAssertTrue(batch.isEmpty)
        XCTAssertEqual(batch.skipped.map(\.reason), [.unusable, .unusable, .unusable])
    }

    // MARK: - Making model output usable

    // MARK: - Facts that end up inside a file name

    func testAModelSayingNothingProducesNothing() {
        // "none" came back as a topic and would have produced a file called none-2024-04-03.txt.
        XCTAssertEqual(DirectActionPlan.sanitize(topic: "none"), "")
        XCTAssertEqual(DirectActionPlan.sanitize(topic: "Keine"), "")
        XCTAssertEqual(DirectActionPlan.sanitize(topic: "-"), "")
        XCTAssertNil(DirectActionPlan.snap("none", to: ["Invoices"]))
        // And a real answer is still a real answer.
        XCTAssertEqual(DirectActionPlan.sanitize(topic: "Nonprofit Report"), "nonprofit-report")
    }

    func testATopicIsShapedLikeAFileName() {
        XCTAssertEqual(DirectActionPlan.sanitize(topic: "Dachreparatur Nordflügel"), "dachreparatur-nordflügel")
        XCTAssertEqual(DirectActionPlan.sanitize(topic: "Invoice #4711 (paid)"), "invoice-4711-paid")
    }

    func testATopicIsThreeWordsAtMost() {
        // The mask supplies the date and the extension; a topic that repeats the whole document
        // makes the 70-character file names this feature exists to avoid.
        XCTAssertEqual(DirectActionPlan.sanitize(topic: "rechnung nr 4711 dachreparatur nordflügel 2480 eur"),
                       "rechnung-nr-4711")
    }

    func testADateTheTextDoesNotContainIsDropped() {
        // The failure this exists for: "Sommer 2023" came back as 2023-07-01, a day and a month
        // invented whole and on their way into a file name.
        XCTAssertFalse(DirectActionPlan.dateSupported("2023-07-01",
                                                      by: "Reisenotizen Kreta, Sommer 2023."))
        XCTAssertTrue(DirectActionPlan.dateSupported("2024-03-12",
                                                     by: "Rechnung vom 12. März 2024"))
        XCTAssertTrue(DirectActionPlan.dateSupported("2024-04-03",
                                                     by: "Rechnung vom 3. April 2024"))
        XCTAssertTrue(DirectActionPlan.dateSupported("2024-03-09", by: "dated 2024-03-09"))
        XCTAssertFalse(DirectActionPlan.dateSupported("2024-03-12", by: "no numbers here"))
        XCTAssertFalse(DirectActionPlan.dateSupported("", by: "12 March 2024"))
    }

    func testADateIsEitherReadableOrAbsent() {
        XCTAssertEqual(DirectActionPlan.sanitize(date: "2024-03-12"), "2024-03-12")
        XCTAssertEqual(DirectActionPlan.sanitize(date: "2024/3/9"), "2024-03-09")
        // An invented date in a file name outlives every chance of noticing it, so anything that
        // cannot be read is nothing.
        XCTAssertEqual(DirectActionPlan.sanitize(date: "March 2024"), "")
        XCTAssertEqual(DirectActionPlan.sanitize(date: "12.03.24"), "")
        XCTAssertEqual(DirectActionPlan.sanitize(date: "2024-13-40"), "")
        XCTAssertEqual(DirectActionPlan.sanitize(date: ""), "")
    }

    func testTagsAreShortLowerCaseAndUnique() {
        let tags = DirectActionPlan.sanitize(tags: ["Invoice", "invoice.", "  Taxes  ", "2024"])
        XCTAssertEqual(tags, ["invoice", "taxes", "2024"])
    }

    func testASentenceIsNotATag() {
        let tags = DirectActionPlan.sanitize(tags: ["a note about the roof repair", "roof"])
        XCTAssertEqual(tags, ["roof"])
    }

    func testAtMostFourTags() {
        XCTAssertEqual(DirectActionPlan.sanitize(tags: ["a", "b", "c", "d", "e"]).count, 4)
    }

    func testAParaphraseStillLandsInTheCategoryItMeant() {
        // Measured: given the single category "Reisenotizen" the model answered "Reisen", and an
        // exact-match check turned that into "no folder fits" — the tidy-up then reported that
        // nothing groups at all, for a set it had just categorised itself.
        XCTAssertEqual(DirectActionPlan.snap("Reisen", to: ["Reisenotizen"]), "Reisenotizen")
        XCTAssertEqual(DirectActionPlan.snap("Rechnungen 2024", to: ["Rechnungen"]), "Rechnungen")
    }

    func testASingleCategoryIsTheAnswerWhateverCameBack() {
        // With one folder on offer there is nothing else the model could have meant.
        XCTAssertEqual(DirectActionPlan.snap("something else entirely", to: ["Invoices"]), "Invoices")
    }

    func testAnAnswerMatchingNothingIsRefusedWhenThereIsAChoice() {
        // With a real choice, a name resembling none of them means none of them fits — and a file
        // left where it is beats one filed at random.
        XCTAssertNil(DirectActionPlan.snap("Zebra", to: ["Invoices", "Photos"]))
    }

    func testAFolderIsSnappedToOneAlreadyChosen() {
        // Without this, "Invoices", "invoices" and "Invoices " are three folders.
        XCTAssertEqual(DirectActionPlan.sanitize(folder: "invoices", matching: ["Invoices"]), "Invoices")
        XCTAssertEqual(DirectActionPlan.sanitize(folder: "Tax Returns", matching: ["Tax-Returns"]), "Tax-Returns")
    }

    func testAFolderIsNeverAPath() {
        XCTAssertEqual(DirectActionPlan.sanitize(folder: "/etc/passwd", matching: []), "passwd")
        XCTAssertEqual(DirectActionPlan.sanitize(folder: "a/b", matching: []), "b")
        XCTAssertEqual(DirectActionPlan.sanitize(folder: "\"Photos\"", matching: []), "Photos")
    }

    func testAHiddenFolderIsNotProposedByAccident() {
        XCTAssertEqual(DirectActionPlan.sanitize(folder: ".ssh", matching: []), "ssh")
    }

    func testAnUnusableFolderIsEmptySoTheFileStaysPut() {
        XCTAssertEqual(DirectActionPlan.sanitize(folder: "   ", matching: []), "")
        XCTAssertEqual(DirectActionPlan.sanitize(folder: "...", matching: []), "")
    }

    // MARK: - A table pulled out of a file

    func testARowShorterThanTheHeaderIsPaddedRatherThanShifted() {
        // The model fills a typed schema, so a table always parses — but nothing guarantees every
        // row has as many cells as there are columns. Dropping the check would move every later
        // value one column left in the CSV, which reads as data rather than as a fault.
        let t = DirectActionPlan.table(headers: ["Datum", "Betrag", "Zweck"],
                                       rows: [["2024-03-12", "480,00"]])
        XCTAssertEqual(t.rows, [["2024-03-12", "480,00", ""]])
    }

    func testARowLongerThanTheHeaderIsTrimmed() {
        let t = DirectActionPlan.table(headers: ["A", "B"], rows: [["1", "2", "3"]])
        XCTAssertEqual(t.rows, [["1", "2"]])
    }

    func testEmptyRowsAreNotRows() {
        let t = DirectActionPlan.table(headers: ["A"], rows: [["  "], ["x"]])
        XCTAssertEqual(t.rows, [["x"]])
    }

    func testCsvQuotesWhatWouldOtherwiseSplitTheRow() {
        let t = DirectActionPlan.table(headers: ["Zweck", "Betrag"],
                                       rows: [["Dach, Nordflügel", "2.480,00"],
                                              ["Er sagte \"ja\"", "0"]])
        XCTAssertEqual(DirectActionPlan.csv(t),
                       "Zweck,Betrag\n\"Dach, Nordflügel\",\"2.480,00\"\n\"Er sagte \"\"ja\"\"\",0\n")
    }

    func testMarkdownEscapesAPipeInsteadOfEndingTheColumn() {
        let t = DirectActionPlan.table(headers: ["A"], rows: [["x | y"]])
        XCTAssertTrue(DirectActionPlan.markdown(t).contains("x \\| y"),
                      DirectActionPlan.markdown(t))
    }

    func testATableWithoutHeadersIsNotATable() {
        XCTAssertTrue(DirectActionPlan.table(headers: ["", "  "], rows: [["a"]]).isEmpty)
        XCTAssertEqual(DirectActionPlan.csv(DirectActionPlan.Table(headers: [], rows: [])), "")
    }
}
