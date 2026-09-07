// SPDX-License-Identifier: Apache-2.0
// PluginPackage.swift - The `.pcplug` plugin package type (F-482).
//
// A plugin package is a zip archive with its own extension — the same trick `.docx`, `.jar` and
// `.ipa` play, and the reason it is the right one here is that the host already knew how to
// unpack a plugin `.zip`, including the TC-style `pluginst.inf` inside it. Nothing about the
// format is new; what is new is that the file now says what it is, so double-clicking it can
// mean something.
//
// The type is *exported*, not imported: this app defines it. It conforms to
// `public.zip-archive`, so anything that can open a zip still can, and Peach Commander is only
// the preferred opener (`LSHandlerRank: Owner` in Info.plist).
//
// Layout inside the package:
//
//     Something.pcplug              (zip)
//     ├── pluginst.inf              [plugininstall] type=pcx  file=Something.pcxplugin  description=…
//     └── Something.pcxplugin/
//         └── Contents/{Info.plist, MacOS/Something, Resources/}

import Foundation
import UniformTypeIdentifiers

enum PluginPackage {
    static let fileExtension = "pcplug"
    static let identifier = "com.peachcommander.plugin-package"

    /// The exported type. Falls back to a synthesised type when Launch Services has not yet seen
    /// our Info.plist — which is the normal state for a freshly built app that has never run.
    static var contentType: UTType {
        UTType(identifier) ?? UTType(exportedAs: identifier, conformingTo: .zip)
    }

    /// Whether `url` names a plugin package, by extension alone.
    ///
    /// By name rather than by content on purpose: this is asked on the panel's Enter path, once
    /// per keypress, and a `.pcplug` that is not a zip fails loudly a moment later in the
    /// installer — where there is a person to tell.
    static func isPackage(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == fileExtension
    }

    static func isPackage(name: String) -> Bool {
        (name as NSString).pathExtension.lowercased() == fileExtension
    }
}
