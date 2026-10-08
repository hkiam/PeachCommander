// SPDX-License-Identifier: Apache-2.0
// PluginGitHosting.swift — pull requests, issues and CI status at GitHub and GitLab (phase 9).
//
// What the Git plugin's Pull Requests window and the panel's CI badge ask the hosting service, and how
// they read the answers. Pure where it can be: the requests are built and the JSON is read by functions
// the tests call directly, and the one class that talks to the network takes its URLSession from the
// caller, so a test hands it a stubbed one. Compiled into the plugin bundle (Tools/build-git-plugin.sh)
// and into PCFoundationTests, beside PluginGit.swift.
//
// The token is the reader's personal access token, kept in the Keychain through the host's `crypt`
// service under `tokenStore(host:)` — never in a file, never in git.ini. Requests go only to the host
// the remote names (or its API host), so a token for one server is never sent to another.

import Foundation

extension PluginGit {

    /// The two services the window speaks to. Bitbucket and Azure keep their web links (phase 5c) but
    /// have no pull-request support here.
    public enum HostKind: String, Sendable, CaseIterable { case github, gitlab }

    /// A repository at a hosting service, as the API addresses it.
    public struct HostingProject: Sendable, Equatable {
        public let kind: HostKind
        /// The web host, lower-cased: `github.com`, `gitlab.example.com`.
        public let host: String
        /// `owner/repo` at GitHub; `group/subgroup/project` at GitLab.
        public let path: String
        /// The API's root, without a trailing slash.
        public let apiBase: String
        /// The remote this was read from — what a pull request's branch is fetched from.
        public let remote: String

        public var webBase: String { "https://\(host)/\(path)" }
    }

    /// The project a remote URL points at, or nil when its host is neither GitHub nor GitLab as far as
    /// can be told. github.com and gitlab.com are known by name, and a host whose name starts with
    /// `gitlab.` is taken for a GitLab; any other self-hosted server needs an entry in `kinds`
    /// (Settings ▸ Git), because a GitHub Enterprise cannot be told from anything else by its name.
    public static func hostingProject(remoteName: String, url: String,
                                      kinds: [String: HostKind] = [:]) -> HostingProject? {
        guard let (rawHost, path) = remoteHostAndPath(url), path.contains("/") else { return nil }
        let host = rawHost.lowercased()
        let kind: HostKind
        if let configured = kinds[host] {
            kind = configured
        } else if host == "github.com" || host == "www.github.com" {
            kind = .github
        } else if host == "gitlab.com" || host.hasPrefix("gitlab.") {
            kind = .gitlab
        } else {
            return nil
        }
        var webHost = host == "www.github.com" ? "github.com" : host
        // An HTTPS remote on a port of its own (`https://gitlab.corp:8443/…`) serves its web pages and its
        // API there too; an SSH port says nothing about HTTPS and is left out.
        if let parsed = URL(string: url), ["https", "http"].contains(parsed.scheme?.lowercased() ?? ""),
           let port = parsed.port, port != 443, port != 80 {
            webHost += ":\(port)"
        }
        let api: String
        switch kind {
        case .github: api = webHost == "github.com" ? "https://api.github.com" : "https://\(webHost)/api/v3"
        case .gitlab: api = "https://\(webHost)/api/v4"
        }
        return HostingProject(kind: kind, host: webHost, path: path, apiBase: api, remote: remoteName)
    }

    /// The first remote of `remotes` that is a hosting project: `origin` when it is one, else the first.
    public static func hostingProject(remotes: [Remote], kinds: [String: HostKind] = [:]) -> HostingProject? {
        let ordered = remotes.filter { $0.name == "origin" } + remotes.filter { $0.name != "origin" }
        return ordered.lazy.compactMap { hostingProject(remoteName: $0.name, url: $0.fetchURL, kinds: kinds) }.first
    }

