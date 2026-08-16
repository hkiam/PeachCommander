// SPDX-License-Identifier: Apache-2.0
// LayoutReport.swift — the scan result as text somebody can keep.
//
// Browsing an image answers "what is in it". This answers "how is it laid out", which
// is a different question and the one firmware work actually writes down: which offset
// the bootloader starts at, how big the kernel is, where the rootfs begins. That is the
// note that goes into a ticket or a teardown, and it is worth producing as a file
// rather than as a panel you have to read and retype.
//
// Deliberately separate from the command that invokes it: this function touches no UI,
// takes a path and returns a string, and is therefore testable against a fixture the
// same way every driver here is. The command in `LayoutCommand.swift` is the thin part —
// find the cursor, call this, write the file — and the thin part is the part that cannot
// be tested without a running app.
//
// The output is deliberately locale-independent. `ByteCountFormatter` would produce
// "2,1 MB" on a German system and "2.1 MB" elsewhere, which makes the report a
// different document depending on who ran it and makes it untestable into the bargain.
// Sizes here are formatted by hand, in bytes and in a fixed binary unit.

import Foundation

enum LayoutReport {
    /// Build the report for the image at `path`.
    ///
    /// Throws whatever the scan throws — an unreadable file and an image whose structure
    /// blows a limit are both worth reporting to the user as themselves rather than as
    /// an empty report.
    static func text(forImageAt path: String) throws -> String {
        let reader = try ImageReader(path: path)
        var lines: [String] = []
        lines.append("Peach Commander — filesystem image layout")
        lines.append("")
        lines.append("File:  \(path)")
        // Both forms once, at the top: the readable one for the person reading the
        // report, the exact one for whatever tool they run next.
        lines.append("Size:  \(size(reader.count)) (\(reader.count) bytes)")
        lines.append("")

        // The declared table first, when there is one. It is a different kind of fact
        // from the scan below — something the image states about itself rather than
        // something found by looking — and the two are worth being able to compare. A
        // partition the table declares but the scan finds nothing in is exactly the
        // sort of discrepancy this report exists to make visible.
        if let partitions = try? PartitionTable.read(reader), !partitions.isEmpty {
            lines.append("Partition table: \(partitions.count) partitions")
            lines.append(row("#", "Offset", "Length", "Type"))
            lines.append(rule())
            for partition in partitions {
                lines.append(row("\(partition.number)", hex(partition.offset),
                                 size(partition.length), partition.typeName))
            }
            lines.append("")
        }

        let regions = try ImageLayout.scan(reader)
        lines.append("Contents found by scanning: \(regions.count) regions")
        lines.append(row("", "Offset", "Length", "Type", "Detail"))
        lines.append(rule())
        for region in regions {
            lines.append(row("", hex(region.offset), size(region.length),
                             region.typeName, region.describedAs))
        }

        let filesystems = regions.filter(\.isFilesystem).count
        lines.append("")
        lines.append(filesystems == 0
            ? "No filesystems were found in this image."
            : "\(filesystems) filesystem\(filesystems == 1 ? "" : "s") can be opened from this image.")
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Formatting

    private static func row(_ number: String, _ offset: String, _ length: String,
                            _ type: String, _ detail: String = "") -> String {
        let line = "\(pad(number, 3))\(pad(offset, 13))\(pad(length, 14))\(pad(type, 16))\(detail)"
        // Trailing padding on the last column would be invisible in a terminal and
        // visible in a diff, so it goes.
        return String(line.reversed().drop { $0 == " " }.reversed())
    }

    private static func rule() -> String { String(repeating: "-", count: 72) }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }

    /// `0x00230044` — the same form the panel entries use, so a name in one can be found
    /// in the other without conversion.
    private static func hex(_ value: Int64) -> String { String(format: "0x%08llx", value) }

    /// "2.0 MB", in fixed binary units. Bytes below a kilobyte, so a 64-byte header
    /// reads as 64 B rather than 0.1 KB.
    private static func size(_ bytes: Int64) -> String {
        guard bytes >= 1024 else { return "\(bytes) B" }
        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes) / 1024
        var unit = 0
        while value >= 1024, unit + 1 < units.count {
            value /= 1024
            unit += 1
        }
        return String(format: "%.1f %@", value, units[unit])
    }
}
