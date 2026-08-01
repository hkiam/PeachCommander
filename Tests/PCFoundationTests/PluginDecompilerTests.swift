// SPDX-License-Identifier: Apache-2.0
// PluginDecompilerTests.swift - The decompiler engine runner (F-345).
//
// This code is compiled into plugins, so the app's own build never runs it: a mistake here would
// ship silently and only show up as a viewer that cannot decompile. The tests deliberately avoid
// needing a JVM — engines are described by data, so a fake "engine" that is just /bin/echo or a
// shell script exercises the same paths a real one does.

import XCTest

final class PluginDecompilerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-decomp-\(ProcessInfo.processInfo.globallyUniqueString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    @discardableResult
    private func script(_ name: String, _ body: String) throws -> String {
        let path = dir.appendingPathComponent(name).path
        try ("#!/bin/sh\n" + body).write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    // MARK: - Descriptors and routing

    /// The built-ins must cover the format the first plugin is for, and must not claim formats
    /// they cannot read — `kinds` is what a future .dex plugin will route on.
    func testBuiltInsCoverClassAndRouteByKind() {
        let engines = PluginDecompilerEngine.builtIns(engineDirectory: "/tmp/engines")
        XCTAssertFalse(engines.filter { $0.handles(kind: "class") }.isEmpty)
        // The invariant is that formats stay apart, not that dex is absent — asserting the latter
        // encoded a passing state rather than a rule, and broke the moment jadx was added.
        XCTAssertTrue(engines.allSatisfy { !$0.handles(kind: "elf") },
                      "no bundled descriptor should claim a format none of them can read")
        // javap is bytecode-only: it must not be offered for a whole jar.
        let javap = engines.first { $0.id == "javap" }
        XCTAssertEqual(javap?.kinds, ["class"])
    }

    /// Every descriptor has to explain itself, because the view shows this text when the engine is
    /// missing — and for JVM engines the licence is the reason we ship no binary.
    func testEveryBuiltInCarriesANote() {
        for e in PluginDecompilerEngine.builtIns(engineDirectory: "/tmp/e") {
            XCTAssertFalse(e.note?.isEmpty ?? true, "\(e.id) has no note")
        }
    }

    /// The architecture claim, asserted: a new format costs a descriptor and nothing else. If this
    /// ever needs a change to the runner, the design did not hold.
    func testANewFormatIsRoutedByKindAlone() {
        let engines = PluginDecompilerEngine.builtIns(engineDirectory: "/tmp/e")
        let dex = engines.filter { $0.handles(kind: "dex") }
        XCTAssertFalse(dex.isEmpty, "no engine claims dex")
        XCTAssertTrue(dex.allSatisfy { $0.output == .directory },
                      "jadx writes files; the runner's directory mode must be what carries it")
        // …and the formats stay apart: a class engine must not be offered for a dex and vice versa.
        XCTAssertTrue(engines.filter { $0.handles(kind: "class") }.allSatisfy { !$0.handles(kind: "dex") })
        // A whole app takes longer than a single class, so the descriptor raises its own limit.
        XCTAssertGreaterThan(dex.first!.timeout, PluginDecompilerEngine.defaultTimeout)
    }

    // MARK: - The user's own engines

    func testUserEngineIsParsed() {
        let (engines, warnings) = PluginDecompilerRegistry.parse("""
            [mine]
            name   = My Decompiler
            kinds  = class, jar
            tool   = /usr/bin/true
            args   = --quiet {input}
            output = stdout
            """, engineDirectory: "/tmp/e")
        XCTAssertTrue(warnings.isEmpty, "warnings: \(warnings)")
        XCTAssertEqual(engines.count, 1)
        XCTAssertEqual(engines.first?.name, "My Decompiler")
        XCTAssertEqual(engines.first?.kinds, ["class", "jar"])
        XCTAssertEqual(engines.first?.args, ["--quiet", "{input}"])
    }

    /// A section without the two fields that make an engine runnable is skipped *and* reported —
    /// silently ignoring it would leave the user wondering why their engine never appears.
    func testIncompleteSectionsAreSkippedWithAWarning() {
        let (engines, warnings) = PluginDecompilerRegistry.parse("""
            [notool]
            kinds = class
            [nokinds]
            tool = /bin/echo
            """, engineDirectory: "/tmp/e")
        XCTAssertTrue(engines.isEmpty)
        XCTAssertEqual(warnings.count, 2, "warnings: \(warnings)")
        XCTAssertTrue(warnings.contains { $0.contains("notool") && $0.contains("tool") })
        XCTAssertTrue(warnings.contains { $0.contains("nokinds") && $0.contains("kinds") })
    }

    /// Paths with spaces are normal on macOS ("Application Support"), so quoting has to survive.
    func testArgumentsSplitOnSpacesButRespectQuotes() {
        XCTAssertEqual(PluginDecompilerRegistry.splitArguments(#"-jar "/a b/c.jar" {input}"#),
                       ["-jar", "/a b/c.jar", "{input}"])
        XCTAssertEqual(PluginDecompilerRegistry.splitArguments(""), [])
    }

    /// A configured engine is an explicit instruction and must beat the built-ins — the rule the
    /// host already applies to text formatters. Getting this backwards means someone who
    /// described their own decompiler still gets ours.
    func testUserEnginesArePreferredOverBuiltIns() throws {
        let dir = self.dir.appendingPathComponent("decompilers")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
            [mine]
            kinds = class
            tool  = /usr/bin/true
            """.write(to: dir.appendingPathComponent("decompilers.ini"),
                      atomically: true, encoding: .utf8)
        let registry = PluginDecompilerRegistry(configRoot: self.dir.path)
        XCTAssertEqual(registry.engines(for: "class").first?.id, "mine")
    }

    /// Reusing a built-in id must *replace* it rather than add a second entry, so pointing CFR at
    /// another jar does not leave two CFRs in the menu.
    func testUserEntryWithABuiltInIdReplacesIt() throws {
        let dir = self.dir.appendingPathComponent("decompilers")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
            [cfr]
            name  = My CFR
            kinds = class
            tool  = /usr/bin/true
            """.write(to: dir.appendingPathComponent("decompilers.ini"),
                      atomically: true, encoding: .utf8)
        let engines = PluginDecompilerRegistry(configRoot: self.dir.path).engines(for: "class")
        XCTAssertEqual(engines.filter { $0.id == "cfr" }.count, 1)
        XCTAssertEqual(engines.first(where: { $0.id == "cfr" })?.name, "My CFR")
    }

    // MARK: - Availability

    func testAvailabilityDistinguishesMissingToolFromMissingPayload() throws {
        let tool = try script("engine.sh", "echo hi")
        let present = PluginDecompilerEngine(id: "a", name: "A", kinds: ["class"], tool: tool,
                                       args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30)
        XCTAssertTrue(present.isAvailable)
        XCTAssertNil(present.missingPath)

        let noJar = PluginDecompilerEngine(id: "b", name: "B", kinds: ["class"], tool: tool,
                                     args: [], enginePath: "/nope/x.jar", output: .stdout, note: nil, timeout: 30)
        XCTAssertFalse(noJar.isAvailable)
        XCTAssertEqual(noJar.missingPath, "/nope/x.jar",
                       "the message must be able to name the file the user has to install")

        let noTool = PluginDecompilerEngine(id: "c", name: "C", kinds: ["class"], tool: "/nope/tool",
                                      args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30)
        XCTAssertFalse(noTool.isAvailable)
    }

    // MARK: - Running

    func testStdoutEngineReturnsItsOutput() throws {
        let tool = try script("cat.sh", #"cat "$1""#)
        let input = dir.appendingPathComponent("Foo.class").path
        try "class Foo {}".write(toFile: input, atomically: true, encoding: .utf8)
        let engine = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: tool,
                                      args: ["{input}"], enginePath: nil, output: .stdout, note: nil, timeout: 30)
        XCTAssertEqual(try PluginDecompilerRunner.run(engine, input: input).get(), "class Foo {}")
    }

    /// Templating is the whole configuration surface: get it wrong and every engine is invoked
    /// with the wrong file.
    func testTemplatePlaceholdersAreSubstituted() throws {
        let tool = try script("args.sh", #"printf '%s\n' "$@""#)
        // A real payload file: the availability check runs before the arguments are built, so a
        // made-up jar path would fail earlier and this would test nothing.
        let jar = dir.appendingPathComponent("cfr.jar").path
        try Data().write(to: URL(fileURLWithPath: jar))
        let engine = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: tool,
                                      args: ["-jar", "{engine}", "{input}"],
                                      enginePath: jar, output: .stdout, note: nil, timeout: 30)
        let text = try PluginDecompilerRunner.run(engine, input: "/x/Foo.class").get()
        XCTAssertEqual(text.split(separator: "\n").map(String.init),
                       ["-jar", jar, "/x/Foo.class"])
    }

    /// Engines that write files instead of printing — Vineflower's default — must work too, and
    /// the temp directory must not be left behind.
    func testDirectoryEngineCollectsWhatItWrote() throws {
        let tool = try script("writer.sh", #"echo "decompiled" > "$2/Foo.java""#)
        let engine = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: tool,
                                      args: ["{input}", "{outdir}"], enginePath: nil,
                                      output: .directory, note: nil, timeout: 30)
        XCTAssertEqual(try PluginDecompilerRunner.run(engine, input: "/x/Foo.class").get(),
                       "decompiled\n")
    }

    /// A failing engine must surface its own diagnostics: "exit 1" alone tells the user nothing.
    func testFailureCarriesTheEnginesDiagnostics() throws {
        let tool = try script("fail.sh", "echo 'not a class file' >&2; exit 3")
        let engine = PluginDecompilerEngine(id: "e", name: "Broken", kinds: ["class"], tool: tool,
                                      args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30)
        guard case .failure(let error) = PluginDecompilerRunner.run(engine, input: "/x") else {
            return XCTFail("expected a failure")
        }
        guard case .engineFailed(let name, let code, let message) = error else {
            return XCTFail("expected engineFailed, got \(error)")
        }
        XCTAssertEqual(name, "Broken")
        XCTAssertEqual(code, 3)
        XCTAssertTrue(message.contains("not a class file"))
        XCTAssertTrue(error.userMessage.contains("not a class file"),
                      "the status line must show the engine's own reason: \(error.userMessage)")
    }

    /// An engine that exits 0 but prints nothing is a failure, not an empty document.
    func testSilentSuccessIsTreatedAsFailure() throws {
        let tool = try script("quiet.sh", "exit 0")
        let engine = PluginDecompilerEngine(id: "e", name: "Quiet", kinds: ["class"], tool: tool,
                                      args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30)
        guard case .failure(.emptyOutput) = PluginDecompilerRunner.run(engine, input: "/x") else {
            return XCTFail("expected emptyOutput")
        }
    }

    /// Output larger than a pipe buffer must not deadlock — the case this is actually for is a
    /// big class, and reading only after waitUntilExit would hang exactly there.
    func testLargeOutputDoesNotDeadlock() throws {
        let tool = try script("big.sh", "for i in $(seq 1 20000); do echo 'public void method();'; done")
        let engine = PluginDecompilerEngine(id: "e", name: "Big", kinds: ["class"], tool: tool,
                                      args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30)
        let text = try PluginDecompilerRunner.run(engine, input: "/x").get()
        XCTAssertEqual(text.split(separator: "\n").count, 20000)
    }

    /// An engine that never finishes must be stopped and reported, not left to spin while the view
    /// says "Decompiling…" for ever. Obfuscated bytecode really does send decompilers into loops.
    func testAnEngineThatHangsIsStoppedAndReported() throws {
        let tool = try script("forever.sh", "sleep 60")
        let engine = PluginDecompilerEngine(id: "e", name: "Slow", kinds: ["class"], tool: tool,
                                      args: [], enginePath: nil, output: .stdout, note: nil,
                                      timeout: 1)
        let started = Date()
        guard case .failure(let error) = PluginDecompilerRunner.run(engine, input: "/x") else {
            return XCTFail("expected a failure")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 10, "the watchdog did not fire")
        guard case .timedOut(let name, let seconds) = error else {
            return XCTFail("expected timedOut, got \(error)")
        }
        XCTAssertEqual(name, "Slow")
        XCTAssertEqual(seconds, 1)
        XCTAssertTrue(error.userMessage.contains("1 second"), error.userMessage)
    }

    /// Nothing on stdin, so whether a tool blocks cannot depend on how the app was launched.
    func testAToolReadingStdinGetsEOFRatherThanWaiting() throws {
        let tool = try script("readstdin.sh", "cat; echo done")
        let engine = PluginDecompilerEngine(id: "e", name: "Reader", kinds: ["class"], tool: tool,
                                      args: [], enginePath: nil, output: .stdout, note: nil,
                                      timeout: 5)
        XCTAssertEqual(try PluginDecompilerRunner.run(engine, input: "/x").get(), "done\n")
    }

    /// `~` and bare file names in the config must resolve the way the user expects: a jar named in
    /// the engine folder, not against a working directory a GUI app never shows them.
    func testPathsResolveAgainstTheEngineFolderAndHome() {
        let (engines, _) = PluginDecompilerRegistry.parse("""
            [a]
            kinds  = class
            tool   = ~/bin/mytool
            engine = cfr.jar
            """, engineDirectory: "/opt/engines")
        XCTAssertEqual(engines.first?.tool, (NSHomeDirectory() as NSString).appendingPathComponent("bin/mytool"))
        XCTAssertEqual(engines.first?.enginePath, "/opt/engines/cfr.jar")
    }

    func testTimeoutIsConfigurablePerEngine() {
        let (engines, _) = PluginDecompilerRegistry.parse("""
            [a]
            kinds   = class
            tool    = /bin/echo
            timeout = 120
            """, engineDirectory: "/e")
        XCTAssertEqual(engines.first?.timeout, 120)
        let (defaulted, _) = PluginDecompilerRegistry.parse("[b]\nkinds = class\ntool = /bin/echo",
                                                      engineDirectory: "/e")
        XCTAssertEqual(defaulted.first?.timeout, PluginDecompilerEngine.defaultTimeout)
    }

    // MARK: - Cache, preference, profiles (F-347)

    /// The key must change when the file changes, or a rebuilt class would show yesterday's source.
    func testCacheKeyFollowsFileAndArguments() throws {
        let file = dir.appendingPathComponent("A.class").path
        try "one".write(toFile: file, atomically: true, encoding: .utf8)
        let engine = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: "/bin/echo",
                                            args: ["-a"], enginePath: nil, output: .stdout,
                                            note: nil, timeout: 5)
        let first = PluginDecompilerCache.key(path: file, engine: engine)
        XCTAssertNotNil(first)

        // Same everything: same key.
        XCTAssertEqual(first, PluginDecompilerCache.key(path: file, engine: engine))

        // Different flags are a different result even for the same engine id.
        let profile = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: "/bin/echo",
                                            args: ["-b"], enginePath: nil, output: .stdout,
                                            note: nil, timeout: 5)
        XCTAssertNotEqual(first, PluginDecompilerCache.key(path: file, engine: profile))

        // A rebuilt file must invalidate it.
        try "two, and longer".write(toFile: file, atomically: true, encoding: .utf8)
        XCTAssertNotEqual(first, PluginDecompilerCache.key(path: file, engine: engine))
    }

    func testCacheRoundTrips() throws {
        let file = dir.appendingPathComponent("B.class").path
        try "x".write(toFile: file, atomically: true, encoding: .utf8)
        let engine = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: "/bin/echo",
                                            args: [], enginePath: nil, output: .stdout,
                                            note: nil, timeout: 5)
        XCTAssertNil(PluginDecompilerCache.read(path: file, engine: engine, configRoot: dir.path))
        PluginDecompilerCache.write("class B {}", path: file, engine: engine, configRoot: dir.path)
        XCTAssertEqual(PluginDecompilerCache.read(path: file, engine: engine, configRoot: dir.path),
                       "class B {}")
    }

    /// A missing file must not produce a key at all — otherwise every unreadable path would share
    /// one cache entry and serve each other's contents.
    func testNoCacheKeyForAMissingFile() {
        let engine = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: "/bin/echo",
                                            args: [], enginePath: nil, output: .stdout,
                                            note: nil, timeout: 5)
        XCTAssertNil(PluginDecompilerCache.key(path: "/nope/nothing.class", engine: engine))
    }

    func testPreferredEngineRoundTripsPerKind() {
        XCTAssertTrue(PluginDecompilerPreference.read(configRoot: dir.path).isEmpty)
        PluginDecompilerPreference.set(engine: "vineflower", forKind: "class", configRoot: dir.path)
        PluginDecompilerPreference.set(engine: "jadx", forKind: "dex", configRoot: dir.path)
        let values = PluginDecompilerPreference.read(configRoot: dir.path)
        XCTAssertEqual(values["class"], "vineflower")
        XCTAssertEqual(values["dex"], "jadx")
        // Changing one must not lose the other.
        PluginDecompilerPreference.set(engine: "cfr", forKind: "class", configRoot: dir.path)
        XCTAssertEqual(PluginDecompilerPreference.read(configRoot: dir.path)["dex"], "jadx")
    }

    /// `extends` is what makes several presets of one engine practical: inherit the tool and jar,
    /// override only the flags.
    func testProfileInheritsFromABuiltIn() {
        let (engines, warnings) = PluginDecompilerRegistry.parse("""
            [cfr-sugar]
            name    = CFR (sugared)
            extends = cfr
            args    = -jar {engine} --sugarenums true {input}
            """, engineDirectory: "/opt/e")
        XCTAssertTrue(warnings.isEmpty, "warnings: \(warnings)")
        guard let e = engines.first else { return XCTFail("nothing parsed") }
        XCTAssertEqual(e.tool, "java", "tool inherited")
        XCTAssertEqual(e.kinds, ["class", "jar"], "kinds inherited")
        XCTAssertEqual(e.enginePath, "/opt/e/cfr.jar", "jar inherited")
        XCTAssertTrue(e.args.contains("--sugarenums"), "args overridden")
    }

    func testUnknownExtendsIsReported() {
        let (_, warnings) = PluginDecompilerRegistry.parse("""
            [x]
            extends = nosuchengine
            kinds = class
            tool = /bin/echo
            """, engineDirectory: "/e")
        XCTAssertTrue(warnings.contains { $0.contains("nosuchengine") }, "warnings: \(warnings)")
    }

    // MARK: - Messages

    func testEveryErrorSaysSomethingSpecific() {
        let cases: [PluginDecompileError] = [
            .noEngine(kind: "class"),
            .engineMissing(engine: "CFR", path: "/x/cfr.jar"),
            .engineFailed(engine: "CFR", exitCode: 1, message: "boom"),
            .emptyOutput(engine: "CFR"),
            .timedOut(engine: "CFR", seconds: 30),
            .notReadable("not a class file"),
        ]
        for c in cases {
            XCTAssertFalse(c.userMessage.isEmpty)
            XCTAssertFalse(c.userMessage.lowercased() == "failed", "too vague: \(c.userMessage)")
        }
        XCTAssertTrue(PluginDecompileError.engineMissing(engine: "CFR", path: "/x/cfr.jar")
            .userMessage.contains("/x/cfr.jar"), "must name the missing file")
    }
}
