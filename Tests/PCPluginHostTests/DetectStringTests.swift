// SPDX-License-Identifier: Apache-2.0
// DetectStringTests.swift - Tests for the TC detect-string parser + evaluator
//
// Covers SPEC-012 §6, feature F-238.

import XCTest
@testable import PCPluginHost

final class DetectStringTests: XCTestCase {

    // MARK: - Fixtures

    /// A ZIP-ish file: extension ZIP, starts with the "PK\x03\x04" signature.
    private func zipContext(ext: String = "zip", size: Int64 = 1024) -> DetectContext {
        // 0x50 0x4B 0x03 0x04 == "PK.." local-file-header signature.
        return DetectContext(ext: ext, size: size, bytes: [0x50, 0x4B, 0x03, 0x04, 0x00],
                             isMultimedia: false)
    }

    /// A short file with only two bytes available.
    private func shortContext() -> DetectContext {
        return DetectContext(ext: "bin", size: 2, bytes: [0x01, 0x02], isMultimedia: false)
    }

    /// A JPEG-ish multimedia file starting with 0xFF.
    private func jpegContext() -> DetectContext {
        return DetectContext(ext: "jpg", size: 5000, bytes: [0xFF, 0xD8, 0xFF, 0xE0],
                             isMultimedia: true)
    }

    // MARK: - TC example: EXT="ZIP"

