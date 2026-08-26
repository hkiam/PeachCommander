// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

#if canImport(FoundationModels)

private struct FixedBroker: ConfirmationBroker {
    let ok: Bool
    func confirmPlan(_ plan: String) async -> Bool { ok }
}

// Class is NOT @available-gated (that would hide it from test discovery); each method
// guards on macOS 26 and skips otherwise. The native tools reuse AutomationCore, so the
// permission model still applies — the first three tests verify that deterministically
// (no model); the last verifies reliability live.
final class NativeToolContextTests: XCTestCase {

    // What is left of this file after the on-device chat was retired: the tool context still
    // executes reads for the direct actions, and the policy still decides what may run. The turn
    // loop, the tool set and the compaction that the rest of this file exercised are gone with the
    // chat they belonged to — their behaviour is covered where it now lives, in
    // LiveDirectActionTests.

    func test_readRunsImmediately() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let bridge = FakeBridge()
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: bridge),
                                    policy: .standard, broker: FixedBroker(ok: false), onProgress: nil)
        let out = await ctx.runRaw("list_directory", ["path": "/a"])
        XCTAssertFalse(out.hasPrefix("Failed"))
        XCTAssertFalse(out.hasPrefix("Refused"))
        let listed = await bridge.listed
        XCTAssertEqual(listed, "/a")
    }

    func test_gatedWrite_declined_isNotExecuted() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let bridge = FakeBridge()
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: bridge),
                                    policy: .standard, broker: FixedBroker(ok: false), onProgress: nil)
        let out = await ctx.runRaw("copy", ["sources": ["/a/f.txt"], "destination": "/b"])
        XCTAssertTrue(out.lowercased().contains("declined"), "got: \(out)")
        let copied = await bridge.copied
        XCTAssertNil(copied, "declined write must not execute")
    }

    func test_gatedWrite_confirmed_isExecuted() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let bridge = FakeBridge()
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: bridge),
                                    policy: .standard, broker: FixedBroker(ok: true), onProgress: nil)
        _ = await ctx.runRaw("copy", ["sources": ["/a/f.txt"], "destination": "/b"])
        let copied = await bridge.copied
        XCTAssertEqual(copied?.dest, "/b", "confirmed write must execute via the core")
    }

    func test_readOnlyPolicy_refusesWrite_evenIfBrokerWouldConfirm() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let bridge = FakeBridge()
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: bridge),
                                    policy: .readOnly, broker: FixedBroker(ok: true), onProgress: nil)
        let out = await ctx.runRaw("copy", ["sources": ["/a/f.txt"], "destination": "/b"])
        XCTAssertTrue(out.hasPrefix("Refused"), "got: \(out)")
        let copied = await bridge.copied
        XCTAssertNil(copied, "a read-only policy must refuse before the broker is asked")
    }
}
#endif
