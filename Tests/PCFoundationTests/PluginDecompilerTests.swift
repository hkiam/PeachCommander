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
                                       args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30, archive: nil)
        XCTAssertTrue(present.isAvailable)
        XCTAssertNil(present.missingPath)

        let noJar = PluginDecompilerEngine(id: "b", name: "B", kinds: ["class"], tool: tool,
                                     args: [], enginePath: "/nope/x.jar", output: .stdout, note: nil, timeout: 30, archive: nil)
        XCTAssertFalse(noJar.isAvailable)
        XCTAssertEqual(noJar.missingPath, "/nope/x.jar",
                       "the message must be able to name the file the user has to install")

        let noTool = PluginDecompilerEngine(id: "c", name: "C", kinds: ["class"], tool: "/nope/tool",
                                      args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30, archive: nil)
        XCTAssertFalse(noTool.isAvailable)
    }

    // MARK: - Running

    func testStdoutEngineReturnsItsOutput() throws {
        let tool = try script("cat.sh", #"cat "$1""#)
        let input = dir.appendingPathComponent("Foo.class").path
        try "class Foo {}".write(toFile: input, atomically: true, encoding: .utf8)
        let engine = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: tool,
                                      args: ["{input}"], enginePath: nil, output: .stdout, note: nil, timeout: 30, archive: nil)
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
                                      enginePath: jar, output: .stdout, note: nil, timeout: 30, archive: nil)
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
                                      output: .directory, note: nil, timeout: 30, archive: nil)
        XCTAssertEqual(try PluginDecompilerRunner.run(engine, input: "/x/Foo.class").get(),
                       "decompiled\n")
    }

    /// A failing engine must surface its own diagnostics: "exit 1" alone tells the user nothing.
    func testFailureCarriesTheEnginesDiagnostics() throws {
        let tool = try script("fail.sh", "echo 'not a class file' >&2; exit 3")
        let engine = PluginDecompilerEngine(id: "e", name: "Broken", kinds: ["class"], tool: tool,
                                      args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30, archive: nil)
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
                                      args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30, archive: nil)
        guard case .failure(.emptyOutput) = PluginDecompilerRunner.run(engine, input: "/x") else {
            return XCTFail("expected emptyOutput")
        }
    }

    /// Output larger than a pipe buffer must not deadlock — the case this is actually for is a
    /// big class, and reading only after waitUntilExit would hang exactly there.
    func testLargeOutputDoesNotDeadlock() throws {
        let tool = try script("big.sh", "for i in $(seq 1 20000); do echo 'public void method();'; done")
        let engine = PluginDecompilerEngine(id: "e", name: "Big", kinds: ["class"], tool: tool,
                                      args: [], enginePath: nil, output: .stdout, note: nil, timeout: 30, archive: nil)
        let text = try PluginDecompilerRunner.run(engine, input: "/x").get()
        XCTAssertEqual(text.split(separator: "\n").count, 20000)
    }

    /// An engine that never finishes must be stopped and reported, not left to spin while the view
    /// says "Decompiling…" for ever. Obfuscated bytecode really does send decompilers into loops.
    func testAnEngineThatHangsIsStoppedAndReported() throws {
        let tool = try script("forever.sh", "sleep 60")
        let engine = PluginDecompilerEngine(id: "e", name: "Slow", kinds: ["class"], tool: tool,
                                      args: [], enginePath: nil, output: .stdout, note: nil,
                                      timeout: 1, archive: nil)
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
                                      timeout: 5, archive: nil)
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
                                            note: nil, timeout: 5, archive: nil)
        let first = PluginDecompilerCache.key(path: file, engine: engine)
        XCTAssertNotNil(first)

        // Same everything: same key.
        XCTAssertEqual(first, PluginDecompilerCache.key(path: file, engine: engine))

        // Different flags are a different result even for the same engine id.
        let profile = PluginDecompilerEngine(id: "e", name: "E", kinds: ["class"], tool: "/bin/echo",
                                            args: ["-b"], enginePath: nil, output: .stdout,
                                            note: nil, timeout: 5, archive: nil)
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
                                            note: nil, timeout: 5, archive: nil)
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
                                            note: nil, timeout: 5, archive: nil)
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

