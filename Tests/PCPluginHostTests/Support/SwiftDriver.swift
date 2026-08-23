// SPDX-License-Identifier: Apache-2.0
// SwiftDriver.swift - compile a plugin source with a driver, run it, read back tab-separated output.
//
// Three test files (S3XML, S3Signer, S3AWSConfig) each carried their own copy of this: write a
// main.swift, compile it against a plugin source with -O, run it, split the output on tabs. Beyond
// being three places to fix one bug, it was three places paying the compiler per test — 49.6 s for
// ten S3AWSConfig tests, which compile eight files each time.
//
// Two things fix that. The compile is memoized per driver source (`CachedPluginBuild`), and drivers
// that differ only in their *data* take it through argv and stdin instead of through string
// interpolation — so a group of tests that ask the same question of different input compiles once
// and runs N times. The driver still holds the real plugin source to exact strings, which is the
// property these files exist for.

import Foundation
import XCTest

enum SwiftDriver {
    /// Build `body` against `sources` (once per distinct body) and run it.
    ///
    /// - Parameters:
    ///   - label: names the cache entry; the driver source is hashed in alongside it.
    ///   - sources: repo-relative Swift files compiled into the driver.
    ///   - extraFlags: anything else swiftc needs — bridging headers, frameworks.
    ///   - arguments: passed to the driver process, so one compiled driver can answer many cases.
    ///   - stdin: fed to the driver, for input too large or too awkward to put in argv.
    /// - Returns: the driver's stdout as `key -> value`, split on the first tab of each line.
    static func run(label: String,
                    sources: [String],
                    extraFlags: [String] = [],
                    body: String,
                    arguments: [String] = [],
                    stdin: String? = nil,
                    repoRoot: URL) throws -> [String: String] {
        let binary = try CachedPluginBuild.artifact(key: "\(label)-\(body.hashValue)") { cache in
            let swiftc = "/usr/bin/swiftc"
            try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: swiftc), "swiftc unavailable")
            // Top-level statements are only allowed in a file called main.swift, which is why the
            // driver lives in a directory of its own rather than beside the binary.
            let driverDir = cache.appendingPathComponent("driver", isDirectory: true)
            try FileManager.default.createDirectory(at: driverDir, withIntermediateDirectories: true)
            let main = driverDir.appendingPathComponent("main.swift")
            try Data(body.utf8).write(to: main)

            let binary = cache.appendingPathComponent(label)
            let build = Process()
            build.executableURL = URL(fileURLWithPath: swiftc)
            build.arguments = ["-O", "-o", binary.path]
                + sources.map { repoRoot.appendingPathComponent($0).path }
                + [main.path] + extraFlags
            let buildErr = Pipe(); build.standardError = buildErr
            try build.run(); build.waitUntilExit()
            // A compiler that RAN and refused this is a failure, not a skip. The skip belongs to a
            // machine without swiftc; reusing it here means the day the source stops compiling, the
            // file reports success and says nothing. The failure is cached with the artifact, so
            // every test asking for this driver still goes red.
            guard build.terminationStatus == 0 else {
                let e = String(data: buildErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                throw PluginBuildFailure(description: "\(label) did not compile:\n\(e)")
            }
            return binary
        }
        let run = Process()
        run.executableURL = binary
        run.arguments = arguments
        let out = Pipe(); run.standardOutput = out
        if let stdin {
            let input = Pipe(); run.standardInput = input
            try run.run()
            // Written off the calling thread: a driver that fills its stdout pipe before it has
            // drained stdin would deadlock against a synchronous write here, and "the suite hangs
            // on one machine and not another" is an expensive shape of bug to go looking for.
            DispatchQueue.global().async {
                input.fileHandleForWriting.write(Data(stdin.utf8))
                try? input.fileHandleForWriting.close()
            }
        } else {
            try run.run()
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        run.waitUntilExit()
        XCTAssertEqual(run.terminationStatus, 0, "the \(label) driver did not run to completion")

        var result: [String: String] = [:]
        for line in (String(data: data, encoding: .utf8) ?? "").split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        return result
    }
}
