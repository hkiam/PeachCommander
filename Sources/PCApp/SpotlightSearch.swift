// SPDX-License-Identifier: Apache-2.0
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

    /// Where a query looks. Spotlight's own scopes, named so a tool argument can carry one (F-446).
    enum Scope: Equatable {
        case wholeComputer
        case userHome
        case folder(String)

        /// Tolerant parsing, because this arrives from a language model.
        init(_ text: String, activeFolder: String) {
            switch text.lowercased().trimmingCharacters(in: .whitespaces) {
            case "", "home", "user", "userhome":            self = .userHome
            case "disk", "computer", "all", "everywhere", "wholecomputer": self = .wholeComputer
            case "here", ".", "folder", "panel":            self = .folder(activeFolder)
            case let other where other.hasPrefix("/"):      self = .folder(text)
            default:                                        self = .userHome
            }
        }

        var searchScopes: [Any] {
            switch self {
            case .wholeComputer: return [NSMetadataQueryLocalComputerScope]
            case .userHome:      return [NSMetadataQueryUserHomeScope]
            case .folder(let p): return [URL(fileURLWithPath: p)]
            }
        }

        var described: String {
            switch self {
            case .wholeComputer: return "this computer"
            case .userHome:      return "your home folder"
            case .folder(let p): return p
            }
        }
    }

    /// One indexed match, with the attributes worth having without a second stat call.
    struct Hit: Sendable, Equatable {
        let path: String
        let isDirectory: Bool
        let size: Int64
        let modified: Date?
    }

    /// Run a structured query and return the matches, best-effort ordered by modification date.
    ///
    /// The index is macOS's own and always current, so there is no warm-up to wait for and nothing of
    /// ours to maintain — which is the whole reason this exists rather than an index of our own.
    /// What it cannot see, it cannot see: Spotlight honours the privacy exclusions and the locations
    /// macOS keeps to itself, so an empty result is not proof that a file is absent (F-445 is the same
    /// wall from the other side).
    func find(_ query: SpotlightQuery, scope: Scope, limit: Int, now: Date = Date()) async -> [Hit] {
        guard let predicate = SpotlightPredicate.build(query, now: now) else { return [] }
        return await withCheckedContinuation { continuation in
            let q = NSMetadataQuery()
            q.predicate = predicate
            q.searchScopes = scope.searchScopes
            // Newest first: for "that contract from last month" the recent end is the answer, and a
            // capped list has to cut from the right end.
            q.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey,
                                                 ascending: false)]

            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main
            ) { [weak self] _ in
                q.stop()
                if let token { NotificationCenter.default.removeObserver(token) }
                var hits: [Hit] = []
                for i in 0..<min(q.resultCount, max(0, limit)) {
                    guard let item = q.result(at: i) as? NSMetadataItem,
                          let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
                    else { continue }
                    let type = item.value(forAttribute: NSMetadataItemContentTypeTreeKey) as? [String]
                    hits.append(Hit(path: path,
                                    isDirectory: type?.contains("public.folder") ?? false,
                                    size: (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?
                                        .int64Value ?? 0,
                                    modified: item.value(forAttribute: NSMetadataItemFSContentChangeDateKey)
                                        as? Date))
                }
                self?.query = nil
                continuation.resume(returning: hits)
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
