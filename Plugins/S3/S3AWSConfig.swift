// SPDX-License-Identifier: Apache-2.0
// S3AWSConfig.swift — the credentials the AWS CLI already has.
//
// Anyone who uses `aws s3` has profiles in ~/.aws, and asking them to retype an access key into a
// dialog is asking them to keep a second copy of a secret. These are read, offered in the connect
// dialog, and never written: this file has no writer, and the profiles it returns are deliberately
// not saved into the plugin's own list — copying someone's credentials out of ~/.aws and into a
// second place is not something a file manager should do quietly.
//
// The format is INI with two wrinkles that matter. In ~/.aws/config every section except `default`
// is written `[profile name]`, while in ~/.aws/credentials it is plain `[name]` — mixing those up
// produces a profile called "profile foo". And config supports nested settings, which is where
// `s3.addressing_style = path` lives, i.e. exactly the setting this plugin needs for MinIO and Ceph.

import Foundation

/// One profile as the AWS CLI stores it. Everything is optional except the name, because a profile
/// may set only a region, or only credentials, and the two files are merged.
struct S3AWSProfile {
    let name: String
    let accessKeyID: String
    let secretAccessKey: String
    let sessionToken: String?
    let region: String?
    let endpointURL: String?
    let pathStyle: Bool?

    var hasCredentials: Bool { !accessKeyID.isEmpty && !secretAccessKey.isEmpty }
}

enum S3AWSConfig {
    /// Stands in for the home directory. A test seam: reading the developer's real ~/.aws would make
    /// the result depend on whose machine the suite runs on, and the assertions would then be about
    /// that person's AWS account.
    static var homeOverride: String?

