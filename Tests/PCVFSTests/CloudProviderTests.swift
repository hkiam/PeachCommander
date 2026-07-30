// CloudProviderTests.swift - Cloud provider availability + volume mapping.

import XCTest
@testable import PCVFS

final class CloudProviderTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCVFS-Cloud-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil
    }

    func test_isAvailable_trueForExistingDir_falseForMissing() {
        let present = CloudProvider(id: "x", name: "X", localPath: tempDir.path)
        XCTAssertTrue(present.isAvailable)

        let missing = CloudProvider(id: "y", name: "Y",
                                    localPath: tempDir.appendingPathComponent("nope").path)
        XCTAssertFalse(missing.isAvailable)
    }

    func test_isAvailable_falseForRegularFile() throws {
        let file = tempDir.appendingPathComponent("f.txt")
        try Data("x".utf8).write(to: file)
        XCTAssertFalse(CloudProvider(id: "f", name: "F", localPath: file.path).isAvailable)
    }

    func test_iCloudDrivePath_pointsAtMobileDocuments() {
        XCTAssertTrue(CloudProviderRegistry.iCloudDrivePath.hasSuffix("Mobile Documents/com~apple~CloudDocs"))
    }

    func test_getCloudVolumes_mapsAvailableProviders() async {
        // Deterministic where iCloud isn't configured (CI): if the registry has
        // providers, each must map to a cloud:* volume at its local path.
        let manager = VolumeManager()
        let volumes = await manager.getCloudVolumes()
        let providers = CloudProviderRegistry.available()
        XCTAssertEqual(volumes.count, providers.count)
        for provider in providers {
            let v = volumes.first { $0.id == "cloud:\(provider.id)" }
            XCTAssertEqual(v?.path, provider.localPath)
            XCTAssertEqual(v?.fsType, "Cloud")
        }
    }
}
