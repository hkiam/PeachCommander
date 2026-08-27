// SPDX-License-Identifier: Apache-2.0
// The ranking behind `semantic_search`. Every case below is one that was measured against the
// running app first — three of them were defects found that way, with nothing to catch a return.
//
// No language model anywhere: the scorer is injected, so what is asserted is the order, and the
// order is where the defects were.

import XCTest
@testable import PCAutomation

final class SemanticRankerTests: XCTestCase {

    private func candidate(_ name: String, _ sample: String = "") -> SemanticRanker.Candidate {
        .init(name: name, sample: sample)
    }

    // MARK: - What is compared

    func testAPageIsReducedToItsContentWords() {
        let text = "Rechnung Nr. 2024-0871\nMeier Dachdeckerei GmbH, Hamburg\nBetrag 1450,00 EUR"
        let words = SemanticRanker.keywords(text).split(separator: " ").map(String.init)
        XCTAssertTrue(words.contains("rechnung"))
        XCTAssertTrue(words.contains("dachdeckerei"))
        XCTAssertFalse(words.contains("nr"), "short words carry the grammar, not the subject")
        XCTAssertFalse(words.contains("eur"))
        // Numbers survive, and the tokenizer keeps a decimal together: "1450,00" is one word, not
        // two. Written down because it is the kind of thing a reader would assume the other way —
        // it adds a little noise, and the measurements that chose this floor were taken with it.
        XCTAssertTrue(words.contains("1450,00"))
        XCTAssertTrue(words.contains("2024"))
    }

    func testAWordIsKeptOnceAndInOrder() {
        XCTAssertEqual(SemanticRanker.keywords("Rechnung Reparatur rechnung REPARATUR Dach"),
                       "rechnung reparatur dach")
    }

    func testTheWordCountIsCapped() {
        let many = (1...60).map { "wort\($0)" }.joined(separator: " ")
        XCTAssertEqual(SemanticRanker.keywords(many, limit: 25).split(separator: " ").count, 25)
    }

    // MARK: - The phrase to compare against

    func testAPhraseLosesItsFillerWords() {
        // Measured: handed over whole, this ranked the lease first and the invoice second over the
        // folder it names; condensed, the invoice comes first.
        XCTAssertEqual(SemanticRanker.comparablePhrase("die Rechnung über das Dach"),
                       "rechnung über dach")
    }

    func testAPhraseWithNothingLeftFallsBackToItself() {
        // An empty left-hand side makes every distance meaningless rather than merely unhelpful.
        XCTAssertEqual(SemanticRanker.comparablePhrase("log"), "log")
        XCTAssertEqual(SemanticRanker.comparablePhrase("S3"), "s3")
    }

    // MARK: - Literal matching, for when no embedding fits the query

    func testLiteralMatchingKeepsEveryWordAsTyped() {
        // The four-character floor must not reach this path: these are the terms people search
        // literally for.
        XCTAssertEqual(SemanticRanker.lexical(query: "log", text: "app log output"), 1.0)
        XCTAssertEqual(SemanticRanker.lexical(query: "rechnung dach",
                                              text: "rechnung für das dach"), 1.0)
        XCTAssertEqual(SemanticRanker.lexical(query: "rechnung dach", text: "nur rechnung"), 0.5)
        XCTAssertEqual(SemanticRanker.lexical(query: "", text: "irgendwas"), 0)
    }

    // MARK: - The order

    func testContentCanOutrankAName() {
        // The defect this whole file exists for: the file whose *contents* matched best came back
        // last, because the name was given a tenth of a head start in a range only half that wide.
        let files = [candidate("nginx.conf", "worker_processes auto; server_name shop"),
                     candidate("scan_0042.txt", "Rechnung Meier Dachdeckerei Dacheindeckung")]
        let order = SemanticRanker.rank(files, limit: 5) { text in
            text.contains("rechnung") ? 0.923 : (text.contains("nginx") ? 0.892 : 0.1)
        }
        XCTAssertEqual(order.first, "scan_0042.txt")
    }

    func testABinarySampleIsNotCompared() {
        // A binary read as a string is noise; only the name should count for it.
        let binary = String(repeating: "\u{FFFD}", count: 200)
        XCTAssertFalse(SemanticRanker.looksLikeText(binary))
        let order = SemanticRanker.rank([candidate("bild.png", binary)], limit: 5) { text in
            text.isEmpty ? 0 : (text.contains("bild") ? 0.5 : 9.9)
        }
        XCTAssertEqual(order, ["bild.png"], "scored by its name, never by its bytes")
    }

    func testNothingScoringIsAnEmptyAnswer() {
        // Only when the scorer itself says nothing at all — no embedding fits the query and no word
        // of it appears anywhere. This is NOT "the folder is unrelated": measured, a query about
        // nothing in the folder scores higher and stands out more than a real match, so nothing
        // here can decide that. See the note in `rank`.
        XCTAssertEqual(SemanticRanker.rank([candidate("a.txt"), candidate("b.txt")],
                                           limit: 5) { _ in 0 }, [])
    }

    func testAnUnrelatedQueryStillGetsTheWholeRanking() {
        // Written down so the promise is not quietly reintroduced: with everything scoring in one
        // narrow band, which is what the embedding does, the cutoff keeps them all. The caller's
        // sheet is titled "Closest matches" for exactly this reason.
        let files = [candidate("a.txt"), candidate("b.txt"), candidate("c.txt")]
        let order = SemanticRanker.rank(files, limit: 5) { text in
            text.hasPrefix("a") ? 0.99 : (text.hasPrefix("b") ? 0.94 : 0.86)
        }
        XCTAssertEqual(order, ["a.txt", "b.txt", "c.txt"])
    }

    func testTheBestMatchIsAlwaysReturned() {
        // An absolute floor used to throw away the best match too whenever the whole folder scored
        // low, and "no file matches" is a worse answer than a weak one.
        let order = SemanticRanker.rank([candidate("a.txt"), candidate("b.txt")], limit: 5) { text in
            text.hasPrefix("a") ? 0.02 : 0.001
        }
        XCTAssertEqual(order.first, "a.txt")
    }

    func testDistantCandidatesAreLeftOut() {
        // Everything above zero is not an answer: a caller reads the whole folder back as "these
        // are all about it" and passes that on.
        let order = SemanticRanker.rank([candidate("treffer.txt"), candidate("fern.txt")],
                                        limit: 5) { text in
            text.hasPrefix("treffer") ? 1.0 : 0.5      // 0.5 is below 70% of the best
        }
        XCTAssertEqual(order, ["treffer.txt"])
    }

    func testCloseCandidatesKeepTheWinnerCompany() {
        let order = SemanticRanker.rank([candidate("treffer.txt"), candidate("nah.txt")],
                                        limit: 5) { text in
            text.hasPrefix("treffer") ? 1.0 : 0.8
        }
        XCTAssertEqual(order, ["treffer.txt", "nah.txt"])
    }

    func testTheLimitIsHonouredAndNeverZero() {
        let files = (1...5).map { candidate("datei\($0).txt") }
        XCTAssertEqual(SemanticRanker.rank(files, limit: 2) { _ in 1.0 }.count, 2)
        XCTAssertEqual(SemanticRanker.rank(files, limit: 0) { _ in 1.0 }.count, 1,
                       "a limit of zero must still answer, or the tool reports nothing found")
    }

    func testASeparatorInANameIsNotPartOfTheWord() {
        XCTAssertEqual(SemanticRanker.readableName("quartals_bericht-q3.txt"), "quartals bericht q3")
    }
}