    private static var home: URL {
        if let homeOverride { return URL(fileURLWithPath: homeOverride, isDirectory: true) }
        // `AWS_CONFIG_FILE` and `AWS_SHARED_CREDENTIALS_FILE` point elsewhere for people who keep
        // credentials outside their home directory, and honouring them costs nothing.
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    private static func path(_ envKey: String, default relative: String) -> URL {
        if let override = ProcessInfo.processInfo.environment[envKey], !override.isEmpty,
           homeOverride == nil {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        return home.appendingPathComponent(relative)
    }

    static var credentialsFile: URL {
        path("AWS_SHARED_CREDENTIALS_FILE", default: ".aws/credentials")
    }

    static var configFile: URL {
        path("AWS_CONFIG_FILE", default: ".aws/config")
    }

    // MARK: - INI

    /// Parse an AWS-style INI file into section -> key -> value.
    ///
    /// Nested settings are flattened with a dot, so
    ///
    ///     s3 =
    ///       addressing_style = path
    ///
    /// becomes `s3.addressing_style`. That is the only place the addressing style lives in the CLI's
    /// own configuration, and it is the setting that decides whether a MinIO endpoint works at all.
    static func parseINI(_ text: String) -> [String: [String: String]] {
        var out: [String: [String: String]] = [:]
        var section: String?
        var parent: String?
        for rawLine in text.components(separatedBy: .newlines) {
            // A comment may follow a value on the same line, but only when introduced by a space —
            // otherwise a secret containing '#' would be truncated, and the failure would look like
            // a wrong password.
            var line = rawLine
            if let hash = line.range(of: " #") { line = String(line[line.startIndex..<hash.lowerBound]) }
            if let semi = line.range(of: " ;") { line = String(line[line.startIndex..<semi.lowerBound]) }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") { continue }

            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                var name = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                // `[profile foo]` in config, `[foo]` in credentials, `[default]` in both.
                if name.hasPrefix("profile ") {
                    name = String(name.dropFirst("profile ".count)).trimmingCharacters(in: .whitespaces)
                }
                section = name
                parent = nil
                if out[name] == nil { out[name] = [:] }
                continue
            }

            guard let section, let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<equals]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: equals)...])
                .trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }

            // Indentation is what makes a line a sub-setting, so it is read from the raw line rather
            // than the trimmed one.
            let indented = rawLine.hasPrefix(" ") || rawLine.hasPrefix("\t")
            if value.isEmpty, !indented {
                // `s3 =` on its own opens a nested block.
                parent = key
                continue
            }
            if indented, let parent {
                out[section]?["\(parent).\(key)"] = value
            } else {
                parent = nil
                out[section]?[key] = value
            }
        }
        return out
    }

    // MARK: - Profiles

    /// Every profile the AWS CLI would see, credentials and config merged.
    static func profiles() -> [S3AWSProfile] {
        let credentials = (try? String(contentsOf: credentialsFile, encoding: .utf8))
            .map(parseINI) ?? [:]
        let config = (try? String(contentsOf: configFile, encoding: .utf8))
            .map(parseINI) ?? [:]

        var names = Array(credentials.keys)
        for name in config.keys where !names.contains(name) { names.append(name) }
        // `default` first, then the rest alphabetically — the order the CLI itself implies.
        names.sort { left, right in
            if left == "default" { return right != "default" }
            if right == "default" { return false }
            return left.localizedStandardCompare(right) == .orderedAscending
        }

        return names.compactMap { name in
            let c = credentials[name] ?? [:]
            let g = config[name] ?? [:]
            func value(_ key: String) -> String? {
                // Credentials wins: it is the file that exists to hold these, and a stale copy in
                // config should not shadow it.
                if let v = c[key], !v.isEmpty { return v }
                if let v = g[key], !v.isEmpty { return v }
                return nil
            }
            let key = value("aws_access_key_id") ?? ""
            let secret = value("aws_secret_access_key") ?? ""
            let style = value("s3.addressing_style")
            let profile = S3AWSProfile(
                name: name,
                accessKeyID: key,
                secretAccessKey: secret,
                sessionToken: value("aws_session_token"),
                region: value("region"),
                endpointURL: value("endpoint_url") ?? value("s3.endpoint_url"),
                pathStyle: style.map { $0.lowercased() == "path" })
            // A section with neither credentials nor a region says nothing useful — an `[sso-session]`
            // block, or a profile that only sets `output = json`. Offering it would put a name in the
            // dialog that cannot connect.
            guard profile.hasCredentials || profile.region != nil else { return nil }
            return profile
        }
    }

    /// An AWS CLI profile as this plugin's own connection settings, plus its secret.
    ///
    /// The endpoint is derived from the region when the profile does not name one, which is the
    /// normal case: `s3.<region>.amazonaws.com`, virtual-hosted, over TLS.
    static func connection(for profile: S3AWSProfile) -> (S3Profile, String) {
        var host = "s3.amazonaws.com"
        var useTLS = true
        var pathStyle = profile.pathStyle ?? false
        if let endpoint = profile.endpointURL, !endpoint.isEmpty {
            var text = endpoint
            if let range = text.range(of: "://") {
                useTLS = text[text.startIndex..<range.lowerBound].lowercased() != "http"
                text = String(text[range.upperBound...])
            }
            if let slash = text.firstIndex(of: "/") { text = String(text[text.startIndex..<slash]) }
            host = text
            // An endpoint reached by IP or carrying a port cannot be addressed virtual-hosted: there
            // is no wildcard name to put a bucket in front of.
            if profile.pathStyle == nil, S3Environment.looksLikeALocalEndpoint(host) { pathStyle = true }
        } else if let region = profile.region, !region.isEmpty, region != "us-east-1" {
            host = "s3.\(region).amazonaws.com"
        }
        let converted = S3Profile(
            name: profile.name,
            host: host,
            useTLS: useTLS,
            region: profile.region ?? "us-east-1",
            pathStyle: pathStyle,
            accessKeyID: profile.accessKeyID,
            anonymous: !profile.hasCredentials)
        return (converted, profile.secretAccessKey)
    }
}