    func testExtEqualsZipTrue() {
        XCTAssertTrue(DetectString.matches(#"EXT="ZIP""#, context: zipContext()))
    }

    func testExtEqualsZipFalse() {
        XCTAssertFalse(DetectString.matches(#"EXT="ZIP""#, context: zipContext(ext: "txt")))
    }

    // MARK: - EXT case-insensitivity

    func testExtCaseInsensitiveLiteralUppercase() {
        // Context ext is lowercase "zip"; literal is uppercase "ZIP".
        XCTAssertTrue(DetectString.matches(#"EXT="ZIP""#, context: zipContext(ext: "zip")))
    }

    func testExtCaseInsensitiveLiteralLowercase() {
        XCTAssertTrue(DetectString.matches(#"EXT="zip""#, context: zipContext(ext: "ZIP")))
    }

    func testExtInequality() {
        XCTAssertTrue(DetectString.matches(#"EXT!="MP3""#, context: jpegContext()))
        XCTAssertFalse(DetectString.matches(#"EXT!="JPG""#, context: jpegContext()))
    }

    // MARK: - TC example: EXT="TXT" & SIZE>100

    func testExtAndSizeTrue() {
        let ctx = DetectContext(ext: "txt", size: 200, bytes: [], isMultimedia: false)
        XCTAssertTrue(DetectString.matches(#"EXT="TXT" & SIZE>100"#, context: ctx))
    }

    func testExtAndSizeFalseBySize() {
        let ctx = DetectContext(ext: "txt", size: 50, bytes: [], isMultimedia: false)
        XCTAssertFalse(DetectString.matches(#"EXT="TXT" & SIZE>100"#, context: ctx))
    }

    func testExtAndSizeFalseByExt() {
        let ctx = DetectContext(ext: "md", size: 200, bytes: [], isMultimedia: false)
        XCTAssertFalse(DetectString.matches(#"EXT="TXT" & SIZE>100"#, context: ctx))
    }

    // MARK: - SIZE comparisons around a boundary (boundary = 100)

    func testSizeComparisons() {
        func ctx(_ n: Int64) -> DetectContext {
            DetectContext(ext: "x", size: n, bytes: [], isMultimedia: false)
        }
        XCTAssertTrue(DetectString.matches("SIZE>100", context: ctx(101)))
        XCTAssertFalse(DetectString.matches("SIZE>100", context: ctx(100)))

        XCTAssertTrue(DetectString.matches("SIZE<100", context: ctx(99)))
        XCTAssertFalse(DetectString.matches("SIZE<100", context: ctx(100)))

        XCTAssertTrue(DetectString.matches("SIZE>=100", context: ctx(100)))
        XCTAssertFalse(DetectString.matches("SIZE>=100", context: ctx(99)))

        XCTAssertTrue(DetectString.matches("SIZE<=100", context: ctx(100)))
        XCTAssertFalse(DetectString.matches("SIZE<=100", context: ctx(101)))

        XCTAssertTrue(DetectString.matches("SIZE=100", context: ctx(100)))
        XCTAssertFalse(DetectString.matches("SIZE=100", context: ctx(101)))

        XCTAssertTrue(DetectString.matches("SIZE!=100", context: ctx(101)))
        XCTAssertFalse(DetectString.matches("SIZE!=100", context: ctx(100)))
    }

    // MARK: - TC example: [0]=80 & [1]=75  (PK zip signature)

    func testByteProbeZipSignatureTrue() {
        XCTAssertTrue(DetectString.matches("[0]=80 & [1]=75", context: zipContext()))
    }

    func testByteProbeZipSignatureFailsOnOtherBytes() {
        let notZip = DetectContext(ext: "zip", size: 10, bytes: [0x00, 0x00, 0x00],
                                   isMultimedia: false)
        XCTAssertFalse(DetectString.matches("[0]=80 & [1]=75", context: notZip))
    }

    func testByteProbeBeyondFileLengthIsFalse() {
        // Only 2 bytes available; probing [5] can never match.
        XCTAssertFalse(DetectString.matches("[5]=1", context: shortContext()))
        // Even an inequality against a missing byte is false (TC semantics).
        XCTAssertFalse(DetectString.matches("[5]!=99", context: shortContext()))
    }

    func testByteProbeInequality() {
        XCTAssertTrue(DetectString.matches("[0]!=0", context: zipContext()))
        XCTAssertFalse(DetectString.matches("[0]!=80", context: zipContext()))
    }

    // MARK: - TC example: MULTIMEDIA & EXT!="MP3"

    func testMultimediaAndExtNotMp3True() {
        XCTAssertTrue(DetectString.matches(#"MULTIMEDIA & EXT!="MP3""#, context: jpegContext()))
    }

    func testMultimediaAndExtNotMp3FalseByExt() {
        let mp3 = DetectContext(ext: "mp3", size: 5000, bytes: [], isMultimedia: true)
        XCTAssertFalse(DetectString.matches(#"MULTIMEDIA & EXT!="MP3""#, context: mp3))
    }

    func testMultimediaFalseWhenNotMultimedia() {
        let doc = DetectContext(ext: "doc", size: 100, bytes: [], isMultimedia: false)
        XCTAssertFalse(DetectString.matches(#"MULTIMEDIA & EXT!="MP3""#, context: doc))
    }

    func testMultimediaBareBoolTrueAndFalse() {
        XCTAssertTrue(DetectString.matches("MULTIMEDIA", context: jpegContext()))
        XCTAssertFalse(DetectString.matches("MULTIMEDIA", context: zipContext()))
    }

    func testMultimediaNumericComparison() {
        XCTAssertTrue(DetectString.matches("MULTIMEDIA=1", context: jpegContext()))
        XCTAssertTrue(DetectString.matches("MULTIMEDIA=0", context: zipContext()))
        XCTAssertFalse(DetectString.matches("MULTIMEDIA=1", context: zipContext()))
    }

    // MARK: - TC example: FORCE

    func testForceAlwaysTrue() {
        XCTAssertTrue(DetectString.matches("FORCE", context: zipContext()))
        XCTAssertTrue(DetectString.matches("FORCE", context: shortContext()))
    }

    // MARK: - TC example: (EXT="JPG" | EXT="JPEG") & [0]=255

    func testGroupedOrWithByteTrueJpg() {
        XCTAssertTrue(DetectString.matches(#"(EXT="JPG" | EXT="JPEG") & [0]=255"#,
                                           context: jpegContext()))
    }

    func testGroupedOrWithByteTrueJpeg() {
        let jpeg = DetectContext(ext: "jpeg", size: 5000, bytes: [0xFF, 0xD8],
                                 isMultimedia: true)
        XCTAssertTrue(DetectString.matches(#"(EXT="JPG" | EXT="JPEG") & [0]=255"#,
                                           context: jpeg))
    }

    func testGroupedOrWithByteFalseByByte() {
        let png = DetectContext(ext: "jpg", size: 5000, bytes: [0x89, 0x50],
                                isMultimedia: true)
        XCTAssertFalse(DetectString.matches(#"(EXT="JPG" | EXT="JPEG") & [0]=255"#,
                                            context: png))
    }

    // MARK: - NOT negation

    func testNotNegation() {
        XCTAssertFalse(DetectString.matches(#"!EXT="ZIP""#, context: zipContext()))
        XCTAssertTrue(DetectString.matches(#"!EXT="RAR""#, context: zipContext()))
    }

    func testNotWithParentheses() {
        XCTAssertTrue(DetectString.matches("!(SIZE>100)",
                                           context: DetectContext(ext: "x", size: 10,
                                                                  bytes: [], isMultimedia: false)))
    }

    // MARK: - Precedence: & binds tighter than |

    func testAndBindsTighterThanOr() {
        // Parsed as: EXT="ZIP" | (EXT="TXT" & SIZE>1000000).
        // For a ZIP file, the left side is true, so the whole thing is true.
        // Under WRONG precedence ( (A|B) & C ), the trailing SIZE>1000000 would
        // make it false, so this test distinguishes correct vs. wrong precedence.
        let ctx = zipContext(size: 10)
        XCTAssertTrue(DetectString.matches(#"EXT="ZIP" | EXT="TXT" & SIZE>1000000"#,
                                           context: ctx))
    }

    func testParenthesesOverridePrecedence() {
        // Forcing (A|B)&C: ZIP matches A, but SIZE>1000000 is false -> whole false.
        let ctx = zipContext(size: 10)
        XCTAssertFalse(DetectString.matches(#"(EXT="ZIP" | EXT="TXT") & SIZE>1000000"#,
                                            context: ctx))
    }

    // MARK: - Empty / whitespace-only

    func testEmptyStringIsFalse() {
        XCTAssertFalse(DetectString.matches("", context: zipContext()))
        XCTAssertFalse(DetectString.isValid(""))
    }

    func testWhitespaceOnlyIsFalse() {
        XCTAssertFalse(DetectString.matches("   \t\n", context: zipContext()))
        XCTAssertFalse(DetectString.isValid("   \t\n"))
    }

    // MARK: - Malformed strings -> matches false AND isValid false

    func testMalformedExtWithNoValue() {
        XCTAssertFalse(DetectString.matches("EXT=", context: zipContext()))
        XCTAssertFalse(DetectString.isValid("EXT="))
    }

    func testMalformedTrailingAnd() {
        XCTAssertFalse(DetectString.matches(#"EXT="ZIP" &"#, context: zipContext()))
        XCTAssertFalse(DetectString.isValid(#"EXT="ZIP" &"#))
    }

    func testMalformedByteOffsetOutOfRange() {
        XCTAssertFalse(DetectString.matches("[99999]=1", context: zipContext()))
        XCTAssertFalse(DetectString.isValid("[99999]=1"))
    }

    func testMalformedDoubledOperator() {
        XCTAssertFalse(DetectString.matches("SIZE>>1", context: zipContext()))
        XCTAssertFalse(DetectString.isValid("SIZE>>1"))
    }

    func testMalformedUnterminatedString() {
        XCTAssertFalse(DetectString.isValid(#"EXT="ZIP"#))
    }

    func testMalformedUnbalancedParen() {
        XCTAssertFalse(DetectString.isValid(#"(EXT="ZIP""#))
    }

    func testMalformedExtComparedToNumber() {
        // EXT must compare against a quoted string, not a number.
        XCTAssertFalse(DetectString.isValid("EXT=5"))
    }

    func testMalformedSizeComparedToString() {
        // SIZE must compare against an integer, not a string.
        XCTAssertFalse(DetectString.isValid(#"SIZE="100""#))
    }

    // MARK: - isValid on valid expressions

    func testIsValidSimple() {
        XCTAssertTrue(DetectString.isValid(#"EXT="ZIP""#))
        XCTAssertTrue(DetectString.isValid("FORCE"))
        XCTAssertTrue(DetectString.isValid("[8191]=0"))
    }

    func testIsValidComplexExpression() {
        let complex = #"(EXT="JPG" | EXT="JPEG") & [0]=255 & !(SIZE<10) | FORCE"#
        XCTAssertTrue(DetectString.isValid(complex))
    }

    // MARK: - Byte offset boundary values

    func testByteOffsetLowerAndUpperBoundsAreValid() {
        XCTAssertTrue(DetectString.isValid("[0]=1"))
        XCTAssertTrue(DetectString.isValid("[8191]=1"))
        XCTAssertFalse(DetectString.isValid("[8192]=1"))
    }

    // MARK: - EXT lexicographic ordering (rarely used but supported)

    func testExtLexicographicOrdering() {
        let ctx = DetectContext(ext: "bbb", size: 0, bytes: [], isMultimedia: false)
        XCTAssertTrue(DetectString.matches(#"EXT>"aaa""#, context: ctx))
        XCTAssertTrue(DetectString.matches(#"EXT<"ccc""#, context: ctx))
        XCTAssertFalse(DetectString.matches(#"EXT>"ccc""#, context: ctx))
    }
}

// MARK: - The Java decompiler's detect string (F-345)
//
// The plugin claims .class by extension *and* by CAFEBABE, so a class file that lost its name
// inside an archive is still recognised. Both halves are asserted here because a detect string
// that silently never matches looks exactly like a plugin that failed to load.

extension DetectStringTests {
    private var javaDetect: String { #"EXT="CLASS" | ([0]=202 & [1]=254 & [2]=186 & [3]=190)"# }

    func testJavaDetectStringIsValid() {
        XCTAssertTrue(DetectString.isValid(javaDetect), "a malformed detect string never matches")
    }

    func testJavaDetectMatchesByExtension() {
        let ctx = DetectContext(ext: "class", size: 1000, bytes: [0, 0, 0, 0])
        XCTAssertTrue(DetectString.matches(javaDetect, context: ctx))
    }

    /// CAFEBABE = 0xCA 0xFE 0xBA 0xBE = 202 254 186 190.
    ///
    /// Note the single `=`: this dialect has no `==`, and a detect string using it parses as
    /// invalid, which means the plugin silently never claims anything. That is exactly how the
    /// first version of this plugin failed — the viewer just showed plain text.
    func testJavaDetectMatchesByMagicWithoutAnExtension() {
        let ctx = DetectContext(ext: "", size: 1000, bytes: [202, 254, 186, 190, 0, 0])
        XCTAssertTrue(DetectString.matches(javaDetect, context: ctx),
                      "a class file without its extension must still be recognised")
    }

    func testJavaDetectIgnoresUnrelatedFiles() {
        XCTAssertFalse(DetectString.matches(javaDetect,
                                            context: DetectContext(ext: "txt", size: 10, bytes: [1, 2, 3, 4])))
        // A Mach-O also starts with 0xCAFEBABE (fat binary) — but only the byte test can confuse
        // them, and the extension differs, so this documents the known overlap rather than hiding it.
        XCTAssertTrue(DetectString.matches(javaDetect,
                                           context: DetectContext(ext: "", size: 10, bytes: [202, 254, 186, 190])),
                      "known overlap with Mach-O fat binaries; the engine reports it cannot read them")
    }
}

// MARK: - Every shipped plugin's own detect string (F-353)

/// Reads the detect strings out of the real Info.plists and holds them to the grammar.
///
/// This exists because a plugin once shipped with `==` in its detect string. The dialect has a single
/// `=`, so the expression was invalid, and an invalid expression matches nothing — the plugin loaded,
/// claimed no file, and looked simply broken with nothing to point at. A parse check over the shipped
/// manifests would have caught it in the commit that introduced it.
final class ShippedDetectStringTests: XCTestCase {
    /// Repo root, derived from this file's path so the test does not depend on the working directory.
    private var pluginsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PCPluginHostTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Plugins")
    }

    private func manifests() throws -> [(name: String, detect: String)] {
        let fm = FileManager.default
        var out: [(String, String)] = []
        for entry in try fm.contentsOfDirectory(atPath: pluginsDirectory.path).sorted() {
            let plist = pluginsDirectory.appendingPathComponent(entry).appendingPathComponent("Info.plist")
            guard let data = try? Data(contentsOf: plist),
                  let dict = try? PropertyListSerialization.propertyList(
                    from: data, format: nil) as? [String: Any],
                  let detect = dict["PCPluginDetectString"] as? String, !detect.isEmpty else { continue }
            out.append((entry, detect))
        }
        return out
    }

    func testEveryShippedDetectStringParses() throws {
        let all = try manifests()
        XCTAssertFalse(all.isEmpty, "no manifest declared a detect string — is the path right?")
        for (name, detect) in all {
            XCTAssertTrue(DetectString.isValid(detect), "\(name): invalid detect string: \(detect)")
        }
    }

    func testTheDotNetPluginClaimsAWindowsImageAndNothingElse() throws {
        let detect = try XCTUnwrap(manifests().first { $0.name == "NetDecompiler" }?.detect)
        // A .dll that starts with "MZ" is a candidate; whether it is *managed* cannot be asked here —
        // the CLI header sits behind a pointer and the grammar has fixed offsets only. The plugin
        // checks that at load time and declines, which is what keeps native libraries out.
        XCTAssertTrue(DetectString.matches(detect, context: DetectContext(
            ext: "dll", size: 4096, bytes: [0x4D, 0x5A, 0x90, 0x00], isMultimedia: false)))
        XCTAssertFalse(DetectString.matches(detect, context: DetectContext(
            ext: "dll", size: 4096, bytes: [0x7F, 0x45, 0x4C, 0x46], isMultimedia: false)),
                       "an ELF shared object is not a Windows image")
        XCTAssertFalse(DetectString.matches(detect, context: DetectContext(
            ext: "class", size: 4096, bytes: [0xCA, 0xFE, 0xBA, 0xBE], isMultimedia: false)),
                       "that is the Java plugin's format")
    }
}
