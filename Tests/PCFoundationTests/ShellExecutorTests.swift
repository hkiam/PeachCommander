import XCTest
@testable import PCFoundation

final class ShellExecutorTests: XCTestCase {
    private var tempDirectory: String = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        let unique = "ShellExecutorTests-\(UUID().uuidString)"
        tempDirectory = (NSTemporaryDirectory() as NSString).appendingPathComponent(unique)
        try FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: tempDirectory)
        try super.tearDownWithError()
    }

    private var testEnvironment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = env["HOME"] ?? NSHomeDirectory()
        return env
    }

    func testEchoProducesOutputAndZeroExit() async {
        let result = await ShellExecutor.run("echo hello", workingDirectory: tempDirectory, environment: testEnvironment)
        XCTAssertEqual(result.output, "hello")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNil(result.changedDirectory)
    }

    func testFailingCommandReturnsNonZeroExit() async {
        let result = await ShellExecutor.run("exit 3", workingDirectory: tempDirectory, environment: testEnvironment)
        XCTAssertEqual(result.exitCode, 3)
        XCTAssertNil(result.changedDirectory)
    }

    func testUnknownCommandReturnsNonZeroExit() async {
        let result = await ShellExecutor.run(
            "definitely_not_a_real_command_xyz",
            workingDirectory: tempDirectory,
            environment: testEnvironment
        )
        XCTAssertNotEqual(result.exitCode, 0)
    }

    func testPwdReflectsWorkingDirectory() async {
        let result = await ShellExecutor.run("pwd", workingDirectory: tempDirectory, environment: testEnvironment)
        XCTAssertEqual(result.exitCode, 0)
        let standardizedTemp = (tempDirectory as NSString).standardizingPath
        let standardizedOutput = (result.output as NSString).standardizingPath
        XCTAssertEqual(standardizedOutput, standardizedTemp)
    }

    func testCdAbsoluteExistingDirectory() async {
        let subdirectory = (tempDirectory as NSString).appendingPathComponent("subdir")
        try? FileManager.default.createDirectory(atPath: subdirectory, withIntermediateDirectories: true)

        let result = await ShellExecutor.run(
            "cd \(subdirectory)",
            workingDirectory: tempDirectory,
            environment: testEnvironment
        )
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.changedDirectory, subdirectory)
    }

    func testCdRelativeResolvesAgainstWorkingDirectory() async {
        let subdirectory = (tempDirectory as NSString).appendingPathComponent("subdir")
        try? FileManager.default.createDirectory(atPath: subdirectory, withIntermediateDirectories: true)

        let result = await ShellExecutor.run(
            "cd subdir",
            workingDirectory: tempDirectory,
            environment: testEnvironment
        )
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.changedDirectory, subdirectory)
    }

    func testCdDotDotGoesUp() async {
        let subdirectory = (tempDirectory as NSString).appendingPathComponent("subdir")
        try? FileManager.default.createDirectory(atPath: subdirectory, withIntermediateDirectories: true)

        let result = await ShellExecutor.run(
            "cd ..",
            workingDirectory: subdirectory,
            environment: testEnvironment
        )
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.changedDirectory, (tempDirectory as NSString).standardizingPath)
    }

    func testCdTildeGoesHome() async {
        let home = testEnvironment["HOME"] ?? NSHomeDirectory()
        let result = await ShellExecutor.run("cd ~", workingDirectory: tempDirectory, environment: testEnvironment)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.changedDirectory, home)
    }

    func testBareCdGoesHome() async {
        let home = testEnvironment["HOME"] ?? NSHomeDirectory()
        let result = await ShellExecutor.run("cd", workingDirectory: tempDirectory, environment: testEnvironment)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.changedDirectory, home)
    }

    func testCdNonexistentReturnsErrorExitCode() async {
        let missing = (tempDirectory as NSString).appendingPathComponent("does-not-exist")
        let result = await ShellExecutor.run(
            "cd \(missing)",
            workingDirectory: tempDirectory,
            environment: testEnvironment
        )
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNil(result.changedDirectory)
        XCTAssertFalse(result.output.isEmpty)
    }

    func testResolveCdTargetForNonCdLineReturnsNil() {
        let target = ShellExecutor.resolveCdTarget(
            "echo cd something",
            workingDirectory: tempDirectory,
            environment: testEnvironment
        )
        XCTAssertNil(target)
    }

    func testHomeVariableExpansionInCd() {
        var env = testEnvironment
        env["HOME"] = "/Users/testuser"
        let target = ShellExecutor.resolveCdTarget(
            "cd $HOME/Documents",
            workingDirectory: tempDirectory,
            environment: env
        )
        XCTAssertEqual(target, "/Users/testuser/Documents")
    }

    func testCustomVariableExpansionInCd() {
        var env = testEnvironment
        env["MY_DIR"] = tempDirectory
        let target = ShellExecutor.resolveCdTarget(
            "cd ${MY_DIR}",
            workingDirectory: "/some/other/dir",
            environment: env
        )
        XCTAssertEqual(target, tempDirectory)
    }
}
