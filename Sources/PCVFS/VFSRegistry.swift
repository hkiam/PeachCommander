// SPDX-License-Identifier: Apache-2.0
// VFSRegistry.swift - Scheme -> filesystem registry (SPEC-006 §2).

import Foundation

/// Registry mapping VFS schemes (`"file"`, `"archive"`, `"ftp"`, ...) to
/// concrete `VirtualFileSystem` instances.
///
/// Thread-safe: reads and writes are serialized behind a lock so the registry
/// can be shared across panels/tabs and accessed from any queue.
public final class VFSRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var byScheme: [String: VirtualFileSystem] = [:]

    /// Creates an empty registry.
    public init() {}

    /// Registers a filesystem instance, keyed by its `scheme`.
    ///
    /// Registering another filesystem under an already-registered scheme
    /// replaces the previous instance.
    public func register(_ fs: VirtualFileSystem) {
        lock.lock()
        defer { lock.unlock() }
        byScheme[fs.scheme] = fs
    }

    /// The filesystem registered for `scheme`, or `nil` if none is registered.
    public func filesystem(scheme: String) -> VirtualFileSystem? {
        lock.lock()
        defer { lock.unlock() }
        return byScheme[scheme]
    }

    /// All currently registered schemes, in no particular order.
    public var schemes: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(byScheme.keys)
    }
}

extension VFSRegistry {
    /// Process-wide registry, pre-registered with a `LocalFS` under the
    /// `"file"` scheme. Convenience for call sites that don't own their own
    /// registry instance (e.g. app wiring); tests should generally create a
    /// fresh `VFSRegistry()` instead.
    public static let shared: VFSRegistry = {
        let registry = VFSRegistry()
        registry.register(LocalFS())
        return registry
    }()
}
