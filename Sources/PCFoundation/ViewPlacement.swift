// SPDX-License-Identifier: Apache-2.0
// ViewPlacement.swift - Where a plugin view sits, when the user disagrees with its manifest (F-381).
//
// A view contribution names its container in the plugin's `Info.plist`, and until there was more than
// one container that was the end of it. It is the wrong model as soon as there are two: where a panel
// belongs is a matter of taste and screen shape, and a plugin author knows neither. So the manifest
// declares the *default*, the user may move it, and resetting deletes the override rather than writing
// a different one — which is the only definition of "default" that stays true when plugins come and
// go, or when a plugin changes its own mind in an update.
//
// Two rules, both of which exist because of what happens when they are missing.
//
// **An override naming a container that is not registered is ignored, not honoured.** Containers come
// and go with the window's furniture and an override outlives the thing it names. Honouring it would
// mount the view nowhere, so it would vanish — for a reason the user cannot see, from a preference
// they may have set months ago. Falling back to the declared container keeps it on screen.
//
// **An override equal to the declared container is not an override.** Dragging a view out and back
// again must leave no trace, or "reset to default" quietly stops meaning what it says the moment a
// plugin update changes its own default.
//
// The key is the *view id*, not the plugin. A plugin's identity in the running host is the path its
// bundle was loaded from, which changes when the app moves and differs between a development build and
// an installed one — useless in a preferences file. View ids are namespaced by convention
// (`plugin.notes.sidebar`, `plugin.sysmon.titlebar`) and are what the manifest actually promises to
// keep stable.

import Foundation

public enum ViewPlacement {

    /// The INI section the overrides live in. A section of their own rather than prefixed keys, so
    /// "forget every placement" is "empty this section" and cannot take a neighbouring setting with it.
    public static let section = "ViewPlacement"

    /// Where a view should actually be mounted.
    ///
    /// - Parameters:
    ///   - declared: the container the plugin's manifest names.
    ///   - override: what the user chose, if anything.
    ///   - registered: the containers the window currently offers.
    public static func container(declared: String,
                                 override: String?,
                                 registered: Set<String>) -> String {
        guard let override, override != declared, registered.contains(override) else { return declared }
        return override
    }

    /// Drop overrides that no longer say anything: ones matching the declared container, and ones
    /// naming a container that does not exist.
    ///
    /// Used when writing the preferences back, so the file does not accumulate entries that have no
    /// effect and that a later reading would have to keep explaining away.
    public static func pruned(_ overrides: [String: String],
                              declared: [String: String],
                              registered: Set<String>) -> [String: String] {
        overrides.filter { viewId, container in
            guard registered.contains(container) else { return false }
            // A view whose contribution is not currently loaded keeps its override: its plugin may
            // merely be switched off, and forgetting where the user put it is not a tidy-up.
            guard let declaredContainer = declared[viewId] else { return true }
            return container != declaredContainer
        }
    }
}
