// SPDX-License-Identifier: Apache-2.0
// PluginGitRewrite.swift — changing commit messages after the fact (phase 10).
//
// A message is part of the commit, so changing one makes a new commit — and every commit after it gets a
// new parent, so it is new as well. `git rebase -i` does that by replaying each commit onto the working
// tree, which is why a GUI can drive only one reword per run (one `GIT_EDITOR` file for all of them) and why
// a merge in the range or uncommitted changes get in the way. Here the commits are written directly: each
// one's object is read (`cat-file --batch`), its message replaced and its parents mapped to the rewritten
// ones, and the result written back (`hash-object -w`). The trees are the same objects as before, so
// nothing is checked out, nothing can conflict, and author, committer, dates, encoding and trailers stay
// byte for byte what they were. Only a signature cannot survive: it signed the old bytes.
//
// The branches and tags then move in one `update-ref --stdin` transaction, each only if it is still where
// it was read — and the old and new tips are kept under `refs/pc-backup/<stamp>/` so the rewrite can be
// undone. For a secret that is the wrong thing to keep, so `cleanUpRewrite` drops the backup, the
// reflog entries nothing reaches any more, and prunes — and says which of the old commits are still there.
//
// Compiled into the plugin bundle (Tools/build-git-plugin.sh) and into PCFoundationTests, beside
// PluginGit.swift. Git is reached only through the `GitCall` the caller passes, so the tests run the same
// code against a real repository.

import CryptoKit
import Foundation

extension PluginGit {

    // MARK: - Commit objects

    /// A commit object as git stores it. The headers are kept as Latin-1 text — every byte is one
    /// character and back — so a header in any encoding is written back exactly as it was read.
    public struct CommitObject: Equatable, Sendable {
        /// One entry per header, its continuation lines (a signature spans many) included.
        public var headers: [String]
        public var message: Data
        /// A commit object without the blank line before the message (git never writes one, but reading
        /// must not invent one).
        public var hasSeparator = true

        public init(headers: [String], message: Data, hasSeparator: Bool = true) {
            self.headers = headers; self.message = message; self.hasSeparator = hasSeparator
        }

        private func values(_ key: String) -> [String] {
            headers.compactMap { $0.hasPrefix(key + " ") ? String($0.dropFirst(key.count + 1)) : nil }
        }

        public var tree: String? { values("tree").first }
        public var parents: [String] { values("parent") }
        public var author: String? { values("author").first }
        public var committer: String? { values("committer").first }
        public var encoding: String? { values("encoding").first }
        public var isSigned: Bool { headers.contains { $0.hasPrefix("gpgsig ") || $0.hasPrefix("gpgsig-sha256 ") } }

        /// Whether the message is UTF-8 — the only kind this editor writes. A commit in another encoding
        /// keeps its message; changing it would mean writing that encoding back.
        public var isUTF8: Bool {
            guard let encoding = encoding?.lowercased() else { return true }
            return encoding == "utf-8" || encoding == "utf8"
        }

        public var messageText: String? { isUTF8 ? String(data: message, encoding: .utf8) : nil }

        public func serialized() -> Data {
            var out = Data(headers.joined(separator: "\n").data(using: .isoLatin1) ?? Data())
            out.append(0x0A)
            if hasSeparator { out.append(0x0A) }
            out.append(message)
            return out
        }
    }