// MARK: - Whole-archive results (F-349)

/// The tree, the search and the archive-mode descriptors.
///
/// These test the parts a plugin's UI cannot: an NSOutlineView needs a host, but "which node holds
/// which file" and "which classes contain this string" are plain functions and belong here.
final class PluginDecompilerArchiveTests: XCTestCase {
    private var root = ""

    override func setUpWithError() throws {
        root = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pc-archive-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(atPath: root) }

    private func write(_ relative: String, _ body: String) throws {
        let full = (root as NSString).appendingPathComponent(relative)
        try FileManager.default.createDirectory(atPath: (full as NSString).deletingLastPathComponent,
                                               withIntermediateDirectories: true)
        try body.write(toFile: full, atomically: true, encoding: .utf8)
    }

    // MARK: The tree

    func testTreeNestsPackagesAndKeepsLeafPaths() {
        let nodes = PluginDecompilerNode.tree(from: ["com/example/A.java", "com/example/B.java"])
        // com/example collapses to one row: two levels with nothing to choose between them are two
        // clicks for no information.
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].name, "com/example")
        XCTAssertFalse(nodes[0].isLeaf)
        XCTAssertEqual(nodes[0].children.map(\.name), ["A.java", "B.java"])
        XCTAssertEqual(nodes[0].children[0].relativePath, "com/example/A.java")
    }

    func testTreeStopsCollapsingWhereThereIsAChoice() {
        let nodes = PluginDecompilerNode.tree(from: ["com/a/X.java", "com/b/Y.java"])
        XCTAssertEqual(nodes.map(\.name), ["com"])
        XCTAssertEqual(nodes[0].children.map(\.name), ["a", "b"])
    }

    func testTreeSortsPackagesBeforeClasses() {
        let nodes = PluginDecompilerNode.tree(from: ["Main.java", "util/Helper.java"])
        XCTAssertEqual(nodes.map(\.name), ["util", "Main.java"])
    }

    func testTreeHandlesFilesAtTheRoot() {
        let nodes = PluginDecompilerNode.tree(from: ["Main.java"])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertTrue(nodes[0].isLeaf)
        XCTAssertEqual(nodes[0].relativePath, "Main.java")
    }

    // MARK: Cross-class search

    func testSearchFindsTheClassAndTheLine() throws {
        try write("a/One.java", "class One {\n  String s = \"needle\";\n}\n")
        try write("b/Two.java", "class Two {}\n")
        let result = PluginDecompilerSearch.scan(files: ["a/One.java", "b/Two.java"], in: root,
                                                for: "needle", matchCase: false)
        XCTAssertFalse(result.capped)
        XCTAssertEqual(result.hits.count, 1)
        XCTAssertEqual(result.hits[0].relativePath, "a/One.java")
        XCTAssertEqual(result.hits[0].line, 2)
        XCTAssertEqual(result.hits[0].excerpt, "String s = \"needle\";")
    }

    func testSearchHonoursCaseWhenAsked() throws {
        try write("A.java", "class A { int Needle; }\n")
        XCTAssertEqual(PluginDecompilerSearch.scan(files: ["A.java"], in: root, for: "needle",
                                                   matchCase: false).hits.count, 1)
        XCTAssertTrue(PluginDecompilerSearch.scan(files: ["A.java"], in: root, for: "needle",
                                                  matchCase: true).hits.isEmpty)
    }

    func testSearchReportsOnlyTheFirstLinePerFile() throws {
        try write("A.java", "x\nneedle\nneedle\n")
        let hits = PluginDecompilerSearch.scan(files: ["A.java"], in: root, for: "needle",
                                               matchCase: false).hits
        // One hit per class, not per line: the tree lists files, and a file listed twice would be
        // two rows pointing at the same place.
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].line, 2)
    }

    func testSearchStopsWhenCancelled() throws {
        for i in 0..<20 { try write("F\(i).java", "needle\n") }
        var seen = 0
        let hits = PluginDecompilerSearch.scan(files: (0..<20).map { "F\($0).java" }, in: root,
                                               for: "needle", matchCase: false,
                                               isCancelled: { seen += 1; return seen > 3 }).hits
        XCTAssertLessThan(hits.count, 20, "a cancelled scan must not read every file")
    }

    func testSearchOfEmptyNeedleFindsNothing() {
        XCTAssertTrue(PluginDecompilerSearch.scan(files: ["A.java"], in: root, for: "",
                                                  matchCase: false).hits.isEmpty)
    }

    // MARK: What counts as a source file

    func testOnlySourceExtensionsAreListed() throws {
        try write("a/A.java", "x")
        try write("a/A.class", "x")
        try write("META-INF/MANIFEST.MF", "x")
        try write("b/B.smali", "x")
        XCTAssertEqual(PluginDecompilerRunner.sourceFiles(in: root), ["a/A.java", "b/B.smali"])
    }

    // MARK: Descriptors

    func testJavapCannotDoAnArchiveButCfrCan() {
        let engines = PluginDecompilerEngine.builtIns(engineDirectory: root)
        let javap = engines.first { $0.id == "javap" }!
        XCTAssertNil(javap.archive)
        XCTAssertFalse(javap.handlesArchive(kind: "class"))
        let cfr = engines.first { $0.id == "cfr" }!
        XCTAssertTrue(cfr.handlesArchive(kind: "jar"))
        // Whatever the arguments are, they must put the result where it is read from.
        XCTAssertTrue(cfr.archive!.args.contains("{outdir}"))
    }

    func testEveryArchiveCapableBuiltInWritesToOutdir() {
        for engine in PluginDecompilerEngine.builtIns(engineDirectory: root) {
            guard let archive = engine.archive else { continue }
            XCTAssertTrue(archive.args.contains("{outdir}"),
                          "\(engine.id): archive output is read from {outdir}, so it must be passed one")
            XCTAssertTrue(archive.args.contains("{input}"), "\(engine.id): no input")
            XCTAssertGreaterThan(archive.timeout, engine.timeout,
                                 "\(engine.id): a whole archive is slower than one class")
        }
    }

    func testArchiveEnginesExcludeThoseThatCannot() {
        let registry = PluginDecompilerRegistry(configRoot: root)
        XCTAssertFalse(registry.archiveEngines(for: "jar").contains { $0.id == "javap" })
        XCTAssertTrue(registry.archiveEngines(for: "jar").contains { $0.id == "cfr" })
        // Every kind the profile routes to the tree view must have at least one engine describing it,
        // or F3 on such a file would open a view nothing can ever fill. No exemptions: the carve-out
        // this once had was hiding three kinds that were claimed and unsupported.
        for kind in PluginDecompilerProfile.java.treeKinds {
            XCTAssertFalse(registry.archiveEngines(for: kind).isEmpty, "no archive engine for .\(kind)")
        }
    }

    // MARK: Configuration

    func testArchiveArgumentsCanBeConfigured() {
        let ini = """
        [mine]
        tool  = /bin/echo
        kinds = jar
        args  = {input}
        archive_args    = --all {input} -o {outdir}
        archive_timeout = 900
        """
        let engine = PluginDecompilerRegistry.parse(ini, engineDirectory: root).engines[0]
        XCTAssertEqual(engine.archive?.args, ["--all", "{input}", "-o", "{outdir}"])
        XCTAssertEqual(engine.archive?.timeout, 900)
    }

    func testAnEngineWithoutArchiveArgsClaimsNoArchiveSupport() {
        let ini = "[mine]\ntool = /bin/echo\nkinds = jar\nargs = {input}\n"
        let engine = PluginDecompilerRegistry.parse(ini, engineDirectory: root).engines[0]
        // Not "reuse args on a JAR": that would run a tool with flags its author never meant and
        // then blame the output on the user's file.
        XCTAssertNil(engine.archive)
        XCTAssertFalse(engine.handlesArchive(kind: "jar"))
    }

    func testExtendsInheritsArchiveSupport() {
        let ini = "[cfr-quiet]\nextends = cfr\nargs = -jar {engine} --silent {input}\n"
        let engine = PluginDecompilerRegistry.parse(ini, engineDirectory: root).engines[0]
        // The profile changed only the single-class line; whole JARs must keep working.
        XCTAssertEqual(engine.archive?.args.contains("{outdir}"), true)
    }

    // MARK: Cache

    func testArchiveAndSingleFileResultsDoNotShareACacheEntry() throws {
        let file = (root as NSString).appendingPathComponent("x.jar")
        try "content".write(toFile: file, atomically: true, encoding: .utf8)
        let cfr = PluginDecompilerEngine.builtIns(engineDirectory: root).first { $0.id == "cfr" }!
        let single = PluginDecompilerCache.key(path: file, engine: cfr)
        let tree = PluginDecompilerCache.treeDirectory(path: file, engine: cfr, configRoot: root)
        XCTAssertNotNil(single)
        XCTAssertNotNil(tree)
        XCTAssertFalse(tree!.hasSuffix(single!), "the same engine's two invocations are two results")
    }

    func testAnUnfinishedResultIsNotServedFromCache() throws {
        let dir = (root as NSString).appendingPathComponent("tree-abc")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "class A {}".write(toFile: (dir as NSString).appendingPathComponent("A.java"),
                               atomically: true, encoding: .utf8)
        // Files are present, but the run never finished — a timeout leaves exactly this state, and
        // treating it as complete would hide classes for as long as the entry lives.
        XCTAssertFalse(PluginDecompilerCache.treeIsComplete(dir))
        PluginDecompilerCache.markTreeComplete(dir, configRoot: root)
        XCTAssertTrue(PluginDecompilerCache.treeIsComplete(dir))
    }

    // MARK: The runner, end to end

    func testRunArchiveCollectsWhatTheEngineWroteAndRefusesWhatItCannot() throws {
        // A script standing in for a decompiler: it writes a small tree into {outdir}, which is all
        // the runner requires of an engine. Real engines cannot be a test dependency — none is
        // bundled, by design.
        let script = (root as NSString).appendingPathComponent("fake.sh")
        try """
        #!/bin/sh
        out="$2"
        mkdir -p "$out/com/example"
        printf 'class A { String s = "hello"; }\\n' > "$out/com/example/A.java"
        printf 'class B {}\\n' > "$out/com/example/B.java"
        printf 'ignored\\n' > "$out/notes.log"
        """.write(toFile: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script)
        let engine = PluginDecompilerEngine(
            id: "fake", name: "Fake", kinds: ["jar"], tool: script,
            args: ["{input}"], enginePath: nil, output: .directory, note: nil, timeout: 5,
            archive: PluginDecompilerArchiveSupport(args: ["{input}", "{outdir}"], timeout: 30))
        let out = (root as NSString).appendingPathComponent("result")
        let result = PluginDecompilerRunner.runArchive(engine, input: "/dev/null", outputDirectory: out)
        XCTAssertEqual(try result.get(), ["com/example/A.java", "com/example/B.java"])
        XCTAssertEqual(PluginDecompilerRunner.readSource("com/example/A.java", from: out),
                       "class A { String s = \"hello\"; }\n")

        // An engine that never described an archive mode must be refused rather than run with the
        // single-file arguments.
        let single = PluginDecompilerEngine(
            id: "single", name: "Single", kinds: ["jar"], tool: script, args: ["{input}"],
            enginePath: nil, output: .stdout, note: nil, timeout: 5, archive: nil)
        if case .success = PluginDecompilerRunner.runArchive(single, input: "/dev/null",
                                                            outputDirectory: out) {
            XCTFail("an engine without archive support must not be run over an archive")
        }
    }
}

