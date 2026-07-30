// swift-tools-version:5.9
// PeachCommanderPluginSDK — a distributable SwiftPM package that vends the
// Peach Commander plugin C ABI (PCX packers, PDX detectors, PFX file systems,
// PLX listers, and the shared `contrib` command/view ABI). External plugin
// authors depend on this package and `import CPeachCommanderPlugin` to get the
// C declarations, then build their bundle against the documented entry points
// (see PORTING.md). The headers mirror the in-repo canonical copies under
// Plugins/SDK/ — regenerate with Tools/sync-plugin-sdk.sh.
import PackageDescription

let package = Package(
    name: "PeachCommanderPluginSDK",
    products: [
        .library(name: "CPeachCommanderPlugin", targets: ["CPeachCommanderPlugin"]),
    ],
    targets: [
        .target(
            name: "CPeachCommanderPlugin",
            publicHeadersPath: "include"
        ),
    ]
)