    public static func parseCommitObject(_ data: Data) -> CommitObject? {
        let bytes = [UInt8](data)
        // The headers end at the first empty line.
        var end: Int?
        var index = 0
        while index + 1 < bytes.count {
            if bytes[index] == 0x0A, bytes[index + 1] == 0x0A { end = index; break }
            index += 1
        }
        let headerBytes: ArraySlice<UInt8>
        let message: Data
        var hasSeparator = true
        if let end {
            headerBytes = bytes[0..<end]
            message = Data(bytes[(end + 2)...])
        } else {
            guard bytes.last == 0x0A else { return nil }
            headerBytes = bytes[0..<(bytes.count - 1)]
            message = Data()
            hasSeparator = false
        }
        guard let text = String(bytes: headerBytes, encoding: .isoLatin1) else { return nil }
        var headers: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix(" "), !headers.isEmpty {
                headers[headers.count - 1] += "\n" + line
            } else {
                headers.append(line)
            }
        }
        guard headers.first?.hasPrefix("tree ") == true else { return nil }
        return CommitObject(headers: headers, message: message, hasSeparator: hasSeparator)
    }

    /// The commit with new parents and, when given, a new message — and without its signature, which
    /// signed the old bytes and would only fail to verify. Every other header stays where it was.
    public static func rewrittenCommit(_ commit: CommitObject, parents: [String], message: Data?) -> CommitObject {
        var headers: [String] = []
        var placed = false
        for header in commit.headers {
            if header.hasPrefix("gpgsig ") || header.hasPrefix("gpgsig-sha256 ") { continue }
            if header.hasPrefix("parent ") {
                if !placed { headers += parents.map { "parent " + $0 }; placed = true }
                continue
            }
            headers.append(header)
            if header.hasPrefix("tree "), !placed, !commit.headers.contains(where: { $0.hasPrefix("parent ") }) {
                headers += parents.map { "parent " + $0 }
                placed = true
            }
        }
        let body = message ?? commit.message
        // A message needs the blank line before it, or it would be read as headers.
        return CommitObject(headers: headers, message: body, hasSeparator: commit.hasSeparator || !body.isEmpty)
    }

    /// The object name git gives these bytes: SHA-1, or SHA-256 in a repository made with
    /// `--object-format=sha256`.
    public static func objectHash(type: String, content: Data, sha256: Bool = false) -> String {
        var data = Data("\(type) \(content.count)".utf8)
        data.append(0)
        data.append(content)
        let digest: [UInt8] = sha256 ? Array(SHA256.hash(data: data)) : Array(Insecure.SHA1.hash(data: data))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// An annotated tag pointed at the rewritten commit. Its signature goes, as a commit's does: in a tag
    /// it is the end of the message. nil when the bytes are not a tag of a commit.
    public static func rewrittenTag(_ data: Data, target: String) -> (data: Data, wasSigned: Bool)? {
        guard let text = String(data: data, encoding: .isoLatin1) else { return nil }
        let head: String, body: String
        if let blank = text.range(of: "\n\n") {
            head = String(text[..<blank.lowerBound]); body = String(text[blank.upperBound...])
        } else {
            head = text.hasSuffix("\n") ? String(text.dropLast()) : text; body = ""
        }
        var headers = head.components(separatedBy: "\n")
        guard headers.first?.hasPrefix("object ") == true, headers.contains("type commit") else { return nil }
        headers[0] = "object " + target
        var wasSigned = false
        // A SHA-256 repository may sign in a header as well; its continuation lines go with it.
        var kept: [String] = []
        var skipping = false
        for header in headers {
            if header.hasPrefix(" "), skipping { continue }
            skipping = header.hasPrefix("gpgsig")
            if skipping { wasSigned = true } else { kept.append(header) }
        }
        var message = body
        for marker in ["-----BEGIN PGP SIGNATURE-----", "-----BEGIN SSH SIGNATURE-----", "-----BEGIN SIGNED MESSAGE-----"] {
            if message.hasPrefix(marker) { message = ""; wasSigned = true; break }
            if let range = message.range(of: "\n" + marker) {
                message = String(message[..<range.upperBound].dropLast(marker.count))
                wasSigned = true
                break
            }
        }
        let out = kept.joined(separator: "\n") + "\n\n" + message
        return (out.data(using: .isoLatin1) ?? Data(), wasSigned)
    }

    /// `git cat-file --batch`'s answer: `<oid> <type> <size>\n<content>\n` per object, `<oid> missing\n`
    /// for one that is not there.
    public static func parseCatFileBatch(_ data: Data) -> [String: (type: String, content: Data)] {
        let bytes = [UInt8](data)
        var out: [String: (type: String, content: Data)] = [:]
        var index = 0
        while index < bytes.count {
            guard let newline = bytes[index...].firstIndex(of: 0x0A) else { break }
            let header = String(decoding: bytes[index..<newline], as: UTF8.self).split(separator: " ")
            index = newline + 1
            guard header.count == 3, let size = Int(header[2]), index + size <= bytes.count else { continue }
            out[String(header[0])] = (String(header[1]), Data(bytes[index..<(index + size)]))
            index += size + 1
        }
        return out
    }

    /// `git commit-tree`'s environment for a commit that is signed anew: the author and committer exactly
    /// as they were, dates and time zones included.
    public static func identityEnvironment(_ commit: CommitObject) -> [String: String]? {
        func split(_ value: String?) -> (name: String, email: String, date: String)? {
            guard let value, let open = value.firstIndex(of: "<"), let close = value.lastIndex(of: ">"),
                  open < close else { return nil }
            let name = value[..<open].trimmingCharacters(in: .whitespaces)
            let email = String(value[value.index(after: open)..<close])
            let date = value[value.index(after: close)...].trimmingCharacters(in: .whitespaces)
            guard !date.isEmpty else { return nil }
            // `@` makes the number a timestamp whatever its length; git's date parser guesses otherwise.
            return (name, email, "@" + date)
        }
        guard let author = split(commit.author.flatMap(latin1ToUTF8)),
              let committer = split(commit.committer.flatMap(latin1ToUTF8)) else { return nil }
        return ["GIT_AUTHOR_NAME": author.name, "GIT_AUTHOR_EMAIL": author.email, "GIT_AUTHOR_DATE": author.date,
                "GIT_COMMITTER_NAME": committer.name, "GIT_COMMITTER_EMAIL": committer.email,
                "GIT_COMMITTER_DATE": committer.date]
    }

    /// A header read as Latin-1, as the UTF-8 it really is (nil when it is not UTF-8).
    private static func latin1ToUTF8(_ text: String) -> String? {
        guard let bytes = text.data(using: .isoLatin1) else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    /// `commit-tree` for a signed copy of `commit` with these parents; the message goes on stdin, as is.
    public static func commitTreeArguments(_ commit: CommitObject, parents: [String]) -> [String]? {
        guard let tree = commit.tree else { return nil }
        return ["commit-tree", tree] + parents.flatMap { ["-p", $0] } + ["-S"]
    }

    /// Whether a commit can be signed anew through `commit-tree`: it writes only the four usual headers,
    /// so a commit with any other (an encoding, a merged tag, a tool's change id) would come out different.
    /// What it does write is compared afterwards as well (`rewriteMessages`).
    public static func canSignAnew(_ commit: CommitObject) -> Bool {
        commit.messageText != nil && commit.headers.allSatisfy {
            $0.hasPrefix("tree ") || $0.hasPrefix("parent ") || $0.hasPrefix("author ") || $0.hasPrefix("committer ")
        }
    }

    // MARK: - Rewriting a history

    /// What `rewriteCommits` produced.
    public struct CommitRewrite: Equatable, Sendable {
        /// Old name → new name, for every commit that changed.
        public var mapping: [String: String] = [:]
        /// The new objects in the order they were made, parents before children.
        public var written: [(hash: String, data: Data)] = []
        /// Commits that had a signature and do not any more.
        public var unsigned: [String] = []

        public static func == (a: Self, b: Self) -> Bool {
            a.mapping == b.mapping && a.unsigned == b.unsigned
                && a.written.map(\.hash) == b.written.map(\.hash) && a.written.map(\.data) == b.written.map(\.data)
        }
    }

    /// Rewrite the commits in `order` (parents before children, as `rev-list --reverse --topo-order`
    /// lists them): those in `messages` get their new message, and every commit with a rewritten parent
    /// gets the new parent. A commit neither applies to is left alone, so its name stays.
    ///
    /// `write` stores one new commit and returns its name — computed here (`objectHash`) to be written in
    /// one batch afterwards, or the name `commit-tree -S` gave a commit signed anew. It receives the
    /// rewritten object and the original. nil from `write` stops the rewrite.
    public static func rewriteCommits(order: [String], objects: [String: CommitObject], messages: [String: String],
                                      write: (CommitObject, CommitObject) -> String?) -> CommitRewrite? {
        var result = CommitRewrite()
        for hash in order {
            guard let commit = objects[hash] else { continue }
            let parents = commit.parents.map { result.mapping[$0] ?? $0 }
            let message = messages[hash].map { Data($0.utf8) }
            guard message != nil || parents != commit.parents else { continue }
            let rewritten = rewrittenCommit(commit, parents: parents, message: message)
            guard let name = write(rewritten, commit) else { return nil }
            result.mapping[hash] = name
            if commit.isSigned { result.unsigned.append(hash) }
        }
        return result
    }

    /// A message as typed into an editor, as git stores one: trailing white space and empty lines gone,
    /// one newline at the end. Empty stays empty — the caller refuses it.
    public static func normalizedMessage(_ text: String) -> String {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
            .map { line -> String in
                var line = line
                while let last = line.last, last == " " || last == "\t" { line.removeLast() }
                return line
            }
        while lines.last?.isEmpty == true { lines.removeLast() }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Find and replace

    /// What to look for in the messages, and what to put in its place.
    public struct MessageReplacement: Equatable, Sendable {
        public var find: String
        public var replacement: String
        public var regex = false
        public var caseSensitive = false
        public var wholeWord = false

        public init(find: String, replacement: String, regex: Bool = false, caseSensitive: Bool = false,
                    wholeWord: Bool = false) {
            self.find = find; self.replacement = replacement
            self.regex = regex; self.caseSensitive = caseSensitive; self.wholeWord = wholeWord
        }

        /// nil for an empty search, or a regular expression that does not compile.
        public var expression: NSRegularExpression? {
            guard !find.isEmpty else { return nil }
            var pattern = regex ? find : NSRegularExpression.escapedPattern(for: find)
            if wholeWord { pattern = #"(?<![\p{L}\p{N}_])(?:"# + pattern + #")(?![\p{L}\p{N}_])"# }
            return try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
        }

        /// A literal replacement is literal: `$1` in it is `$1`, not a group.
        public var template: String { regex ? replacement : NSRegularExpression.escapedTemplate(for: replacement) }

        public func matches(in text: String) -> [NSRange] {
            guard let expression else { return [] }
            return expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
                .map(\.range).filter { $0.length > 0 }
        }

        public func apply(to text: String) -> String {
            guard let expression, !matches(in: text).isEmpty else { return text }
            return expression.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text),
                                                       withTemplate: template)
        }
    }

    /// What a found secret is replaced with by default.
    public static let redactedText = "***REDACTED***"

    /// Secrets with a recognisable shape. The name is shown with each finding; the value — the whole
    /// match, or its first group where the pattern names a key before the value — is what gets replaced.
    public static let secretPatterns: [(name: String, pattern: String)] = [
        ("GitHub token", #"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b"#),
        ("GitHub token", #"\bgithub_pat_[A-Za-z0-9_]{22,}\b"#),
        ("GitLab token", #"\bgl(?:pat|dt|rt|ptt|cbt|soat)-[A-Za-z0-9_\-]{20,}"#),
        ("AWS access key", #"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"#),
        ("Slack token", #"\bxox[abposr]-[A-Za-z0-9-]{10,}"#),
        ("Google API key", #"\bAIza[0-9A-Za-z_\-]{35}"#),
        ("Stripe key", #"\b(?:sk|rk)_live_[0-9A-Za-z]{20,}"#),
        ("API key", #"\bsk-(?:ant-|proj-)?[A-Za-z0-9_\-]{24,}"#),
        ("Private key", #"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|\z)"#),
        ("Password in a URL", #"[A-Za-z][A-Za-z0-9+.\-]*://[^/\s:@]+:([^/\s@]+)@"#),
        ("Password or key", #"(?i)\b(?:password|passwd|pwd|secret|token|api[_\-]?key|access[_\-]?key)\b\s*[:=]\s*["']?([^\s"']{6,})"#),
    ]

    public struct SecretFinding: Equatable, Sendable {
        public let kind: String
        public let value: String
    }

    /// The secrets in one message, each value once.
    public static func secretFindings(in text: String) -> [SecretFinding] {
        var out: [SecretFinding] = []
        let whole = NSRange(text.startIndex..., in: text)
        for (kind, pattern) in secretPatterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in expression.matches(in: text, range: whole) {
                let range = match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound
                    ? match.range(at: 1) : match.range
                guard let swiftRange = Range(range, in: text) else { continue }
                let value = String(text[swiftRange])
                // A placeholder is not a secret, and an earlier, more specific pattern already has it.
                if value.contains(redactedText) || value.allSatisfy({ $0 == "*" || $0 == "x" || $0 == "X" }) { continue }
                if out.contains(where: { $0.value == value || $0.value.contains(value) }) { continue }
                out.append(SecretFinding(kind: kind, value: value))
            }
        }
        return out
    }

    /// The replacement that removes these values: each literally, longest first so one inside another
    /// does not leave a tail behind.
    public static func redaction(of values: [String]) -> MessageReplacement {
        let unique = Array(Set(values)).sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }
        return MessageReplacement(find: unique.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|"),
                                  replacement: redactedText, regex: true, caseSensitive: true)
    }

    /// A value as it may be shown: enough to recognise it, not enough to use it.
    public static func maskedSecret(_ value: String) -> String {
        let line = value.components(separatedBy: "\n").first ?? value
        guard line.count > 8 else { return String(repeating: "•", count: max(line.count, 4)) }
        return String(line.prefix(4)) + "…" + String(line.suffix(2)) + " (\(value.count))"
    }

    // MARK: - Reading the messages

    /// Which commits the messages window lists.
    public enum MessageScope: Equatable, Sendable {
        case commits([String])
        case currentBranch
        case allBranches
        case notPushed
    }

    /// One commit's message as the window lists it.
    public struct MessageCommit: Equatable, Sendable {
        public let hash: String
        public let shortHash: String
        public let author: String
        public let date: Date
        public let message: String
        public var subject: String { message.components(separatedBy: "\n").first ?? "" }
    }

    /// The listing: `-z` between commits, so a message may hold any separator but NUL — which git does
    /// not keep in a message either.
    /// How many commits the messages window reads at most.
    public static let messagesLimit = 50_000

    public static func messagesArguments(_ scope: MessageScope, limit: Int = messagesLimit) -> [String] {
        var out = ["--no-optional-locks", "log", "-z", "--topo-order", "--encoding=UTF-8", "--max-count=\(limit)",
                   "--format=%H\(unitSeparator)%h\(unitSeparator)%an\(unitSeparator)%at\(unitSeparator)%B"]
        switch scope {
        case .commits(let hashes): out += ["--no-walk=unsorted"] + hashes
        case .currentBranch: out += ["HEAD"]
        case .allBranches: out += ["--branches", "--tags"]
        case .notPushed: out += ["--branches", "--not", "--remotes"]
        }
        return out
    }

    public static func parseMessages(_ output: String) -> [MessageCommit] {
        output.components(separatedBy: "\0").compactMap { record in
            let fields = record.components(separatedBy: unitSeparator)
            guard fields.count >= 5, fields[0].count >= 40 else { return nil }
            return MessageCommit(hash: fields[0], shortHash: fields[1], author: fields[2],
                                 date: Date(timeIntervalSince1970: TimeInterval(fields[3]) ?? 0),
                                 message: fields[4...].joined(separator: unitSeparator))
        }
    }

    // MARK: - What a rewrite touches

    /// A branch, tag or remote branch holding one of the commits to change.
    public struct RewriteRef: Equatable, Sendable {
        public enum Kind: String, Sendable { case branch, tag, remote, stash }
        public let name: String
        public let kind: Kind
        /// The branch HEAD is on.
        public var isCurrent = false
        /// `refs/remotes/origin/main` for a branch that has one.
        public var upstream: String?
        public var remoteName: String?
        public var remoteRef: String?

        public var shortName: String {
            for prefix in ["refs/heads/", "refs/tags/", "refs/remotes/"] where name.hasPrefix(prefix) {
                return String(name.dropFirst(prefix.count))
            }
            return name
        }
    }

    public static func containingRefsArguments(_ commits: [String]) -> [String] {
        ["for-each-ref",
         "--format=%(refname)\(unitSeparator)%(upstream)\(unitSeparator)%(upstream:remotename)\(unitSeparator)%(upstream:remoteref)"]
            + commits.flatMap { ["--contains", $0] }
            + ["refs/heads", "refs/tags", "refs/remotes", "refs/stash"]
    }

    public static func parseContainingRefs(_ output: String, currentBranch: String?) -> [RewriteRef] {
        output.components(separatedBy: "\n").compactMap { line in
            let fields = line.components(separatedBy: unitSeparator)
            guard let name = fields.first, !name.isEmpty else { return nil }
            let kind: RewriteRef.Kind
            if name.hasPrefix("refs/heads/") { kind = .branch }
            else if name.hasPrefix("refs/tags/") { kind = .tag }
            else if name == "refs/stash" { kind = .stash }
            else if name.hasPrefix("refs/remotes/"), !name.hasSuffix("/HEAD") { kind = .remote }
            else { return nil }
            func field(_ index: Int) -> String? { fields.count > index && !fields[index].isEmpty ? fields[index] : nil }
            return RewriteRef(name: name, kind: kind, isCurrent: name == currentBranch, upstream: field(1),
                              remoteName: field(2), remoteRef: field(3))
        }
    }

    /// The branches that were pushed with old commits on them: their upstream holds one of the commits.
    public static func pushedBranches(_ refs: [RewriteRef]) -> [RewriteRef] {
        let remotes = Set(refs.filter { $0.kind == .remote }.map(\.name))
        return refs.filter { $0.kind == .branch && $0.upstream.map(remotes.contains) == true }
    }

    /// The push that replaces a rewritten branch at its remote — with a lease, as every push after a
    /// rewrite in this plugin (`forcePushArguments`).
    public static func forcePushArguments(for ref: RewriteRef) -> [String]? {
        guard let remote = ref.remoteName, let remoteRef = ref.remoteRef else { return nil }
        return forcePushArguments + [remote, "\(ref.name):\(remoteRef)"]
    }

    // MARK: - Running it

    /// How the rewrite reaches git: arguments, stdin, extra environment → stdout and success.
    public typealias GitCall = (_ arguments: [String], _ input: Data?, _ environment: [String: String]) -> (out: Data, ok: Bool)

    public enum RewriteError: Error, Equatable, Sendable {
        /// None of the commits is on a branch or tag that was chosen.
        case notReachable
        /// These commits keep their message in an encoding other than UTF-8.
        case notUTF8([String])
        /// A ref moved while the rewrite ran; nothing was changed.
        case refMoved(String)
        /// git refused; its words.
        case git(String)
        /// The history could not be listed.
        case historyUnreadable
        /// A new commit could not be written (git's words, when it said any).
        case writeFailed(String)
        /// git named a written object differently from the name computed here; no ref was moved.
        case nameMismatch
    }

    public struct RewriteReport: Equatable, Sendable {
        public var stamp: String
        /// Old commit → new commit.
        public var mapping: [String: String]
        /// The refs that moved, with where they were and are.
        public var moved: [(ref: String, old: String, new: String)]
        public var unsigned: Int
        /// Commits signed anew could not be, for these (`canSignAnew`); they are unsigned.
        public var notSigned: Int
        /// Edited commits that none of the chosen refs reach — left as they are.
        public var unreached: [String]

        public static func == (a: Self, b: Self) -> Bool {
            a.stamp == b.stamp && a.mapping == b.mapping && a.unsigned == b.unsigned && a.notSigned == b.notSigned
                && a.unreached == b.unreached && a.moved.map(\.ref) == b.moved.map(\.ref)
                && a.moved.map(\.new) == b.moved.map(\.new)
        }
    }

    public static let backupNamespace = "refs/pc-backup/"

    /// The name of one rewrite's backup: sorts by time, and says what it was for.
    public static func backupStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "messages-" + formatter.string(from: date)
    }

    /// The date in a stamp, for saying when the rewrite was.
    public static func backupDate(_ stamp: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.date(from: String(stamp.dropFirst("messages-".count)))
    }

    /// The backups present, newest first.
    public static func backupStamps(_ forEachRefOutput: String) -> [String] {
        let stamps = forEachRefOutput.components(separatedBy: "\n").compactMap { line -> String? in
            guard line.hasPrefix(backupNamespace) else { return nil }
            return line.dropFirst(backupNamespace.count).components(separatedBy: "/").first
        }
        return Array(Set(stamps)).sorted(by: >)
    }

    private static func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    /// Change the messages: `messages` maps a commit to its new message (as stored — `normalizedMessage`
    /// for typed text); `refs` are the branches and tags (full names) to move onto the rewritten history.
    /// `sign` signs the rewritten commits anew through `commit-tree -S` (Settings ▸ Git ▸ Sign commits).
    public static func rewriteMessages(_ messages: [String: String], refs: [String], sign: Bool, stamp: String,
                                       git: GitCall) -> Result<RewriteReport, RewriteError> {
        func run(_ arguments: [String], _ input: Data? = nil, _ environment: [String: String] = [:]) -> (out: Data, ok: Bool) {
            // Replacement refs (`git replace`) would hand back another commit's content, and that would be
            // baked into the new history; the objects as stored are what is rewritten.
            git(arguments, input, environment.merging(["GIT_NO_REPLACE_OBJECTS": "1"]) { a, _ in a })
        }
        guard !messages.isEmpty, !refs.isEmpty else { return .failure(.notReachable) }
        let sha256 = text(run(["rev-parse", "--show-object-format"]).out).trimmingCharacters(in: .whitespacesAndNewlines) == "sha256"

        // Where each ref is now — the transaction later moves it only from there.
        let listed = run(["for-each-ref", "--format=%(refname)\(unitSeparator)%(objectname)\(unitSeparator)%(objecttype)"
                          + "\(unitSeparator)%(*objectname)\(unitSeparator)%(*objecttype)"] + refs)
        guard listed.ok else { return .failure(.git(text(listed.out))) }
        var current: [(ref: String, object: String, type: String, peeled: String?)] = []
        for line in text(listed.out).components(separatedBy: "\n") {
            let f = line.components(separatedBy: unitSeparator)
            guard f.count >= 5, refs.contains(f[0]) else { continue }
            current.append((f[0], f[1], f[2], f[2] == "tag" && f[4] == "commit" ? f[3] : nil))
        }
        let tips = Array(Set(current.compactMap { $0.type == "commit" ? $0.object : $0.peeled }))
        guard !tips.isEmpty else { return .failure(.notReachable) }

        // The edited commits first: their encoding, and their parents, which bound the walk.
        let edited = Array(messages.keys)
        let first = parseCatFileBatch(run(["cat-file", "--batch"], Data((edited.joined(separator: "\n") + "\n").utf8)).out)
        let notUTF8 = edited.filter { first[$0].flatMap { parseCommitObject($0.content) }.map { $0.messageText == nil } ?? false }
        guard notUTF8.isEmpty else { return .failure(.notUTF8(notUTF8.sorted())) }
        let boundary = Set(edited.flatMap { first[$0].flatMap { parseCommitObject($0.content) }?.parents ?? [] })

        // Every commit that may need rewriting, parents first. Bounded by the edited commits' parents —
        // unless one edited commit is an ancestor of another's parent, which the bound would hide; then
        // the whole history of the tips.
        func walk(_ bound: Set<String>) -> [(hash: String, parents: [String])]? {
            let result = run(["rev-list", "--topo-order", "--reverse", "--parents"] + tips
                             + (bound.isEmpty ? [] : ["--not"] + bound.sorted()))
            guard result.ok else { return nil }
            return text(result.out).components(separatedBy: "\n").compactMap { line in
                let parts = line.split(separator: " ").map(String.init)
                return parts.first.map { ($0, Array(parts.dropFirst())) }
            }
        }
        guard var order = walk(boundary) else { return .failure(.historyUnreadable) }
        if !boundary.isEmpty, !Set(edited).isSubset(of: Set(order.map(\.hash))) {
            guard let full = walk([]) else { return .failure(.historyUnreadable) }
            order = full
        }
        let listedHashes = Set(order.map(\.hash))
        let unreached = edited.filter { !listedHashes.contains($0) }.sorted()
        guard unreached.count < edited.count else { return .failure(.notReachable) }

        let batch = run(["cat-file", "--batch"], Data((order.map(\.hash).joined(separator: "\n") + "\n").utf8))
        guard batch.ok else { return .failure(.git(text(batch.out))) }
        let objects = parseCatFileBatch(batch.out).compactMapValues { $0.type == "commit" ? parseCommitObject($0.content) : nil }

        // Written: computed here and stored in one go — or, to be signed, one `commit-tree -S` each.
        var pending: [(hash: String, data: Data)] = []
        var notSigned = 0
        var failure: String?
        let rewrite = rewriteCommits(order: order.map(\.hash), objects: objects, messages: messages) { rewritten, _ in
            let data = rewritten.serialized()
            let computed = objectHash(type: "commit", content: data, sha256: sha256)
            guard sign else { pending.append((computed, data)); return computed }
            // Signing: each commit is written before its children ask for it as a parent.
            if canSignAnew(rewritten), let arguments = commitTreeArguments(rewritten, parents: rewritten.parents),
               let environment = identityEnvironment(rewritten) {
                let result = run(arguments, rewritten.message, environment)
                let name = text(result.out).trimmingCharacters(in: .whitespacesAndNewlines)
                guard result.ok, !name.isEmpty else { failure = text(result.out); return nil }
                // `commit-tree` writes its own headers: only a commit that, signature aside, is exactly
                // the one meant is kept. Anything else (a name git tidied, an encoding it added) is
                // written unsigned instead.
                let written = parseCatFileBatch(run(["cat-file", "--batch"], Data((name + "\n").utf8)).out)[name]
                if let written, let object = parseCommitObject(written.content),
                   rewrittenCommit(object, parents: object.parents, message: nil).serialized() == data {
                    return name
                }
            }
            notSigned += 1
            if let error = store([(computed, data)], type: "commit", run: run) {
                failure = "\(error)"
                return nil
            }
            return computed
        }
        guard let rewrite else { return .failure(.writeFailed(failure ?? "")) }
        if let error = store(pending, type: "commit", run: run) { return .failure(error) }

        // Tags of a rewritten commit: a lightweight one simply moves; an annotated one is a new tag object.
        var updates: [(ref: String, old: String, new: String)] = []
        var tagObjects: [(hash: String, data: Data)] = []
        var unsigned = rewrite.unsigned.count
        let tagBatch = parseCatFileBatch(run(["cat-file", "--batch"],
                                             Data((current.filter { $0.type == "tag" }.map(\.object).joined(separator: "\n") + "\n").utf8)).out)
        for entry in current {
            if entry.type == "commit" {
                if let new = rewrite.mapping[entry.object] { updates.append((entry.ref, entry.object, new)) }
            } else if let peeled = entry.peeled, let new = rewrite.mapping[peeled],
                      let tag = tagBatch[entry.object], let moved = rewrittenTag(tag.content, target: new) {
                let name = objectHash(type: "tag", content: moved.data, sha256: sha256)
                tagObjects.append((name, moved.data))
                if moved.wasSigned { unsigned += 1 }
                updates.append((entry.ref, entry.object, name))
            }
        }
        if let error = store(tagObjects, type: "tag", run: run) { return .failure(error) }
        guard !updates.isEmpty else { return .failure(.notReachable) }

        var transaction = ""
        for update in updates {
            let backup = backupNamespace + stamp + "/"
            let short = update.ref.dropFirst("refs/".count)
            transaction += "update \(update.ref) \(update.new) \(update.old)\n"
            transaction += "create \(backup)old/\(short) \(update.old)\n"
            transaction += "create \(backup)new/\(short) \(update.new)\n"
        }
        let moved = run(["update-ref", "-m", "PeachCommander: rewrite commit messages", "--stdin"], Data(transaction.utf8),
                        englishMessagesEnvironment)
        guard moved.ok else {
            let message = text(moved.out)
            // "cannot lock ref 'refs/heads/main': is at … but expected …"
            if message.contains("but expected"), let ref = updates.first(where: { message.contains("'\($0.ref)'") })?.ref {
                return .failure(.refMoved(ref))
            }
            return .failure(.git(message))
        }
        return .success(RewriteReport(stamp: stamp, mapping: rewrite.mapping, moved: updates, unsigned: unsigned,
                                      notSigned: notSigned, unreached: unreached))
    }

    /// Write objects whose names were computed here, and check git agrees on each name.
    private static func store(_ objects: [(hash: String, data: Data)], type: String,
                              run: ([String], Data?, [String: String]) -> (out: Data, ok: Bool)) -> RewriteError? {
        guard !objects.isEmpty else { return nil }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pc-git-rewrite-\(UUID().uuidString)")
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) } catch {
            return .writeFailed(error.localizedDescription)
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        var paths: [String] = []
        for (index, object) in objects.enumerated() {
            let url = directory.appendingPathComponent("\(index)")
            do { try object.data.write(to: url) } catch { return .writeFailed(error.localizedDescription) }
            paths.append(url.path)
        }
        let result = run(["hash-object", "-t", type, "-w", "--stdin-paths"], Data((paths.joined(separator: "\n") + "\n").utf8), [:])
        let names = text(result.out).split(separator: "\n").map(String.init)
        guard result.ok else { return .writeFailed(text(result.out)) }
        guard names == objects.map(\.hash) else { return .nameMismatch }
        return nil
    }

    /// The refs a backup holds: ref → (old, new).
    public static func backupRefsArguments(_ stamp: String) -> [String] {
        ["for-each-ref", "--format=%(refname) %(objectname)", backupNamespace + stamp + "/"]
    }

    public static func parseBackup(_ output: String, stamp: String) -> [String: (old: String?, new: String?)] {
        var out: [String: (old: String?, new: String?)] = [:]
        let prefix = backupNamespace + stamp + "/"
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ").map(String.init)
            guard parts.count == 2, parts[0].hasPrefix(prefix) else { continue }
            let rest = parts[0].dropFirst(prefix.count)
            if rest.hasPrefix("old/") { out["refs/" + rest.dropFirst(4), default: (nil, nil)].old = parts[1] }
            if rest.hasPrefix("new/") { out["refs/" + rest.dropFirst(4), default: (nil, nil)].new = parts[1] }
        }
        return out
    }

    public enum UndoResult: Equatable, Sendable {
        case undone([String])
        /// These moved since the rewrite: undoing would throw their new commits away, so nothing was done.
        case moved([String])
        case failed(String)
        case noBackup
    }

    /// Put the refs back where they were before the rewrite, each only if it is still where the rewrite
    /// left it, and drop the backup.
    public static func undoRewrite(stamp: String, git: GitCall) -> UndoResult {
        let listed = git(backupRefsArguments(stamp), nil, [:])
        guard listed.ok else { return .failed(text(listed.out)) }
        let backup = parseBackup(text(listed.out), stamp: stamp)
        guard !backup.isEmpty else { return .noBackup }
        let names = backup.keys.sorted()
        let now = text(git(["for-each-ref", "--format=%(refname) %(objectname)"] + names, nil, [:]).out)
        var at: [String: String] = [:]
        for line in now.components(separatedBy: "\n") {
            let parts = line.split(separator: " ").map(String.init)
            if parts.count == 2 { at[parts[0]] = parts[1] }
        }
        let moved = names.filter { at[$0] != backup[$0]?.new }
        guard moved.isEmpty else { return .moved(moved) }
        var transaction = ""
        for name in names {
            guard let old = backup[name]?.old, let new = backup[name]?.new else { continue }
            transaction += "update \(name) \(old) \(new)\n"
        }
        transaction += deleteBackupTransaction(stamp: stamp, backup: backup)
        let result = git(["update-ref", "-m", "PeachCommander: undo rewrite of commit messages", "--stdin"],
                         Data(transaction.utf8), [:])
        return result.ok ? .undone(names) : .failed(text(result.out))
    }

    private static func deleteBackupTransaction(stamp: String, backup: [String: (old: String?, new: String?)]) -> String {
        var out = ""
        for (name, values) in backup.sorted(by: { $0.key < $1.key }) {
            let short = name.dropFirst("refs/".count)
            if values.old != nil { out += "delete \(backupNamespace)\(stamp)/old/\(short)\n" }
            if values.new != nil { out += "delete \(backupNamespace)\(stamp)/new/\(short)\n" }
        }
        return out
    }

    /// `refs/heads/main`, … for each reflog file under `logs/refs`, the stash's left out.
    public static func reflogRefs(logsDirectory: String) -> [String] {
        let base = URL(fileURLWithPath: logsDirectory)
        guard let walker = FileManager.default.enumerator(at: base.appendingPathComponent("refs"),
                                                         includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var out: [String] = []
        for case let url as URL in walker where (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
            let name = String(url.standardizedFileURL.path.dropFirst(base.standardizedFileURL.path.count + 1))
            if name != "refs/stash" { out.append(name) }
        }
        return out.sorted()
    }

    public struct CleanUpReport: Equatable, Sendable {
        /// Old commits gone from the repository.
        public var removed: [String]
        /// Old commits still there, with the refs that still reach them (empty: a stash, a worktree or
        /// another clone's alternates may).
        public var remaining: [String: [String]]
    }

    /// Remove the old commits from this repository: the backup, the reflog entries the current refs do
    /// not reach (but never the stash's, which *are* the stash list), then `gc --prune=now`. `old` are the
    /// commits to check for afterwards — the ones whose message held the secret.
    public static func cleanUpRewrite(stamp: String?, old: [String], git: GitCall) -> Result<CleanUpReport, RewriteError> {
        // The refs that have a reflog — naming one without makes `reflog expire` fail — read from the
        // repository's logs directory, because `--all` would take the stash's along; and only refs that
        // still exist, since a log file can outlive its ref.
        let common = text(git(["rev-parse", "--path-format=absolute", "--git-common-dir"], nil, [:]).out)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = Set(text(git(["for-each-ref", "--format=%(refname)"], nil, [:]).out).components(separatedBy: "\n"))
        var refs = reflogRefs(logsDirectory: (common as NSString).appendingPathComponent("logs")).filter(existing.contains)
        if git(["reflog", "exists", "HEAD"], nil, [:]).ok { refs.insert("HEAD", at: 0) }
        if !refs.isEmpty {
            let expire = git(["reflog", "expire", "--expire-unreachable=now"] + refs, nil, [:])
            guard expire.ok else { return .failure(.git(text(expire.out))) }
        }
        // The backup last: until here a failure leaves the rewrite undoable.
        if let stamp {
            let listed = git(backupRefsArguments(stamp), nil, [:])
            let backup = parseBackup(text(listed.out), stamp: stamp)
            if !backup.isEmpty {
                let result = git(["update-ref", "--stdin"], Data(deleteBackupTransaction(stamp: stamp, backup: backup).utf8), [:])
                guard result.ok else { return .failure(.git(text(result.out))) }
            }
        }
        let gc = git(["gc", "--prune=now", "--quiet"], nil, [:])
        guard gc.ok else { return .failure(.git(text(gc.out))) }
        var report = CleanUpReport(removed: [], remaining: [:])
        for hash in old {
            if git(["cat-file", "-e", hash + "^{commit}"], nil, [:]).ok {
                let holders = text(git(["for-each-ref", "--format=%(refname)", "--contains", hash], nil, [:]).out)
                    .components(separatedBy: "\n").filter { !$0.isEmpty }
                report.remaining[hash] = holders
            } else {
                report.removed.append(hash)
            }
        }
        return .success(report)
    }
}
