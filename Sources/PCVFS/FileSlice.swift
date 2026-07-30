// SPDX-License-Identifier: Apache-2.0
// FileSlice.swift - Random access into a local file via mmap, for the Lister
// viewer (I07). Supports files up to disk size without reading them fully
// into memory: the file is memory-mapped once and slices are read directly
// from the mapped region.

import Foundation

/// Read-only, memory-mapped view of a local file.
///
/// `FileSlice` mmaps the file once at `init` and serves random-access reads
/// from the mapping. It is a reference type because it owns a raw pointer
/// (the mapping) and a file descriptor that must be released together in
/// `deinit`. It is intended for use on the main thread only (viewer UI code)
/// and is therefore not `Sendable`.
public final class FileSlice {
    private let fd: Int32
    private let mapping: UnsafeRawPointer?
    private let mappedSize: Int64

    /// Total number of bytes in the file.
    public var count: Int64 { mappedSize }

    /// Open and mmap the file at `path` read-only.
    ///
    /// Returns `nil` if the file cannot be opened or stat'd. Empty files are
    /// a valid case: `count` is 0 and no mapping is created (mmap of a
    /// zero-length region is undefined), so `bytes(at:length:)` always
    /// returns an empty array for them.
    public init?(path: String) {
        let openedFD = path.withCString { open($0, O_RDONLY) }
        guard openedFD >= 0 else { return nil }

        var info = stat()
        guard fstat(openedFD, &info) == 0 else {
            close(openedFD)
            return nil
        }

        let size = Int64(info.st_size)
        guard size >= 0 else {
            close(openedFD)
            return nil
        }

        if size == 0 {
            self.fd = openedFD
            self.mapping = nil
            self.mappedSize = 0
            return
        }

        guard let base = mmap(nil, Int(size), PROT_READ, MAP_PRIVATE, openedFD, 0),
              Int(bitPattern: base) != -1 else {
            close(openedFD)
            return nil
        }

        self.fd = openedFD
        self.mapping = UnsafeRawPointer(base)
        self.mappedSize = size
    }

    deinit {
        if let mapping {
            munmap(UnsafeMutableRawPointer(mutating: mapping), Int(mappedSize))
        }
        close(fd)
    }

    /// Read up to `length` bytes starting at `offset`.
    ///
    /// Both `offset` and `length` are clamped to the file's bounds; an
    /// out-of-range `offset` (negative, or at/beyond `count`) returns an
    /// empty array, as does a non-positive `length`.
    public func bytes(at offset: Int64, length: Int) -> [UInt8] {
        guard let mapping, offset >= 0, offset < mappedSize, length > 0 else {
            return []
        }

        let available = mappedSize - offset
        let clampedLength = Int(min(Int64(length), available))
        guard clampedLength > 0 else { return [] }

        let start = mapping.advanced(by: Int(offset)).assumingMemoryBound(to: UInt8.self)
        return [UInt8](UnsafeBufferPointer(start: start, count: clampedLength))
    }

    /// Read up to `length` bytes starting at `offset`, as `Data`.
    public func data(at offset: Int64, length: Int) -> Data {
        Data(bytes(at: offset, length: length))
    }

    /// Scoped access to the whole memory-mapped region as a raw buffer, without
    /// copying — for a single streaming pass (e.g. line indexing) over huge files.
    /// The buffer is only valid for the duration of `body`.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
        guard let mapping, mappedSize > 0 else {
            return body(UnsafeRawBufferPointer(start: nil, count: 0))
        }
        return body(UnsafeRawBufferPointer(start: mapping, count: Int(mappedSize)))
    }
}