extension PluginDecompilerArchiveTests {
    func testTheFirstClassOpenedIsTheShallowestOne() {
        // util/ sorts before the classes because packages come first, so a depth-first search would
        // return Helper.java and the view would have to expand a package to show it.
        let nodes = PluginDecompilerNode.tree(from: ["com/Alpha.java", "com/util/Helper.java"])
        XCTAssertEqual(PluginDecompilerNode.shallowestLeaf(in: nodes)?.relativePath, "com/Alpha.java")
    }

    func testShallowestLeafDescendsWhenItHasTo() {
        let nodes = PluginDecompilerNode.tree(from: ["com/example/deep/Only.java"])
        XCTAssertEqual(PluginDecompilerNode.shallowestLeaf(in: nodes)?.relativePath,
                       "com/example/deep/Only.java")
    }

    func testShallowestLeafOfNothingIsNothing() {
        XCTAssertNil(PluginDecompilerNode.shallowestLeaf(in: []))
    }
}

// MARK: - Options (F-352)

extension PluginDecompilerArchiveTests {
    func testOptionsDefaultToWorkingWithoutAFile() {
        // No options.ini yet is the normal first run: everything must be on, or the plugin would ship
        // switched off by its own configuration.
        let options = PluginDecompilerOptions.read(configRoot: root)
        XCTAssertTrue(options.claimArchives)
        XCTAssertTrue(options.allowSearchDecompile)
        XCTAssertEqual(options.classTimeout, 0)
        XCTAssertEqual(options.cacheMaxAgeDays, 30)
    }