    /// The settings field for self-hosted servers: `git.example.com=gitlab, ghe.corp=github`. Entries
    /// that do not read as host=kind are left out.
    public static func parseHostKinds(_ text: String) -> [String: HostKind] {
        var kinds: [String: HostKind] = [:]
        for entry in text.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" }) {
            let parts = entry.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty, !parts[0].contains(" "),
                  let kind = HostKind(rawValue: parts[1].lowercased()) else { continue }
            kinds[parts[0].lowercased()] = kind
        }
        return kinds
    }

    public static func hostKindsText(_ kinds: [String: HostKind]) -> String {
        kinds.keys.sorted().map { "\($0)=\(kinds[$0]!.rawValue)" }.joined(separator: ", ")
    }

    /// Where a host's token lives in the Keychain (the `crypt` service's store name).
    public static func tokenStore(host: String) -> String { "git-token:" + host.lowercased() }

    /// Where a person creates the token, with the scopes the window needs already ticked where the
    /// service lets a link do that.
    public static func tokenCreationURL(_ project: HostingProject) -> String {
        switch project.kind {
        case .github:
            return "https://\(project.host)/settings/tokens/new?scopes=repo&description=Peach%20Commander"
        case .gitlab:
            return "https://\(project.host)/-/user_settings/personal_access_tokens?name=Peach%20Commander&scopes=api"
        }
    }

    // MARK: Requests

    /// One API call, as data: what the tests compare and what the client sends.
    public struct APIRequest: Sendable, Equatable {
        public let method: String
        public let url: String
        public let body: Data?
    }

    /// The headers for a call: GitHub takes a bearer token and wants its media type and API version
    /// named; GitLab takes its own header.
    public static func apiHeaders(_ kind: HostKind, token: String) -> [String: String] {
        switch kind {
        case .github:
            return ["Authorization": "Bearer \(token)", "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "PeachCommander"]
        case .gitlab:
            return ["PRIVATE-TOKEN": token, "Accept": "application/json", "User-Agent": "PeachCommander"]
        }
    }

    /// GitLab addresses a project by its path, URL-encoded as one segment (`group%2Fproject`).
    private static func gitlabID(_ project: HostingProject) -> String {
        project.path.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~")))
            ?? project.path
    }

    private static func query(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? text
    }

    public static func pullRequestsRequest(_ project: HostingProject) -> APIRequest {
        switch project.kind {
        case .github:
            return APIRequest(method: "GET", url: "\(project.apiBase)/repos/\(project.path)/pulls?state=open&per_page=50", body: nil)
        case .gitlab:
            return APIRequest(method: "GET",
                              url: "\(project.apiBase)/projects/\(gitlabID(project))/merge_requests?state=opened&per_page=50",
                              body: nil)
        }
    }

    public static func issuesRequest(_ project: HostingProject) -> APIRequest {
        switch project.kind {
        case .github:
            return APIRequest(method: "GET", url: "\(project.apiBase)/repos/\(project.path)/issues?state=open&per_page=50", body: nil)
        case .gitlab:
            return APIRequest(method: "GET",
                              url: "\(project.apiBase)/projects/\(gitlabID(project))/issues?state=opened&per_page=50", body: nil)
        }
    }

    /// The repository itself — for its default branch, the base a new pull request proposes.
    public static func projectRequest(_ project: HostingProject) -> APIRequest {
        switch project.kind {
        case .github: return APIRequest(method: "GET", url: "\(project.apiBase)/repos/\(project.path)", body: nil)
        case .gitlab: return APIRequest(method: "GET", url: "\(project.apiBase)/projects/\(gitlabID(project))", body: nil)
        }
    }

    /// The calls for a commit's CI status: GitHub has two systems — check runs (Actions) and the older
    /// commit statuses — and both are asked; GitLab has its pipelines.
    public static func ciRequests(_ project: HostingProject, sha: String) -> [APIRequest] {
        switch project.kind {
        case .github:
            return [APIRequest(method: "GET", url: "\(project.apiBase)/repos/\(project.path)/commits/\(sha)/check-runs?per_page=100", body: nil),
                    APIRequest(method: "GET", url: "\(project.apiBase)/repos/\(project.path)/commits/\(sha)/status", body: nil)]
        case .gitlab:
            return [APIRequest(method: "GET",
                               url: "\(project.apiBase)/projects/\(gitlabID(project))/pipelines?sha=\(query(sha))&per_page=1",
                               body: nil)]
        }
    }

    /// Open a pull request (a merge request at GitLab) from `head` into `base`.
    public static func createPullRequestRequest(_ project: HostingProject, title: String, body: String,
                                                head: String, base: String, draft: Bool) -> APIRequest {
        let payload: [String: Any]
        let url: String
        switch project.kind {
        case .github:
            url = "\(project.apiBase)/repos/\(project.path)/pulls"
            payload = ["title": title, "body": body, "head": head, "base": base, "draft": draft]
        case .gitlab:
            url = "\(project.apiBase)/projects/\(gitlabID(project))/merge_requests"
            // GitLab marks a draft by its title.
            payload = ["title": draft ? "Draft: " + title : title, "description": body,
                       "source_branch": head, "target_branch": base, "remove_source_branch": false]
        }
        let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return APIRequest(method: "POST", url: url, body: data)
    }

    /// The ref the service publishes a pull request's commits under.
    public static func pullRequestRef(_ project: HostingProject, number: Int) -> String {
        project.kind == .github ? "pull/\(number)/head" : "merge-requests/\(number)/head"
    }

    /// Bring an already checked-out pull-request branch up to date: git refuses to fetch into the branch
    /// that is checked out, so the commits go to FETCH_HEAD and the branch moves forward to them — and
    /// refuses, rather than losing anything, when the pull request was force-pushed.
    public static func updatePullRequestArguments(_ project: HostingProject, number: Int) -> [[String]] {
        [["fetch", project.remote, pullRequestRef(project, number: number)], ["merge", "--ff-only", "FETCH_HEAD"]]
    }

    /// Whether the branch has to be pushed before a pull request can name it, and how: its upstream must
    /// be the same branch on the project's remote with nothing left to push. Any other upstream — a
    /// branch started from `origin/main` tracks main — means the remote has no such branch yet.
    public static func pushBeforePullRequest(branch: String, upstream: String?, ahead: Int,
                                             remote: String) -> [String]? {
        let own = "\(remote)/\(branch)"
        if upstream == own { return ahead > 0 ? ["push", remote, "HEAD"] : nil }
        return ["push", "--set-upstream", remote, "HEAD"]
    }

    /// Fetch a pull request's commits into a local branch, whether or not its branch lives in this
    /// repository (a fork's does not): both services publish every one under a ref of its own.
    public static func fetchPullRequestArguments(_ project: HostingProject, number: Int) -> (arguments: [String], branch: String) {
        switch project.kind {
        case .github:
            let branch = "pr/\(number)"
            return (["fetch", project.remote, "+pull/\(number)/head:\(branch)"], branch)
        case .gitlab:
            let branch = "mr/\(number)"
            return (["fetch", project.remote, "+merge-requests/\(number)/head:\(branch)"], branch)
        }
    }

    // MARK: Answers

    public struct PullRequest: Sendable, Equatable {
        public var number: Int
        public var title: String
        public var author: String
        public var sourceBranch: String
        public var targetBranch: String
        public var webURL: String
        public var isDraft: Bool
        public var updated: Date?
        public var body: String
        /// The commit at the tip of the source branch, for its CI status.
        public var headSHA: String?
    }

    public struct Issue: Sendable, Equatable {
        public var number: Int
        public var title: String
        public var author: String
        public var webURL: String
        public var labels: [String]
        public var updated: Date?
        public var body: String
    }

    private static func json(_ data: Data) -> Any? { try? JSONSerialization.jsonObject(with: data) }

    private static func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    public static func parsePullRequests(_ data: Data, kind: HostKind) -> [PullRequest]? {
        guard let items = json(data) as? [[String: Any]] else { return nil }
        return items.compactMap { item in
            switch kind {
            case .github:
                guard let number = item["number"] as? Int else { return nil }
                let head = item["head"] as? [String: Any], base = item["base"] as? [String: Any]
                return PullRequest(number: number, title: item["title"] as? String ?? "",
                                   author: (item["user"] as? [String: Any])?["login"] as? String ?? "",
                                   sourceBranch: head?["ref"] as? String ?? "", targetBranch: base?["ref"] as? String ?? "",
                                   webURL: item["html_url"] as? String ?? "", isDraft: item["draft"] as? Bool ?? false,
                                   updated: date(item["updated_at"]), body: item["body"] as? String ?? "",
                                   headSHA: head?["sha"] as? String)
            case .gitlab:
                guard let number = item["iid"] as? Int else { return nil }
                let title = item["title"] as? String ?? ""
                return PullRequest(number: number, title: title,
                                   author: (item["author"] as? [String: Any])?["username"] as? String ?? "",
                                   sourceBranch: item["source_branch"] as? String ?? "",
                                   targetBranch: item["target_branch"] as? String ?? "",
                                   webURL: item["web_url"] as? String ?? "",
                                   isDraft: item["draft"] as? Bool ?? item["work_in_progress"] as? Bool ?? false,
                                   updated: date(item["updated_at"]), body: item["description"] as? String ?? "",
                                   headSHA: item["sha"] as? String)
            }
        }
    }

    public static func parseIssues(_ data: Data, kind: HostKind) -> [Issue]? {
        guard let items = json(data) as? [[String: Any]] else { return nil }
        return items.compactMap { item in
            switch kind {
            case .github:
                // GitHub lists pull requests among the issues; they have a tab of their own.
                guard item["pull_request"] == nil, let number = item["number"] as? Int else { return nil }
                let labels = (item["labels"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
                return Issue(number: number, title: item["title"] as? String ?? "",
                             author: (item["user"] as? [String: Any])?["login"] as? String ?? "",
                             webURL: item["html_url"] as? String ?? "", labels: labels,
                             updated: date(item["updated_at"]), body: item["body"] as? String ?? "")
            case .gitlab:
                guard let number = item["iid"] as? Int else { return nil }
                return Issue(number: number, title: item["title"] as? String ?? "",
                             author: (item["author"] as? [String: Any])?["username"] as? String ?? "",
                             webURL: item["web_url"] as? String ?? "", labels: item["labels"] as? [String] ?? [],
                             updated: date(item["updated_at"]), body: item["description"] as? String ?? "")
            }
        }
    }

    public static func parseDefaultBranch(_ data: Data) -> String? {
        (json(data) as? [String: Any])?["default_branch"] as? String
    }

    /// The created pull request's number and page.
    public static func parseCreated(_ data: Data, kind: HostKind) -> (number: Int, webURL: String)? {
        guard let item = json(data) as? [String: Any] else { return nil }
        let number = item[kind == .github ? "number" : "iid"] as? Int
        let url = item[kind == .github ? "html_url" : "web_url"] as? String
        guard let number, let url else { return nil }
        return (number, url)
    }

    /// The overall verdict of a commit's CI, worst first: one failure fails it, one still running keeps
    /// it pending.
    public enum CIState: String, Sendable, Equatable { case success, failure, pending, none }

    public struct CICheck: Sendable, Equatable {
        public var name: String
        public var state: CIState
        public var webURL: String?
    }

    public struct CIStatus: Sendable, Equatable {
        public var state: CIState
        public var checks: [CICheck]
        public static let none = CIStatus(state: .none, checks: [])
    }

    static func combined(_ states: [CIState]) -> CIState {
        if states.isEmpty { return .none }
        if states.contains(.failure) { return .failure }
        if states.contains(.pending) { return .pending }
        if states.allSatisfy({ $0 == .none }) { return .none }
        return .success
    }

    /// GitHub's answers to `ciRequests`, in order: check runs, then the combined commit status.
    public static func parseGitHubCI(checkRuns: Data?, status: Data?) -> CIStatus {
        var checks: [CICheck] = []
        if let checkRuns, let root = json(checkRuns) as? [String: Any], let runs = root["check_runs"] as? [[String: Any]] {
            for run in runs {
                let state: CIState
                if run["status"] as? String != "completed" {
                    state = .pending
                } else {
                    switch run["conclusion"] as? String {
                    case "success", "neutral", "skipped": state = .success
                    case "failure", "timed_out", "cancelled", "action_required", "startup_failure", "stale": state = .failure
                    default: state = .none
                    }
                }
                checks.append(CICheck(name: run["name"] as? String ?? "", state: state, webURL: run["html_url"] as? String))
            }
        }
        if let status, let root = json(status) as? [String: Any], let statuses = root["statuses"] as? [[String: Any]] {
            for item in statuses {
                let state: CIState
                switch item["state"] as? String {
                case "success": state = .success
                case "failure", "error": state = .failure
                case "pending": state = .pending
                default: state = .none
                }
                checks.append(CICheck(name: item["context"] as? String ?? "", state: state, webURL: item["target_url"] as? String))
            }
        }
        return CIStatus(state: combined(checks.map(\.state)), checks: checks)
    }

    /// GitLab's latest pipeline for the commit — one check, the pipeline itself.
    public static func parseGitLabCI(_ data: Data?) -> CIStatus {
        guard let data, let pipelines = json(data) as? [[String: Any]], let latest = pipelines.first else { return .none }
        let state: CIState
        switch latest["status"] as? String {
        case "success": state = .success
        case "failed", "canceled": state = .failure
        case "created", "waiting_for_resource", "preparing", "pending", "running", "scheduled", "manual": state = .pending
        default: state = .none
        }
        let name = "pipeline #\((latest["id"] as? Int).map(String.init) ?? "?")"
        return CIStatus(state: state, checks: [CICheck(name: name, state: state, webURL: latest["web_url"] as? String)])
    }

    /// What the service said went wrong, for the window's status line: its own message when it gave one.
    public static func apiErrorMessage(_ data: Data, status: Int) -> String {
        if let root = json(data) as? [String: Any] {
            if let message = root["message"] as? String {
                if let errors = root["errors"] as? [[String: Any]],
                   let first = errors.first?["message"] as? String { return "\(message): \(first)" }
                return message
            }
            if let message = root["message"] as? [String: Any] {
                return message.map { "\($0.key) \($0.value)" }.sorted().joined(separator: "; ")
            }
            if let message = root["error_description"] as? String ?? root["error"] as? String { return message }
        }
        return "HTTP \(status)"
    }

    /// How many calls are left before the service starts refusing, from the response's headers, when
    /// it says. GitHub and GitLab spell the header differently.
    public static func rateLimitRemaining(_ headers: [String: String]) -> Int? {
        let lower = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
        return (lower["x-ratelimit-remaining"] ?? lower["ratelimit-remaining"]).flatMap { Int($0) }
    }

    /// A pull request's body, prefilled from the branch's commits: one commit gives its message; several
    /// give their subjects as a list.
    public static func pullRequestDraft(subjects: [String], firstMessage: String?) -> (title: String, body: String) {
        if subjects.count == 1 {
            let message = (firstMessage ?? subjects[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            var lines = message.components(separatedBy: "\n")
            let title = lines.isEmpty ? subjects[0] : lines.removeFirst()
            return (title, lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return (subjects.last ?? "", subjects.reversed().map { "- " + $0 }.joined(separator: "\n"))
    }
}

/// Sends `APIRequest`s with a token, off the main thread; the completion runs on the URLSession's
/// queue. One per window: it holds the token for as long as the window is open, and no longer.
public final class PluginGitHostingClient: @unchecked Sendable {
    public struct Response: Sendable {
        public let status: Int
        public let data: Data
        public let headers: [String: String]
        public var ok: Bool { (200..<300).contains(status) }
    }

    private let project: PluginGit.HostingProject
    private let token: String
    private let session: URLSession

    public init(project: PluginGit.HostingProject, token: String, session: URLSession = .shared) {
        self.project = project
        self.token = token
        self.session = session
    }

    /// nil response with an error message when the request never got an answer.
    public func send(_ request: PluginGit.APIRequest, completion: @escaping @Sendable (Response?, String?) -> Void) {
        // Host and port both: a token for gitlab.corp:8443 is not one for gitlab.corp.
        guard let url = URL(string: request.url), let api = URL(string: project.apiBase),
              url.host?.lowercased() == api.host?.lowercased(), url.port == api.port, url.scheme == api.scheme
        else {
            // The token goes to the project's own API host and nowhere else.
            completion(nil, "Refused to send the token to \(request.url)")
            return
        }
        var urlRequest = URLRequest(url: url, timeoutInterval: 30)
        urlRequest.httpMethod = request.method
        for (key, value) in PluginGit.apiHeaders(project.kind, token: token) { urlRequest.setValue(value, forHTTPHeaderField: key) }
        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        session.dataTask(with: urlRequest) { data, response, error in
            guard let http = response as? HTTPURLResponse else {
                completion(nil, error?.localizedDescription ?? "No answer")
                return
            }
            var headers: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                if let key = key as? String, let value = value as? String { headers[key] = value }
            }
            completion(Response(status: http.statusCode, data: data ?? Data(), headers: headers), nil)
        }.resume()
    }
}
