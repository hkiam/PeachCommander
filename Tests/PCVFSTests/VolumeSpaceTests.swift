// SPDX-License-Identifier: Apache-2.0
// VolumeSpaceTests.swift - The free/total figures a panel header shows (F-037).
//
// The arithmetic behind the header had no tests. It is three lines, which is exactly why: the sizes
// disks actually come in are the interesting input, not the formula. A 4 TB volume used to read
// "4096.0 GB" because the unit ladder stopped at G — fixed in ByteSize, and this is the caller that
// would have shown it.

import XCTest
@testable import PCFoundation
@testable import PCVFS

final class VolumeSpaceTests: XCTestCase {
    private let tb: Int64 = 1024 * 1024 * 1024 * 1024

    private func volume(capacity: Int64, free: Int64) -> Volume {
        Volume(id: "test", name: "Test", path: "/Volumes/Test",
               isRemovable: false, isEjectable: false, isHidden: false,
               capacity: capacity, freeSpace: free, fsType: "apfs")
    }

    func testUsedIsWhatIsLeftOverFromTheCapacity() {
        let v = volume(capacity: 500, free: 200)
        XCTAssertEqual(v.usedSpace, 300)
    }

    func testAMultiTerabyteVolumeIsNotReportedInGigabytes() {
        // The sizes people have: 4 TB free of 8 TB. The old ladder produced "4096.0 GB" here.
        let v = volume(capacity: 8 * tb, free: 4 * tb)
        XCTAssertTrue(v.freeSpaceFormatted().contains("TB"), v.freeSpaceFormatted())
        XCTAssertTrue(v.capacityFormatted().contains("TB"), v.capacityFormatted())
    }

    func testAnOrdinarySizeStillReadsAsItDid() {
        let v = volume(capacity: 512 * 1024 * 1024, free: 256 * 1024 * 1024)
        XCTAssertTrue(v.freeSpaceFormatted().contains("MB"), v.freeSpaceFormatted())
    }

    func testThePercentageIsOfFreeSpace() {
        let v = volume(capacity: 1000, free: 250)
        XCTAssertEqual(v.freeSpacePercentage(), 25.0, accuracy: 0.001)
    }

    func testAVolumeReportingNoCapacityDoesNotDivideByZero() {
        // A network mount that will not answer reports 0, and the header still has to draw something.
        let v = volume(capacity: 0, free: 0)
        XCTAssertEqual(v.freeSpacePercentage(), 0.0)
        XCTAssertEqual(v.usedSpace, 0)
    }
}