    func testOptionsSurviveAWriteAndRead() {
        var written = PluginDecompilerOptions()
        // One flag left ON deliberately: the first version of this test set both to false and passed
        // while the parser was reading every written value as unparsable — "1" plus the inline comment
        // the writer emits came back as false, so "off" was the only answer it could ever give.
        written.claimArchives = true
        written.allowSearchDecompile = false
        written.classTimeout = 45
        written.archiveTimeout = 600
        written.cacheMaxAgeDays = 7
        written.write(configRoot: root)
        XCTAssertEqual(PluginDecompilerOptions.read(configRoot: root), written)
    }

    func testAMangledLineCostsOnlyItsOwnSetting() throws {
        let path = PluginDecompilerOptions.file(configRoot: root)
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                               withIntermediateDirectories: true)
        try "[Options]\nClaimArchives = 0\nClassTimeout = not-a-number\n"
            .write(toFile: path, atomically: true, encoding: .utf8)
        let options = PluginDecompilerOptions.read(configRoot: root)
        XCTAssertFalse(options.claimArchives, "the readable setting must still apply")
        XCTAssertEqual(options.classTimeout, 0, "the unreadable one falls back to the default")
    }

    func testConfiguredTimeoutsReachEveryEngine() throws {
        var options = PluginDecompilerOptions()
        options.classTimeout = 11
        options.archiveTimeout = 222
        options.write(configRoot: root)
        // Through the registry, because that is the only way a consumer gets an engine — a timeout
        // honoured on one path and not another is the bug this arrangement exists to prevent.
        let registry = PluginDecompilerRegistry(configRoot: root)
        for engine in registry.engines {
            XCTAssertEqual(engine.timeout, 11, engine.id)
            if let archive = engine.archive { XCTAssertEqual(archive.timeout, 222, engine.id) }
        }
    }

    func testZeroMeansTheEngineKeepsItsOwnTimeout() {
        let registry = PluginDecompilerRegistry(configRoot: root)   // no options.ini
        let jadx = registry.engines.first { $0.id == "jadx" }!
        XCTAssertEqual(jadx.timeout, 120, "jadx sets its own 120 s; 0 must not overwrite it with 0")
    }

    func testClearingAPreferenceIsNotThesameAsPickingTheFirst() {
        PluginDecompilerPreference.set(engine: "procyon", forKind: "class", configRoot: root)
        XCTAssertEqual(PluginDecompilerPreference.read(configRoot: root)["class"], "procyon")
        PluginDecompilerPreference.clear(forKind: "class", configRoot: root)
        XCTAssertNil(PluginDecompilerPreference.read(configRoot: root)["class"],
                     "\"first available\" must leave no id behind, or a better engine installed later "
                     + "would never be chosen")
    }
}

