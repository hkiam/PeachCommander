// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

final class PlaceholderModelProviderTests: XCTestCase {
    func test_echoesUserMessage_andIsAvailable() async throws {
        let p = PlaceholderModelProvider()
        let available = await p.isAvailable
        XCTAssertTrue(available)
        let reply = try await p.respond(
            messages: [ModelMessage(role: .user, content: "organize my downloads")],
            tools: AutomationCatalog.tools)
        guard case .text(let t) = reply else { return XCTFail("expected text") }
        XCTAssertTrue(t.contains("organize my downloads"))
    }
}
