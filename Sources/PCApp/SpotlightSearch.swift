// SpotlightSearch.swift - Optional Spotlight-backed file search (backlog item 25).
//
// An alternative to the recursive VFS walk for local, indexed folders: builds an
// NSMetadataQuery from the name mask (+ optional content text) and returns the
// matching file paths. Only valid on indexed local volumes, so the caller gates
// it to LocalFS, non-regex, whole-directory searches. The predicate builder is
// static + pure so it can be unit-tested without a live index.

import Foundation
import PCFoundation

@MainActor
final class SpotlightSearch {
    private var query: NSMetadataQuery?

    /// Run a Spotlight query scoped to `directory`, returning matching file paths.
    /// Completes when the initial gathering pass finishes.
    func search(nameMask: String, contentText: String?, in directory: String) async -> [String] {
        await withCheckedContinuation { continuation in
            let q = NSMetadataQuery()
            q.predicate = SpotlightPredicate.build(nameMask: nameMask, contentText: contentText)
            q.searchScopes = [URL(fileURLWithPath: directory)]

            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main
            ) { [weak self] _ in
                q.stop()
                if let token { NotificationCenter.default.removeObserver(token) }
                let paths: [String] = (0..<q.resultCount).compactMap {
                    (q.result(at: $0) as? NSMetadataItem)?
                        .value(forAttribute: NSMetadataItemPathKey) as? String
                }
                self?.query = nil
                continuation.resume(returning: paths)
            }
            self.query = q
            q.start()
        }
    }

    func cancel() {
        query?.stop()
        query = nil
    }
}