extension PluginDecompilerArchiveTests {
    func testResultDirectoriesAreNamedAfterTheirInput() throws {
        let file = (root as NSString).appendingPathComponent("my demo.jar")
        try "x".write(toFile: file, atomically: true, encoding: .utf8)
        let cfr = PluginDecompilerEngine.builtIns(engineDirectory: root).first { $0.id == "cfr" }!
        let dir = PluginDecompilerCache.treeDirectory(path: file, engine: cfr, configRoot: root)!
        let name = (dir as NSString).lastPathComponent
        // The name is what a panel tab shows, so the archive has to be recognisable in it — and the
        // space must not survive as one, since this becomes a single path component.
        XCTAssertTrue(name.hasPrefix("my_demo.jar-"), name)
        XCTAssertFalse(name.contains(" "), name)
    }

    func testTwoArchivesWithTheSameNameKeepSeparateResults() throws {
        let a = (root as NSString).appendingPathComponent("a/lib.jar")
        let b = (root as NSString).appendingPathComponent("b/lib.jar")
        for path in [a, b] {
            try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                   withIntermediateDirectories: true)
            try path.write(toFile: path, atomically: true, encoding: .utf8)   // different contents
        }
        let cfr = PluginDecompilerEngine.builtIns(engineDirectory: root).first { $0.id == "cfr" }!
        XCTAssertNotEqual(PluginDecompilerCache.treeDirectory(path: a, engine: cfr, configRoot: root),
                          PluginDecompilerCache.treeDirectory(path: b, engine: cfr, configRoot: root),
                          "the readable prefix must not cost the hash its job")
    }
}

