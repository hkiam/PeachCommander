// SPDX-License-Identifier: Apache-2.0
// S3Profiles.swift — the saved connections, and where they are allowed to live.
//
// Secrets are NOT here. The secret access key goes through the host's `crypt` callback into the
// Keychain; this file holds only what a user would happily read out loud — endpoint, region,
// addressing style, access key ID.
//
// The directory comes from `PfxInit`'s `getContext("configRoot")` and is never built from
// Application Support by hand. That is not tidiness: the host's root moves (`-ConfigRoot`,
// `PEACHCMD_CONFIG_ROOT`), which is how the test suite runs against a throwaway directory, and a
// plugin that builds its own path writes into the user's real settings during a test run. The WebDAV
// plugin did exactly that, to a real history, which is why the rule exists.

import Foundation

/// One saved connection. `Codable` so the file is obvious to read and edit by hand.
struct S3Profile: Codable, Equatable {
    var name: String            // what the drive chip and the dialog show
    var host: String            // "s3.eu-central-1.amazonaws.com", "127.0.0.1:9000"
    var useTLS: Bool
    var region: String
    var pathStyle: Bool
    var accessKeyID: String
    var anonymous: Bool

    /// The Keychain account this profile's secret is stored under. Includes the access key ID so
    /// that two keys for one endpoint do not overwrite each other's secret.
    var secretStore: String { "s3:\(host):\(accessKeyID)" }

    var endpoint: S3Endpoint {
        S3Endpoint(host: host, useTLS: useTLS, region: region, pathStyle: pathStyle)
    }

    static func makeDefault() -> S3Profile {
        S3Profile(name: "", host: "s3.amazonaws.com", useTLS: true, region: "us-east-1",
                  pathStyle: false, accessKeyID: "", anonymous: false)
    }
}

enum S3Profiles {
    /// Where the host keeps its configuration, learned from `PfxInit`. Nil until then.
    static var configRoot: String?

    private static let maximum = 40

    private static var directory: URL {
        let root = configRoot.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("PeachCommander", isDirectory: true)
        let base = root.appendingPathComponent("s3", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static var fileURL: URL { directory.appendingPathComponent("profiles.json") }

    static func load() -> [S3Profile] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([S3Profile].self, from: data)) ?? []
    }

    /// Insert or replace `profile`, most recently used first.
    ///
    /// Keyed on name, and a nameless profile is not saved at all: a connection the user did not name
    /// would come back as an unlabelled chip they cannot tell apart from the next one.
    static func save(_ profile: S3Profile) {
        guard !profile.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var list = load()
        list.removeAll { $0.name == profile.name }
        list.insert(profile, at: 0)
        if list.count > maximum { list = Array(list.prefix(maximum)) }
        write(list)
    }

    static func remove(name: String) {
        var list = load()
        list.removeAll { $0.name == name }
        write(list)
    }

    private static func write(_ list: [S3Profile]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(list) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Connection settings taken from the environment instead of the dialog.
///
/// Two jobs in one, and they are the same job: it is how the automated tests connect without a modal
/// dialog (the WebDAV plugin's `PC_WEBDAV_URL` does the same), and it is how someone who already has
/// credentials exported in their shell avoids typing them again.
enum S3Environment {
    /// A complete connection from the environment, or nil when `PC_S3_ENDPOINT` is not set.
    ///
    /// Returns the secret alongside the profile rather than storing it: an environment secret is not
    /// the user asking for it to be kept.
    static func connection() -> (profile: S3Profile, secret: String)? {
        let env = ProcessInfo.processInfo.environment
        guard let endpoint = env["PC_S3_ENDPOINT"], !endpoint.isEmpty else { return nil }

        // Accepted with or without a scheme, because both are what people paste.
        var host = endpoint
        var useTLS = true
        if let range = host.range(of: "://") {
            useTLS = host[host.startIndex..<range.lowerBound].lowercased() != "http"
            host = String(host[range.upperBound...])
        }
        if let slash = host.firstIndex(of: "/") { host = String(host[host.startIndex..<slash]) }

        let key = env["PC_S3_ACCESS_KEY"] ?? env["AWS_ACCESS_KEY_ID"] ?? ""
        let secret = env["PC_S3_SECRET_KEY"] ?? env["AWS_SECRET_ACCESS_KEY"] ?? ""
        let pathStyle = truthy(env["PC_S3_PATH_STYLE"])
        let profile = S3Profile(
            name: env["PC_S3_PROFILE"] ?? host,
            host: host,
            useTLS: useTLS,
            region: env["PC_S3_REGION"] ?? env["AWS_REGION"] ?? "us-east-1",
            // An endpoint reached by IP or with a port cannot be addressed virtual-hosted at all:
            // there is no wildcard name to put the bucket in front of. Defaulting to path-style
            // there saves the user a setting they would only discover by failing.
            pathStyle: pathStyle || looksLikeALocalEndpoint(host),
            accessKeyID: key,
            anonymous: key.isEmpty || secret.isEmpty)
        return (profile, secret)
    }

    static func truthy(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return value == "1" || value == "true" || value == "yes"
    }

    /// A host with a port, or one that is a bare IPv4 address, or `localhost`.
    static func looksLikeALocalEndpoint(_ host: String) -> Bool {
        if host.contains(":") { return true }                       // a port, or IPv6
        if host == "localhost" { return true }
        let parts = host.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy { UInt8($0) != nil }
    }
}
