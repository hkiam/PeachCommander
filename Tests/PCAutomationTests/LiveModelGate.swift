// SPDX-License-Identifier: Apache-2.0
// LiveModelGate.swift - the one place that decides whether tests may call the real on-device model.
//
// `AppleFoundationModelsProviderTests` reached this conclusion first, and its reasoning applies
// word for word to the other two files: these call Apple's on-device model for real, so their
// outcome depends on what the model generates. One of them failed a run with "Exceeded model
// context window size" — the loop had simply accumulated more context that time. A default suite
// whose result depends on token usage is not a usable signal.
//
// Only that file had the gate. `LiveNativeToolTests` and `LiveRealFolderTests` checked availability
// alone, so on any Mac with Apple Intelligence switched on they ran in every suite: six tests,
// 274 seconds of a 604-second run, and a result that changed between runs — one of them reported
// passed, skipped, passed on three consecutive full runs. CI never saw any of it, because the
// runners have no on-device model, so the cost fell entirely on whoever was working.
//
// They are still here and still run: PC_AI_LIVE=1.

import Foundation
import XCTest

enum LiveModel {
    /// Throws `XCTSkip` unless the run asked for the real model.
    ///
    /// Call before probing availability, not after: a machine with the model would otherwise pay
    /// for the probe on every one of these tests in every run.
    static func requireEnabled() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PC_AI_LIVE"] == "1",
                          "set PC_AI_LIVE=1 to run tests against the real on-device model")
    }
}
