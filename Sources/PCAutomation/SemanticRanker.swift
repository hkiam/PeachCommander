// SPDX-License-Identifier: Apache-2.0
// SemanticRanker.swift - the ranking behind `semantic_search`, without the file system.
//
// It lived inside HostAutomationBridge, where nothing could reach it: no test target imports
// PCApp, because PCApp is the application rather than a framework. Three defects were found in
// this arithmetic by running the app by hand and reading the order it printed — a file whose
// content matched best came back last, and a two-word query came back empty. Each was fixed
// against a measurement and pinned by nothing.
//
// So the arithmetic moved here and the host kept the reading of files. The scorer is passed in,
// which means these tests need no language model: what is asserted is the ranking, and the
// ranking is where the defects were.

import Foundation
import NaturalLanguage

public enum SemanticRanker {

    /// One thing to rank: its name, and the beginning of its contents (empty when unread).
    public struct Candidate: Sendable, Equatable {
        public let name: String
        public let sample: String
        public init(name: String, sample: String) { self.name = name; self.sample = sample }
    }

    /// The content words of `text`, deduplicated, in the order they appear.
    ///
    /// A sentence embedding is built for a sentence. Handed a page — prose, a header row, a
    /// licence block — it averages into the middle, and the middle is where every file already
    /// sits. Measured over four files, embedding distance to a German query, best score per file:
    ///
    ///     "rechnung"            invoice   raw prefix 0.828   keywords 0.923
    ///     "temperaturmessungen" readings  raw prefix 0.668   keywords 1.107
    ///     "mietvertrag wohnung" contract  raw prefix 0.948   keywords 1.132
    ///
    /// The raw prefix put the readings file *last* for a query about readings.
    ///
    /// Words of four characters and up, twenty-five of them: short words carry the grammar rather
    /// than the subject, and past a couple of dozen the averaging sets in again.
    public static func keywords(_ text: String, limit: Int = 25) -> String {
        var seen = Set<String>()
        var out: [String] = []
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = text[range].lowercased()
            if word.count >= 4, seen.insert(word).inserted { out.append(word) }
            return out.count < limit
        }
        return out.joined(separator: " ")
    }

    /// "quartals_bericht-q3.txt" → "quartals bericht q3": separators carry no meaning here.
    public static func readableName(_ name: String) -> String {
        (name as NSString).deletingPathExtension
            .replacingOccurrences(of: "[_.\\-]", with: " ", options: .regularExpression)
            .lowercased()
    }

    /// Whether a sample is text at all — a binary read as a string is noise to an embedding.
    public static func looksLikeText(_ sample: String) -> Bool {
        guard !sample.isEmpty else { return false }
        let printable = sample.unicodeScalars.prefix(400).filter {
            $0 == "\n" || $0 == "\t" || $0 == "\r" || ($0.value >= 32 && $0.value != 0xFFFD)
        }.count
        return Double(printable) / Double(min(sample.unicodeScalars.count, 400)) > 0.9
    }

    public static func tokens(of text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// The phrase to compare against, condensed the same way the files are.
    ///
    /// "die Rechnung über das Dach" is three filler words and two real ones, and handed over whole
    /// it ranked the lease first and the invoice second over the folder it names; as "rechnung
    /// dach" the invoice comes first. A phrase that condenses to nothing falls back to itself:
    /// "log" and "S3" are shorter than the floor, and an empty left-hand side makes every distance
    /// meaningless rather than merely unhelpful.
    public static func comparablePhrase(_ query: String) -> String {
        let condensed = keywords(query)
        return condensed.isEmpty ? query.lowercased() : condensed
    }

    /// How much of the query's words `text` contains, 0...1.
    ///
    /// Every word as typed, not the condensed phrase: this runs when no embedding fits the query
    /// at all, and there the four-character floor would throw away exactly the terms people search
    /// literally for — "log", "S3", "PDF".
    public static func lexical(query: String, text: String) -> Double {
        let wanted = Set(tokens(of: query))
        guard !wanted.isEmpty else { return 0 }
        return Double(wanted.intersection(Set(tokens(of: text))).count) / Double(wanted.count)
    }

    /// The candidates worth returning, best first.
    ///
    /// - Parameter score: what one piece of text is worth against the query. Injected so the order
    ///   can be asserted without a language model — and because the defects were here, not there.
    public static func rank(_ candidates: [Candidate], limit: Int,
                            score: (String) -> Double) -> [String] {
        var scored: [(String, Double)] = []
        for candidate in candidates {
            let byName = score(readableName(candidate.name))
            // Only text-shaped files are worth comparing, and only their content words.
            let byContent = looksLikeText(candidate.sample) ? score(keywords(candidate.sample)) : 0
            // No thumb on the scale for the name. A tenth used to sit on the content, meant to
            // prefer a name that says something; every score lands between about 0.6 and 1.1, so a
            // tenth is a third of everything that separates a match from anything else, and it beat
            // the only signal that was working — "rechnung" scored an nginx.conf's *name* at 0.892,
            // above the real invoice's name, against the invoice's own words at 0.923.
            scored.append((candidate.name, max(byName, byContent)))
        }
        let ranked = scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        guard let best = ranked.first?.1 else { return [] }
        // Relative to the best match, never absolute: an absolute floor threw away the best match
        // too whenever the whole folder scored low. The best match is always returned; the cutoff
        // only decides its company.
        //
        // What this CANNOT do is tell that a folder has nothing to do with the query. The comment
        // that used to stand here said it could, and measuring says no threshold of any shape
        // would. Over five files, best score and the winner's lead over the rest:
        //
        //     "die Rechnung über das Dach"  best 0.889  lead 0.090   → the invoice   (a match)
        //     "Kochrezepte"                 best 0.988  lead 0.126   → an nginx.conf (nothing)
        //     "Bundesliga Spielplan"        best 1.134  lead 0.176   → an nginx.conf (nothing)
        //
        // A query about nothing in the folder scores HIGHER and stands out MORE than a real match,
        // so an absolute floor and a spread test fail the same way. Word overlap does not separate
        // them either: "Temperaturmessungen" shares no token with the readings file it correctly
        // finds. Ranking is the promise this can keep; deciding that nothing fits is not, and the
        // caller's sheet is titled "Closest matches" rather than "matches" for that reason.
        let cutoff = best * 0.7
        return ranked.enumerated()
            .filter { $0.offset == 0 || $0.element.1 >= cutoff }
            .prefix(max(1, limit))
            .map { $0.element.0 }
    }

    /// The sentence embedding to compare with, or nil when nothing fits.
    ///
    /// Nil matters: the caller then scores by word overlap instead, which works in any language.
    /// This used to fall back to the ENGLISH embedding for a language Apple has no model for,
    /// which is worse than having none — it returns finite distances, so the lexical fallback was
    /// never reached and a French or Russian query was ranked against English vectors. Measured on
    /// macOS 26.4: sentence embeddings existed for German, English and Italian and for none of the
    /// other sixteen languages this app ships in.
    ///
    /// `reader` is the language the app is running in, tried when the recognizer's answer has no
    /// embedding. Two words are not enough to place a language — "Webserver Konfiguration" is read
    /// as Danish, and the whole search then fell back to literal matching and returned nothing at
    /// all for a query whose answer was in the folder. The reader's language is a real prior; they
    /// typed the query. English was only ever a guess, which is why that fallback went.
    public static func embedding(for query: String, reader: String?) -> NLEmbedding? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(query)
        if let language = recognizer.dominantLanguage,
           let found = NLEmbedding.sentenceEmbedding(for: language) {
            return found
        }
        if let reader, let base = Locale(identifier: reader).language.languageCode?.identifier,
           let byReader = NLEmbedding.sentenceEmbedding(for: NLLanguage(rawValue: base)) {
            return byReader
        }
        return NLEmbedding.sentenceEmbedding(for: .english)
    }

    /// The embedding's own score for `text`, higher is better, or nil when it says nothing usable.
    public static func semantic(_ embedding: NLEmbedding?, phrase: String, text: String) -> Double? {
        guard let embedding, !text.isEmpty, !phrase.isEmpty else { return nil }
        let d = embedding.distance(between: phrase, and: text)   // smaller = closer
        guard d.isFinite, d > 0, d < 2 else { return nil }
        return 2 - d
    }
}
