// SPDX-License-Identifier: Apache-2.0
// AutomationProbe.swift — where a headless answer to a modal dialog comes from (F-478).
//
// Every modal in this app that an automation run has to get past is gated on a named value:
// `PC_MACRO_CONFIRM_DUMP`, `PC_MACRO_ASK`, `PC_AI_DIRECT_APPLY` and their kin. Without one the script
// runs on inside the modal's nested runloop and `quit` never lands — the run does not fail, it hangs.
//
// **Two sources, because one of them cannot be reached from the VM.** The harness launches the app
// with `open`, so that it lands in the auto-logged-in Aqua session and has a real window to
// photograph; `open` hands the app *arguments* and never the caller's environment. `launchctl setenv`
// from the ssh session does not help either: an ssh session has its own launchd domain, and
// `launchctl getenv` in the guest came back empty while the same variable worked perfectly when the
// binary was run directly. Measured, after a full VM run reported four empty reports.
//
// So a probe value is read from the environment *or* from the argument domain, which is where
// `-PC_MACRO_CONFIRM_DUMP <path>` after `--args` lands — the same channel `-ConfigRoot` uses, and the
// one the crash-watermark override already relies on. The environment stays first so a local run,
// where it is the natural spelling, behaves exactly as before.

import Foundation

enum AutomationProbe {

    /// The value of a probe setting, from the environment or from the argument domain.
    static func value(_ name: String) -> String? {
        if let fromEnvironment = ProcessInfo.processInfo.environment[name], !fromEnvironment.isEmpty {
            return fromEnvironment
        }
        // `UserDefaults` sees `-name value` from the command line as the argument domain. Empty is
        // treated as absent, so `-PC_MACRO_ASK ""` cannot switch a probe on by accident.
        guard let fromArguments = UserDefaults.standard.string(forKey: name),
              !fromArguments.isEmpty else { return nil }
        return fromArguments
    }

    /// Whether a flag-shaped probe is on. `"0"` is off, so a scenario can turn one off explicitly.
    static func isOn(_ name: String) -> Bool {
        guard let raw = value(name) else { return false }
        return raw != "0"
    }
}
