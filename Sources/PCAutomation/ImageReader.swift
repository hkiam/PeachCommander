// SPDX-License-Identifier: Apache-2.0
// ImageReader.swift — what Vision can make of a picture, on the device.
//
// Apple Intelligence is text-only: `Transcript.Segment` has a case for text and one for structure
// and none for an image. So a picture reaches the assistant by being turned into words first, and
// this is where that happens. It is not a workaround — OCR and classification are what actually
// read a scan, and the language model's job afterwards is to name and file what they found.
//
// Here rather than in the app so that both the host bridge and the tests use ONE implementation.
// The last time two pieces of code computed the same thing separately — the summary fingerprint —
// they disagreed and a panel column was empty for every file, forever.

import Foundation
#if canImport(Vision)
import Vision
#endif

public enum ImageReader {

    /// Read `path` as a picture: the text on it, and what it appears to show.
    ///
    /// Throws rather than returning an empty description when it cannot run at all, because
    /// "nothing in this picture" and "this could not be looked at" are different answers and only
    /// one of them is about the picture.
    public static func describe(path: String) async throws -> ImageDescription {
        guard FileManager.default.fileExists(atPath: path) else {
            throw AutomationError.notImplemented("describe_image: \(path) is not there")
        }
        #if canImport(Vision)
        // Vision's Swift API landed in macOS 15. Below it this says so rather than returning an
        // empty description, which would read as "there is nothing in this picture".
        guard #available(macOS 15, *) else {
            throw AutomationError.notImplemented("describe_image needs macOS 15 or newer")
        }
        let url = URL(fileURLWithPath: path)

        var text = ""
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // Whatever the system can read, rather than a list of languages we would have to keep
        // current — and this app ships in nineteen of them.
        request.automaticallyDetectsLanguage = true
        if let lines = try? await request.perform(on: url) {
            text = lines.compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var labels: [String] = []
        if let found = try? await ClassifyImageRequest().perform(on: url) {
            // A confidence floor: the tail of this list is every concept the classifier knows, each
            // with a number near zero, and passing that on as "what it shows" would bury the two
            // labels that mean something under a hundred that do not.
            labels = found.filter { $0.confidence > 0.2 }
                .sorted { $0.confidence > $1.confidence }
                .prefix(6).map(\.identifier)
        }
        // Bounded like a read is: a page of dense text can OCR into more than a small model's
        // whole context window.
        return ImageDescription(text: String(text.prefix(4000)), labels: labels)
        #else
        throw AutomationError.notImplemented("describe_image needs Vision")
        #endif
    }
}