// MARK: - Managed vs native binaries (F-353)

/// The check the detect string cannot make. Fixtures are built byte by byte rather than shipped:
/// a real assembly would be a binary blob in the repo whose relevance nobody could see.
final class PluginDecompilerFormatTests: XCTestCase {
    private var dir = ""

    override func setUpWithError() throws {
        dir = (NSTemporaryDirectory() as NSString).appendingPathComponent("pc-pe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(atPath: dir) }

    /// A minimal PE. `cliSize` of 0 is a native image; anything else is managed.
    private func writePE(_ name: String, magic: UInt16 = 0x10B, cliRVA: UInt32 = 0x2000,
                         cliSize: UInt32, peOffset: UInt32 = 0x80) throws -> String {
        var bytes = [UInt8](repeating: 0, count: 1024)
        bytes[0] = 0x4D; bytes[1] = 0x5A                       // "MZ"
        func put32(_ value: UInt32, at i: Int) {
            bytes[i] = UInt8(value & 0xFF); bytes[i + 1] = UInt8((value >> 8) & 0xFF)
            bytes[i + 2] = UInt8((value >> 16) & 0xFF); bytes[i + 3] = UInt8((value >> 24) & 0xFF)
        }
        put32(peOffset, at: 0x3C)
        let pe = Int(peOffset)
        // An offset that points past the file is a case worth testing, so the *fixture* must tolerate
        // it rather than crash writing one: only fill in what fits.
        let directories = pe + 24 + (magic == 0x10B ? 96 : 112)
        if directories + 14 * 8 + 8 <= bytes.count {
            bytes[pe] = 0x50; bytes[pe + 1] = 0x45             // "PE\0\0"
            bytes[pe + 24] = UInt8(magic & 0xFF); bytes[pe + 25] = UInt8(magic >> 8)
            put32(cliRVA, at: directories + 14 * 8)
            put32(cliSize, at: directories + 14 * 8 + 4)
        }
        let path = (dir as NSString).appendingPathComponent(name)
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        return path
    }

    func testAManagedAssemblyIsRecognised() throws {
        XCTAssertTrue(PluginDecompilerFormats.isManagedAssembly(try writePE("managed.dll", cliSize: 72)))
    }

    func testPE32PlusIsRecognisedToo() throws {
        // 64-bit images put the data directories 16 bytes further in; reading the wrong offset would
        // make every modern assembly look native.
        XCTAssertTrue(PluginDecompilerFormats.isManagedAssembly(
            try writePE("managed64.dll", magic: 0x20B, cliSize: 72)))
    }

    func testANativeLibraryIsNotClaimed() throws {
        // The whole reason this exists: same extension, same MZ, no CLI header.
        XCTAssertFalse(PluginDecompilerFormats.isManagedAssembly(try writePE("native.dll", cliSize: 0)))
    }

    func testARubbishFileIsNotClaimed() throws {
        let path = (dir as NSString).appendingPathComponent("notes.dll")
        try "this is not a PE at all".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertFalse(PluginDecompilerFormats.isManagedAssembly(path))
    }

    func testAMissingFileIsNotClaimed() {
        XCTAssertFalse(PluginDecompilerFormats.isManagedAssembly(
            (dir as NSString).appendingPathComponent("absent.dll")))
    }

    func testAnOutOfRangePEOffsetIsRejectedRatherThanCrashing() throws {
        // A truncated or hostile file must be answered, not read past its end.
        XCTAssertFalse(PluginDecompilerFormats.isManagedAssembly(
            try writePE("bad.dll", cliSize: 72, peOffset: 0xFFFF)))
    }

    func testTheCSharpTableCoversBothCSharpAndIL() {
        XCTAssertTrue(PluginSyntaxLanguage.csharp.keywords.contains("namespace"))
        XCTAssertTrue(PluginSyntaxLanguage.csharp.keywords.contains("callvirt"),
                      "monodis output is not C#; leaving IL unhighlighted looks like a broken highlighter")
        // `@name` is a verbatim identifier in C#, not an attribute — colouring it as one would light
        // up ordinary variables.
        XCTAssertNil(PluginSyntaxLanguage.csharp.annotationPrefix)
    }
}

extension PluginDecompilerFormatTests {
    func testTheDotNetProfileTreatsAnAssemblyAsManyTypes() {
        let net = PluginDecompilerProfile.dotNet
        // One .dll holds many types, so it takes the same path a JAR does rather than the single-class
        // one — the reason `treeKinds` is about result shape and not about containers.
        XCTAssertTrue(net.isTree(kind: "dll"))
        XCTAssertTrue(net.handles(kind: "exe"))
        XCTAssertFalse(net.handles(kind: "class"), "that is the other plugin's format")
    }

    func testTheTwoProfilesShareNoFormats() {
        let java = PluginDecompilerProfile.java, net = PluginDecompilerProfile.dotNet
        let all: (PluginDecompilerProfile) -> Set<String> = { $0.singleKinds.union($0.treeKinds) }
        XCTAssertTrue(all(java).isDisjoint(with: all(net)),
                      "two installed decompiler plugins must not both claim a file for F3")
    }

    func testEveryDotNetKindHasAnEngine() {
        let registry = PluginDecompilerRegistry(configRoot: dir, profile: "net")
        for kind in PluginDecompilerProfile.dotNet.treeKinds {
            XCTAssertFalse(registry.engines(for: kind).isEmpty, "no engine describes .\(kind)")
        }
        // ILSpy can do a whole assembly; monodis answers with one listing and says so by having no
        // archive support. Both are legitimate, and the view picks by what is installed.
        XCTAssertTrue(registry.archiveEngines(for: "dll").contains { $0.id == "ilspy" })
        XCTAssertFalse(registry.archiveEngines(for: "dll").contains { $0.id == "monodis" })
    }

    func testTheDotNetBytecodeMarkersMatchWhatMonodisPrints() {
        let net = PluginDecompilerProfile.dotNet
        XCTAssertTrue(net.isBytecodeListing(".assembly extern mscorlib\n{\n}\n"),
                      "an IL listing must not be saved as .cs")
        XCTAssertFalse(net.isBytecodeListing("namespace Demo;\npublic class Greeter { }\n"))
    }
}

extension PluginDecompilerFormatTests {
    func testEachProfileCountsItsOwnPlatformsResults() {
        // The bug this pins: ILSpy wrote .cs files and the shared, Java-shaped whitelist counted none,
        // so a successful run was reported as "produced no output".
        XCTAssertTrue(PluginDecompilerProfile.dotNet.resultExtensions.contains("cs"))
        XCTAssertTrue(PluginDecompilerProfile.java.resultExtensions.contains("java"))
        for profile in [PluginDecompilerProfile.java, .dotNet] {
            XCTAssertFalse(profile.resultExtensions.isEmpty, profile.id)
            XCTAssertTrue(profile.resultExtensions.isSubset(of: PluginDecompilerRunner.sourceExtensions),
                          "\(profile.id): the runner's default must cover every profile, or a caller "
                          + "without a profile would silently drop that platform's files")
        }
    }
}
