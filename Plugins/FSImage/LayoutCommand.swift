// SPDX-License-Identifier: Apache-2.0
// LayoutCommand.swift — the Commands-menu entry, and the only part of this plugin
// that is not a filesystem reader.
//
// A plugin of any type may carry contributions; this one is a packer (pcx) that also
// contributes a single command. What the command does is deliberately narrow, and the
// reason is a limit worth writing down rather than working around: `PcHostServices`
// offers `openPath`, which navigates the active panel to a *real* path. There is no
// service that mounts a virtual filesystem. A contributed command therefore cannot put
// the user inside an image — only pressing Enter on the file can do that, which is what
// `CarvedDriver` and `PartitionedDriver` are for.
//
// So this command does not attempt navigation. It produces the one thing navigating
// cannot: a written record of the layout — offsets, lengths, what was found where —
// saved next to the image and selected in the panel. For firmware work that report is
// usually the actual deliverable, the thing that ends up in a ticket or a teardown note,
// and it is tedious to reconstruct by walking a panel and copying numbers by hand.
//
// The scan runs synchronously, on the caller's thread, because the ABI has no way to
// hand a result back later. That is honest for what this is aimed at — firmware images
// are tens of megabytes and scan in well under a second — and it is why the report is
// an explicit command rather than something that happens on its own.

import AppKit

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?,
                         _ services: UnsafePointer<PcHostServices>?) {
    guard let services, commandId.map({ String(cString: $0) }) == "plugin.fsimage.layout" else {
        return
    }
    let host = services.pointee

    guard let path = cursorPath(host) else {
        present(host, L("Scan Image Layout"),
                L("Put the cursor on a filesystem image first."))
        return
    }

    let report: String
    do {
        report = try LayoutReport.text(forImageAt: path)
    } catch {
        present(host, L("Scan Image Layout"),
                L("This file could not be scanned: ") + describe(error))
        return
    }

    guard let written = write(report, forImageAt: path) else {
        present(host, L("Scan Image Layout"),
                L("The report could not be written. The folder may be read-only."))
        return
    }
    // Reveals the report and puts the cursor on it, which is as close to "here is your
    // result" as the host services get.
    written.withCString { host.openPath?(host.host, $0) }
}

/// The file under the cursor, or nil when there is none.
///
/// `localCursorPath` rather than `cursorPath`: inside a virtual filesystem — an archive,
/// an SFTP connection — the first is a path that can actually be opened, because the
/// host has staged the file to a temporary copy. An image inside an archive is a real
/// thing to want to scan, and the plain cursor path would name something that no `open`
/// can reach.
private func cursorPath(_ host: PcHostServices) -> String? {
    var buffer = [CChar](repeating: 0, count: 4096)
    if let local = host.localCursorPath, local(host.host, &buffer, Int32(buffer.count)) == 1 {
        let path = String(cString: buffer)
        if !path.isEmpty { return path }
    }
    guard let cursor = host.cursorPath,
          cursor(host.host, &buffer, Int32(buffer.count)) == 1 else { return nil }
    let path = String(cString: buffer)
    return path.isEmpty ? nil : path
}

/// Save the report beside the image, falling back to the temporary directory.
///
/// Beside the image first because that is where somebody examining a device wants it —
/// the report belongs with the thing it describes, and a file in a temp folder is one
/// restart away from being gone. The fallback matters for the case the primary location
/// cannot serve: an image on a read-only mount, on a DMG, or staged out of an archive
/// into a directory the host owns.
private func write(_ report: String, forImageAt path: String) -> String? {
    let name = (path as NSString).lastPathComponent + ".layout.txt"
    let beside = ((path as NSString).deletingLastPathComponent as NSString)
        .appendingPathComponent(name)
    for candidate in [beside, (NSTemporaryDirectory() as NSString).appendingPathComponent(name)] {
        if (try? report.write(toFile: candidate, atomically: true, encoding: .utf8)) != nil {
            return candidate
        }
    }
    return nil
}

/// Say what went wrong in the words the reader needs, not in the words of a Swift enum.
private func describe(_ error: Error) -> String {
    guard let imageError = error as? ImageError else { return L("the file could not be read") }
    switch imageError {
    case .cannotOpen:            return L("the file could not be opened")
    case .readFailed:            return L("the file could not be read")
    case .notThisFormat:         return L("it is not a filesystem image")
    case .unsupported(let why):  return why
    case .damaged(let why):      return why
    case .outOfBounds:           return L("the image ends before its own structures do")
    case .limitExceeded(let l):  return L("the image is past a structural limit: ") + l
    }
}

private func present(_ host: PcHostServices, _ title: String, _ message: String) {
    guard let presentInfo = host.presentInfo else { return }
    title.withCString { titleC in
        message.withCString { messageC in
            presentInfo(host.host, titleC, messageC)
        }
    }
}
