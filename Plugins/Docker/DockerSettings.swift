// SPDX-License-Identifier: Apache-2.0
// DockerSettings.swift — the handful of decisions this plugin lets the user make, and the file
// it keeps them in.
//
// It lives under the *host's* configuration root, which the host tells the plugin in `PfxInit`.
// Building the path out of Application Support instead would write into the developer's real
// settings during an automated run with `-ConfigRoot` pointed somewhere else — a trap the WebDAV
// and S3 plugins both fell into before the host learned to answer `configRoot`.

import Foundation

struct DockerSettings {
    /// A `DOCKER_HOST` value that overrides discovery, or "" for "find it".
    var endpoint: String = ""

    /// How much of a recursive archive is read before a listing gives up on being exact and
    /// falls back to asking the container itself.
    ///
    /// The engine has no "list a directory" call at all: the only universal way to see what is in
    /// one is `GET …/archive`, which answers with a tar of the directory *and everything under
    /// it*. For an ordinary directory that is a few hundred kilobytes and gives a perfect listing
    /// — every mode, size, time and symlink target, for a stopped container as readily as a
    /// running one. For a container's "/" it is the whole image. So the archive is tried first
    /// with this budget, and only a directory that blows through it costs a fallback.
    var probeBudgetMB: Int = 16

    /// The budget for the second attempt, made when there is no way to ask the container instead
    /// (it is stopped, or has no `ls`).
    ///
    /// Reaching it means the listing fails rather than showing part of a directory. That is not a
    /// timid default: the root of a stopped container built on a full-sized image really is
    /// unreadable this way — measured at 22 GB and 82 seconds for one ordinary application image
    /// — and the engine offers nothing cheaper. Deeper directories are unaffected, and a running
    /// container never reaches here at all.
    var maxBudgetMB: Int = 512

    /// A wall-clock ceiling on the same attempt, so that raising `MaxBudgetMB` cannot turn a
    /// listing into a minute of nothing happening. Bytes alone are the wrong measure on a slow
    /// engine — a remote one, or Docker Desktop's virtual machine under load.
    var maxBudgetSeconds: Int = 20

    /// Whether a directory too large to read as an archive may be listed by running `ls` inside a
    /// *running* container.
    ///
    /// Off makes the plugin use nothing but the archive API, which is the guarantee that matters:
    /// nothing here depends on a shell, `ls`, `cat` or `tar` existing in the image. On (the
    /// default) it is a fallback for the one case the archive cannot serve cheaply — and the
    /// command is `execve`d as an argument vector, never through a shell.
    var execFallback: Bool = true

    /// The image a throwaway container is made from when a volume has to be mounted to be read.
    /// Empty means "any image already on this machine".
    var helperImage: String = ""

    /// Whether the digest-named volumes Docker creates for containers that asked for a volume
    /// without naming one are listed. They hold real data, so they are on by default.
    var showAnonymousVolumes: Bool = true

    // MARK: Persistence

    /// The directory the host keeps its configuration in; set once from `PfxInit`.
    nonisolated(unsafe) static var configRoot: String =
        NSHomeDirectory() + "/Library/Application Support/PeachCommander"

    private static var fileURL: URL {
        URL(fileURLWithPath: configRoot)
            .appendingPathComponent("Docker", isDirectory: true)
            .appendingPathComponent("docker.ini")
    }

    static func load() -> DockerSettings {
        var settings = DockerSettings()
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return settings }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix(";"), !trimmed.hasPrefix("#"),
                  !trimmed.hasPrefix("["), let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[trimmed.startIndex..<equals].trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "Endpoint": settings.endpoint = value
            case "ProbeBudgetMB": settings.probeBudgetMB = max(1, Int(value) ?? settings.probeBudgetMB)
            case "MaxBudgetMB": settings.maxBudgetMB = max(1, Int(value) ?? settings.maxBudgetMB)
            case "MaxBudgetSeconds":
                settings.maxBudgetSeconds = max(1, Int(value) ?? settings.maxBudgetSeconds)
            case "ExecFallback": settings.execFallback = value != "0"
            case "HelperImage": settings.helperImage = value
            case "ShowAnonymousVolumes": settings.showAnonymousVolumes = value != "0"
            default: break
            }
        }
        return settings
    }

    func save() {
        let text = """
        ; Peach Commander — Docker provider. Written by the plugin, safe to edit by hand.
        [Docker]
        ; A DOCKER_HOST value that overrides discovery (unix:///… or tcp://host:port).
        Endpoint=\(endpoint)
        ; Archive bytes read before a listing falls back (see DockerSettings.swift).
        ProbeBudgetMB=\(probeBudgetMB)
        MaxBudgetMB=\(maxBudgetMB)
        MaxBudgetSeconds=\(maxBudgetSeconds)
        ; 0 = never run anything inside a container; the archive API is then the only path.
        ExecFallback=\(execFallback ? 1 : 0)
        ; Image for the throwaway container that makes a volume readable ("" = any local image).
        HelperImage=\(helperImage)
        ShowAnonymousVolumes=\(showAnonymousVolumes ? 1 : 0)

        """
        let url = Self.fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    var probeBudgetBytes: Int64 { Int64(probeBudgetMB) * 1024 * 1024 }
    var maxBudgetBytes: Int64 { Int64(maxBudgetMB) * 1024 * 1024 }
}
