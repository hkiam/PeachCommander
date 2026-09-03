// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class NetworkShareTests: XCTestCase {
    private func s(_ input: String) -> String? { NetworkShare.url(from: input)?.absoluteString }

    func testUNCPath() {
        XCTAssertEqual(s(#"\\server\share\dir"#), "smb://server/share/dir")
        XCTAssertEqual(s(#"\\nas\pub"#), "smb://nas/pub")
    }

    func testDoubleSlash() {
        XCTAssertEqual(s("//server/share"), "smb://server/share")
    }

    func testBareServerShare() {
        XCTAssertEqual(s("server/share"), "smb://server/share")
    }

    func testExplicitSchemesPreserved() {
        XCTAssertEqual(s("smb://user@server/share"), "smb://user@server/share")
        XCTAssertEqual(s("afp://server/vol"), "afp://server/vol")
        XCTAssertEqual(NetworkShare.url(from: "afp://server/vol")?.scheme, "afp")
    }

    func testHost() {
        XCTAssertEqual(NetworkShare.url(from: #"\\nas\pub"#)?.host, "nas")
    }

    func testInvalid() {
        XCTAssertNil(NetworkShare.url(from: ""))
        XCTAssertNil(NetworkShare.url(from: "   "))
        XCTAssertNil(NetworkShare.url(from: "http://example.com"))   // not a share scheme
        XCTAssertNil(NetworkShare.url(from: "smb://"))               // no host
    }

    /// A server on its own is a mount target: macOS then asks which share.
    func testServerWithoutShare() {
        XCTAssertEqual(s("smb://srv"), "smb://srv")
        XCTAssertEqual(NetworkShare.location(from: "smb://srv")?.share, "")
    }

    func testTrailingSeparatorAndQuotesFromAPaste() {
        // How Explorer copies a folder, and how a path survives a mail with a space in it.
        XCTAssertEqual(s(#"\\nas\pub\dir\"#), "smb://nas/pub/dir")
        XCTAssertEqual(s(#""\\nas\pub\dir""#), "smb://nas/pub/dir")
        XCTAssertEqual(s("  " + #"\\nas\pub"# + "  "), "smb://nas/pub")
    }

    func testDomainAndUserPrefix() {
        let loc = NetworkShare.location(from: #"\\PDV;maik1@srv-ablage.pdv.lan\ablage\dir"#)
        XCTAssertEqual(loc?.host, "srv-ablage.pdv.lan")     // matched against the mount table
        XCTAssertEqual(loc?.authority, "PDV;maik1@srv-ablage.pdv.lan")   // macOS pre-fills the login
        XCTAssertEqual(loc?.share, "ablage")
        XCTAssertEqual(loc?.subpath, ["dir"])
    }

    func testSpacesAndUmlautsArePercentEncoded() {
        XCTAssertEqual(s(#"\\srv\ablage\Büro Pläne"#),
                       "smb://srv/ablage/B%C3%BCro%20Pl%C3%A4ne")
    }

    // MARK: - isNetworkLocation

    /// A bare `server/share` must NOT count: it is spelled exactly like a relative folder, and a
    /// path field has to keep reading it as one.
    func testIsNetworkLocation() {
        XCTAssertTrue(NetworkShare.isNetworkLocation(#"\\srv\ablage"#))
        XCTAssertTrue(NetworkShare.isNetworkLocation("//srv/ablage"))
        XCTAssertTrue(NetworkShare.isNetworkLocation("smb://srv/ablage"))
        XCTAssertTrue(NetworkShare.isNetworkLocation("AFP://srv/vol"))
        XCTAssertFalse(NetworkShare.isNetworkLocation("server/share"))
        XCTAssertFalse(NetworkShare.isNetworkLocation("/Volumes/ablage"))
        XCTAssertFalse(NetworkShare.isNetworkLocation("~/Documents"))
        XCTAssertFalse(NetworkShare.isNetworkLocation("http://example.com/x"))
        XCTAssertFalse(NetworkShare.isNetworkLocation(""))
    }

    // MARK: - Where is it mounted?

    /// The table this machine will not have: an already-mounted share whose mount point is NOT
    /// "/Volumes/<share>" — macOS appends "-1" when the same name is taken, which is exactly the
    /// case the old guess got wrong.
    private let mounts = [
        NetworkShare.MountEntry(from: "/dev/disk3s1s1", mountPoint: "/"),
        NetworkShare.MountEntry(from: "//PDV;maik1@srv-ablage.pdv.lan/ablage",
                                mountPoint: "/Volumes/ablage-1"),
        NetworkShare.MountEntry(from: "//guest@nas/pub", mountPoint: "/Volumes/pub"),
    ]

    private func mounted(_ input: String) -> String? {
        guard let loc = NetworkShare.location(from: input) else { return nil }
        return NetworkShare.mountedPath(for: loc, in: mounts)
    }

    func testMountedPathFindsTheShareAndAppendsTheSubpath() {
        XCTAssertEqual(mounted(#"\\srv-ablage.pdv.lan\ablage\PDV_Gemeinsam\Transfer"#),
                       "/Volumes/ablage-1/PDV_Gemeinsam/Transfer")
        XCTAssertEqual(mounted(#"\\srv-ablage.pdv.lan\ablage"#), "/Volumes/ablage-1")
        XCTAssertEqual(mounted(#"\\nas\pub\x"#), "/Volumes/pub/x")
    }

    /// Share names are case-insensitive on SMB, and the same server may be typed short where it
    /// was mounted by FQDN. Missing either would raise a connect dialog for an open mount.
    func testMountedPathMatchesCaseAndShortHostname() {
        XCTAssertEqual(mounted(#"\\SRV-ABLAGE\Ablage\PDV_Gemeinsam"#),
                       "/Volumes/ablage-1/PDV_Gemeinsam")
        XCTAssertEqual(mounted("smb://srv-ablage/ablage"), "/Volumes/ablage-1")
    }

    func testMountedPathDeclinesWhatIsNotMounted() {
        XCTAssertNil(mounted(#"\\other\ablage"#))            // different server
        XCTAssertNil(mounted(#"\\srv-ablage.pdv.lan\other"#))  // different share
        XCTAssertNil(mounted("smb://srv-ablage.pdv.lan"))     // no share to map
        XCTAssertNil(mounted("//srv-ablagex/ablage"))         // not a prefix match
    }

    /// A share can appear in the table more than once, at different depths: macOS mounts a
    /// *subdirectory* as a volume of its own, which is what Finder produced for a URL with a path.
    /// The measured row was `//maik1@srv-ablage.pdv.lan/ablage/PDV_Gemeinsam/Transfer/NKR/ai-fun/
    /// pdv-dokument-vorlage` on `/Volumes/pdv-dokument-vorlage`. Matching host + share alone
    /// answered `/Volumes/pdv-dokument-vorlage/PDV_Gemeinsam` for a lookup of the share root — a
    /// path that EXISTS and is the wrong folder, so it would have navigated there in silence.
    func testASubmountOnlyAnswersForWhatItActuallyCovers() {
        let submount = [NetworkShare.MountEntry(from: "//maik1@srv/ablage/PDV_Gemeinsam/Transfer",
                                                mountPoint: "/Volumes/Transfer")]
        func look(_ input: String) -> String? {
            NetworkShare.location(from: input).flatMap { NetworkShare.mountedPath(for: $0, in: submount) }
        }
        XCTAssertEqual(look(#"\\srv\ablage\PDV_Gemeinsam\Transfer"#), "/Volumes/Transfer")
        XCTAssertEqual(look(#"\\srv\ablage\PDV_Gemeinsam\Transfer\NKR"#), "/Volumes/Transfer/NKR")
        // Above the submount there is nothing to answer with — the share root is NOT mounted.
        XCTAssertNil(look(#"\\srv\ablage"#))
        XCTAssertNil(look(#"\\srv\ablage\PDV_Gemeinsam"#))
        // A sibling of the submounted folder is not inside it either.
        XCTAssertNil(look(#"\\srv\ablage\PDV_Gemeinsam\Archiv"#))
    }

    /// With both the share root and a submount of it mounted, the SHALLOWEST one wins.
    ///
    /// Both reach the same bytes; what differs is what is left above the folder. Answering with the
    /// submount puts the panel in a volume whose root IS the target — no parents, no way up — which
    /// is the fault this whole route exists to avoid. Measured on the real table, where
    /// `/Volumes/ablage` and `/Volumes/pdv-dokument-vorlage` were both mounted from `ablage`.
    func testTheShallowestCoveringMountWins() {
        let both = [
            NetworkShare.MountEntry(from: "//srv/ablage", mountPoint: "/Volumes/ablage"),
            NetworkShare.MountEntry(from: "//srv/ablage/a/b", mountPoint: "/Volumes/b"),
        ]
        func look(_ input: String) -> String? {
            NetworkShare.location(from: input).flatMap { NetworkShare.mountedPath(for: $0, in: both) }
        }
        XCTAssertEqual(look(#"\\srv\ablage\a\b\c"#), "/Volumes/ablage/a/b/c")
        XCTAssertEqual(look(#"\\srv\ablage\a"#), "/Volumes/ablage/a")
        XCTAssertEqual(look(#"\\srv\ablage"#), "/Volumes/ablage")
    }

    /// The live table must at least be readable — `getmntinfo` through a tuple-typed C array is
    /// the one part of this that a synthetic table cannot exercise.
    func testCurrentMountsReadsTheLiveTable() {
        let live = NetworkShare.currentMounts()
        XCTAssertFalse(live.isEmpty)
        XCTAssertTrue(live.contains { $0.mountPoint == "/" }, "the boot volume is always mounted")
        XCTAssertTrue(live.allSatisfy { !$0.mountPoint.isEmpty && !$0.from.isEmpty })
    }
}
