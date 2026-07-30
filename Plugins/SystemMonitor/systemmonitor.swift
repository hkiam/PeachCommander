// SPDX-License-Identifier: Apache-2.0
// systemmonitor.swift — compact live system-monitor chips in the window titlebar,
// each opening a native NSPopover with details. External "ptx" plugin: it
// contributes a view to the host "titlebar" container (Info.plist) and does all
// data gathering in-process via public macOS APIs (mach host_statistics /
// host_processor_info, sysctl, getifaddrs, IOKit power sources, statfs). One
// central MonitorService samples on a background queue on a single 1 s timer,
// keeps current metrics + bounded history, and drives both the chips and any open
// popover from the same data. Capability-based: only modules with real data show;
// GPU and sensors are declared unavailable (no simulated values).

import AppKit
import Darwin
import IOKit
import IOKit.ps

// MARK: - Entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, String(cString: commandId) == "plugin.sysmon.configure" else { return }
    let parent = services?.pointee.parentWindow.map { Unmanaged<NSWindow>.fromOpaque($0).takeUnretainedValue() }
    MonitorSettingsWindow.shared.present(over: parent)
}

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ container: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    // The settings pane is contributed into the host Settings dialog ("settings").
    if let container, String(cString: container) == "settings" {
        return Unmanaged.passRetained(SettingsView()).toOpaque()
    }
    let view = TitlebarMonitorView()
    if let services {
        let svc = services.pointee, host = svc.host
        if let fn = svc.openPathInPanel {
            view.openInPanel = { side, p in p.withCString { fn(host, Int32(side), $0) } }
        }
    }
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    (Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? TitlebarMonitorView)?.teardown()
    Unmanaged<NSView>.fromOpaque(view).release()
}

@_cdecl("PcNotifyView")
public func PcNotifyView(_ view: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?, _ value: UnsafePointer<CChar>?) {}

// MARK: - Module identity

enum ModuleID: String, CaseIterable, Codable {
    case cpu, gpu, memory, disk, network, sensors, battery
    var label: String {
        switch self {
        case .cpu: return L("CPU"); case .gpu: return L("GPU"); case .memory: return L("RAM")
        case .disk: return L("HDD"); case .network: return L("Net"); case .sensors: return L("Sens")
        case .battery: return L("Batt")
        }
    }
    var symbol: String {
        switch self {
        case .cpu: return "cpu"; case .gpu: return "cpu.fill"; case .memory: return "memorychip"
        case .disk: return "internaldrive"; case .network: return "network"
        case .sensors: return "thermometer.medium"; case .battery: return "battery.100"
        }
    }
    /// Upper bound for history graphs: 1.0 for 0…1 utilization metrics, 0 (auto-scale
    /// to the window maximum) for open-ended metrics like network throughput.
    var graphMax: Double { self == .network ? 0 : 1 }
}

// MARK: - Configuration (persisted as JSON under Application Support)

struct ModuleConfig: Codable {
    var id: ModuleID
    var enabled: Bool
    var showValue: Bool = true
    var showGraph: Bool = false
    var showLabel: Bool = true
    var colorHex: String = "#8E8E93"
}

struct MonitorConfig: Codable {
    var enabled: Bool = true
    var scale: Double = 1.0          // 0.8…1.4 title text scale
    var profile: String = "medium"   // minimal | medium | maximal
    var modules: [ModuleConfig] = []

    static func defaults(profile: String) -> MonitorConfig {
        func m(_ id: ModuleID, _ on: Bool, graph: Bool = false, color: String) -> ModuleConfig {
            ModuleConfig(id: id, enabled: on, showValue: true, showGraph: graph, showLabel: true, colorHex: color)
        }
        // Order defines titlebar order (left→right). Colors are muted accents.
        let all: [ModuleConfig]
        switch profile {
        case "minimal":
            all = [m(.cpu, true, color: "#FF9F0A"), m(.memory, true, color: "#30D158"),
                   m(.battery, true, color: "#0A84FF"),
                   m(.gpu, false, color: "#BF5AF2"), m(.disk, false, color: "#64D2FF"),
                   m(.network, false, color: "#5E5CE6"), m(.sensors, false, color: "#FF453A")]
        case "maximal":
            all = [m(.cpu, true, graph: true, color: "#FF9F0A"), m(.gpu, true, graph: true, color: "#BF5AF2"),
                   m(.memory, true, graph: true, color: "#30D158"), m(.disk, true, color: "#64D2FF"),
                   m(.network, true, graph: true, color: "#5E5CE6"), m(.sensors, true, color: "#FF453A"),
                   m(.battery, true, color: "#0A84FF")]
        default: // medium
            all = [m(.cpu, true, color: "#FF9F0A"), m(.gpu, true, color: "#BF5AF2"),
                   m(.memory, true, color: "#30D158"), m(.network, true, color: "#5E5CE6"),
                   m(.battery, true, color: "#0A84FF"),
                   m(.disk, false, color: "#64D2FF"), m(.sensors, false, color: "#FF453A")]
        }
        return MonitorConfig(enabled: true, scale: 1.0, profile: profile, modules: all)
    }
}

final class ConfigStore {
    static let shared = ConfigStore()
    private(set) var config: MonitorConfig
    var onChange: (() -> Void)?

    private let url: URL = {
        // Store under the host's config root so an isolated `-ConfigRoot` (used for
        // testing) is honored; production falls back to the standard location.
        let root: URL
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-ConfigRoot"), i + 1 < args.count {
            root = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        } else if let env = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"], !env.isEmpty {
            root = URL(fileURLWithPath: env, isDirectory: true)
        } else {
            root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("PeachCommander", isDirectory: true)
        }
        let base = root.appendingPathComponent("systemmonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("config.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(MonitorConfig.self, from: data) {
            config = c
        } else {
            config = .defaults(profile: "medium")
        }
    }

    func update(_ mutate: (inout MonitorConfig) -> Void) {
        mutate(&config)
        try? JSONEncoder().encode(config).write(to: url, options: .atomic)
        onChange?()
    }

    func applyProfile(_ profile: String) {
        update { $0 = .defaults(profile: profile) }
    }
}

// MARK: - Hardware info (capability detection)

struct HardwareInfo {
    let chip: String
    let pCores: Int
    let eCores: Int
    let totalCores: Int
    let memoryBytes: Int64

    static let shared = HardwareInfo()
    private init() {
        chip = Sysctl.string("machdep.cpu.brand_string") ?? Sysctl.string("hw.model") ?? "Mac"
        let p = Int(Sysctl.int("hw.perflevel0.logicalcpu") ?? 0)
        let e = Int(Sysctl.int("hw.perflevel1.logicalcpu") ?? 0)
        totalCores = Int(Sysctl.int("hw.logicalcpu") ?? Int64(ProcessInfo.processInfo.activeProcessorCount))
        pCores = p; eCores = e
        memoryBytes = Sysctl.int("hw.memsize") ?? 0
    }
    /// Core index → true if a performance core (best-effort: first pCores are P).
    func isPerformanceCore(_ index: Int) -> Bool { pCores > 0 && eCores > 0 && index < pCores }
}

enum Sysctl {
    static func int(_ name: String) -> Int64? {
        var value: Int64 = 0; var size = MemoryLayout<Int64>.size
        if sysctlbyname(name, &value, &size, nil, 0) == 0, size == MemoryLayout<Int64>.size { return value }
        var v32: Int32 = 0; var s32 = MemoryLayout<Int32>.size
        if sysctlbyname(name, &v32, &s32, nil, 0) == 0 { return Int64(v32) }
        return nil
    }
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
        return String(cString: buf)
    }
}

// MARK: - Metrics + history

/// One module's current reading for the titlebar + popover.
struct Metric {
    var available: Bool
    var value: Double          // primary 0…1 utilization (for graphs/bars) where meaningful
    var short: String          // compact titlebar text, e.g. "8%" / "49G/128G"
    /// Widest value the chip must reserve room for so the titlebar layout doesn't
    /// jitter as the digit count changes (e.g. "100%"). Empty → use `short`.
    var widthTemplate: String = ""
    var rows: [(String, String)] = []   // popover detail rows
    var cores: [Double] = []            // CPU per-core utilization (0…1)
}

/// Fixed-capacity ring buffer of Double for history graphs.
struct Ring {
    private var buf: [Double]
    private var head = 0
    private(set) var count = 0
    init(capacity: Int) { buf = Array(repeating: 0, count: max(1, capacity)) }
    mutating func push(_ v: Double) {
        buf[head] = v; head = (head + 1) % buf.count; count = min(count + 1, buf.count)
    }
    /// Newest-last samples (up to `max`).
    func samples(_ max: Int) -> [Double] {
        let n = Swift.min(count, max)
        guard n > 0 else { return [] }
        return (0..<n).map { buf[(head - n + $0 + buf.count) % buf.count] }
    }
}

// MARK: - Providers

protocol MetricProvider: AnyObject {
    var id: ModuleID { get }
    var available: Bool { get }
    /// Sample on a background thread. Returns nil if momentarily unavailable.
    func sample() -> Metric?
}

/// CPU: aggregate + per-core utilization via host_processor_info tick deltas.
final class CPUProvider: MetricProvider {
    let id = ModuleID.cpu
    var available: Bool { true }
    private var prev: [(user: Double, sys: Double, idle: Double, nice: Double)] = []

    func sample() -> Metric? {
        guard let cur = Self.loads() else { return nil }
        defer { prev = cur }
        guard prev.count == cur.count, !prev.isEmpty else { return Metric(available: true, value: 0, short: "–%") }
        var cores: [Double] = []; var uSum = 0.0, sSum = 0.0, iSum = 0.0, tSum = 0.0
        for i in 0..<cur.count {
            let du = cur[i].user - prev[i].user, ds = cur[i].sys - prev[i].sys
            let dn = cur[i].nice - prev[i].nice, di = cur[i].idle - prev[i].idle
            let busy = du + ds + dn, total = busy + di
            cores.append(total > 0 ? busy / total : 0)
            uSum += du; sSum += ds + dn; iSum += di; tSum += total
        }
        let user = tSum > 0 ? uSum / tSum : 0, sys = tSum > 0 ? sSum / tSum : 0
        let idle = tSum > 0 ? iSum / tSum : 0, busy = 1 - idle
        var m = Metric(available: true, value: busy, short: "\(Int((busy * 100).rounded()))%")
        m.widthTemplate = "100%"
        m.rows = [(L("User"), pct(user)), (L("System"), pct(sys)), (L("Idle"), pct(idle)),
                  (L("Cores"), "\(HardwareInfo.shared.totalCores)")]
        m.cores = cores
        return m
    }
    private func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    static func loads() -> [(user: Double, sys: Double, idle: Double, nice: Double)]? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: Int(bitPattern: info))),
                              vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }
        let states = Int(CPU_STATE_MAX)
        var out: [(Double, Double, Double, Double)] = []
        for i in 0..<Int(count) {
            let b = i * states
            out.append((Double(info[b + Int(CPU_STATE_USER)]), Double(info[b + Int(CPU_STATE_SYSTEM)]),
                        Double(info[b + Int(CPU_STATE_IDLE)]), Double(info[b + Int(CPU_STATE_NICE)])))
        }
        return out
    }
}

/// Memory: unified-memory pool via host_statistics64 + hw.memsize + vm.swapusage.
final class MemoryProvider: MetricProvider {
    let id = ModuleID.memory
    var available: Bool { HardwareInfo.shared.memoryBytes > 0 }

    func sample() -> Metric? {
        let total = HardwareInfo.shared.memoryBytes
        guard total > 0 else { return nil }
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let page = Int64(vm_kernel_page_size)
        let wired = Int64(stats.wire_count) * page
        let compressed = Int64(stats.compressor_page_count) * page
        let active = Int64(stats.active_count) * page
        let free = Int64(stats.free_count + stats.inactive_count) * page
        let used = active + wired + compressed
        let ratio = Double(used) / Double(total)
        var m = Metric(available: true, value: ratio, short: "\(gb(used))/\(gb(total))")
        // Used never exceeds total, so the total's digit count bounds both sides.
        m.widthTemplate = "\(gb(total))/\(gb(total))"
        m.rows = [(L("Used"), bytes(used)), (L("Total"), bytes(total)), (L("Free"), bytes(free)),
                  (L("Wired"), bytes(wired)), (L("Compressed"), bytes(compressed)),
                  (L("Usage"), "\(Int((ratio * 100).rounded()))%")]
        if let sw = Self.swap() { m.rows.append((L("Swap"), "\(bytes(sw.used)) / \(bytes(sw.total))")) }
        return m
    }
    private func gb(_ b: Int64) -> String { "\(Int((Double(b) / 1_073_741_824).rounded()))G" }
    private func bytes(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .memory) }
    static func swap() -> (used: Int64, total: Int64)? {
        var x = xsw_usage(); var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &x, &size, nil, 0) == 0 else { return nil }
        return (Int64(x.xsu_used), Int64(x.xsu_total))
    }
}

/// Network: throughput via getifaddrs byte-counter deltas (non-loopback).
final class NetworkProvider: MetricProvider {
    let id = ModuleID.network
    var available: Bool { true }
    private var prevIn: Int64 = 0, prevOut: Int64 = 0
    private var prevTime = Date.timeIntervalSinceReferenceDate

    func sample() -> Metric? {
        let (inB, outB) = Self.counters()
        let now = Date.timeIntervalSinceReferenceDate
        let dt = max(0.001, now - prevTime)
        let dIn = max(0, Double(inB - prevIn)) / dt, dOut = max(0, Double(outB - prevOut)) / dt
        let first = prevIn == 0 && prevOut == 0
        prevIn = inB; prevOut = outB; prevTime = now
        let down = first ? 0 : dIn, up = first ? 0 : dOut
        // value carries combined throughput (bytes/s) so history graphs are meaningful;
        // it is not a 0…1 ratio, so graphs for network must auto-scale.
        var m = Metric(available: true, value: down + up, short: "↓\(rate(down)) ↑\(rate(up))")
        m.widthTemplate = "↓999.9M ↑999.9M"
        m.rows = [(L("Download"), "\(rate(down))/s"), (L("Upload"), "\(rate(up))/s"),
                  (L("Received"), bytes(inB)), (L("Sent"), bytes(outB))]
        return m
    }
    private func rate(_ bps: Double) -> String {
        if bps >= 1_000_000_000 { return String(format: "%.1fG", bps / 1_000_000_000) }
        if bps >= 1_000_000 { return String(format: "%.1fM", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0fK", bps / 1_000) }
        return "\(Int(bps))B"
    }
    private func bytes(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }
    static func counters() -> (Int64, Int64) {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return (0, 0) }
        defer { freeifaddrs(addrs) }
        var inB: Int64 = 0, outB: Int64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let ifa = p.pointee
            if ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifa.ifa_name)
                if !name.hasPrefix("lo"), let d = ifa.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    inB += Int64(d.pointee.ifi_ibytes); outB += Int64(d.pointee.ifi_obytes)
                }
            }
            ptr = ifa.ifa_next
        }
        return (inB, outB)
    }
}

/// Battery via IOKit power sources; unavailable on desktops (empty source list).
final class BatteryProvider: MetricProvider {
    let id = ModuleID.battery
    private(set) var available = true

    func sample() -> Metric? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef], !list.isEmpty else {
            available = false; return Metric(available: false, value: 0, short: "")
        }
        guard let desc = IOPSGetPowerSourceDescription(blob, list[0])?.takeUnretainedValue() as? [String: Any] else {
            available = false; return nil
        }
        available = true
        let cur = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let mx = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let pct = mx > 0 ? Int((Double(cur) / Double(mx) * 100).rounded()) : cur
        let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let ac = state == kIOPSACPowerValue
        var m = Metric(available: true, value: Double(pct) / 100, short: "\(pct)%")
        m.widthTemplate = "100%"
        m.rows = [(L("Charge"), "\(pct)%"),
                  (L("Status"), charging ? L("Charging") : (ac ? L("AC Power") : L("On Battery")))]
        if let t = desc[kIOPSTimeToEmptyKey] as? Int, !ac, t > 0 { m.rows.append((L("Time Remaining"), String(format: L("%lld min"), t))) }
        if let t = desc[kIOPSTimeToFullChargeKey] as? Int, charging, t > 0 { m.rows.append((L("Time to Full"), String(format: L("%lld min"), t))) }
        return m
    }
}

/// Disk capacity of the boot volume via statfs (slow-changing), plus live read/write
/// throughput via IOBlockStorageDriver byte-counter deltas.
final class DiskProvider: MetricProvider {
    let id = ModuleID.disk
    var available: Bool { true }
    private var prevRead: Int64 = 0, prevWrite: Int64 = 0
    private var prevTime = Date.timeIntervalSinceReferenceDate

    func sample() -> Metric? {
        var fs = statfs()
        guard statfs("/", &fs) == 0 else { return nil }
        let block = Int64(fs.f_bsize)
        let total = Int64(fs.f_blocks) * block
        let free = Int64(fs.f_bavail) * block
        let used = total - free
        guard total > 0 else { return nil }
        let ratio = Double(used) / Double(total)
        var m = Metric(available: true, value: ratio, short: "\(Int((ratio * 100).rounded()))%")
        m.widthTemplate = "100%"
        m.rows = [(L("Used"), bytes(used)), (L("Free"), bytes(free)), (L("Total"), bytes(total)),
                  (L("Usage"), "\(Int((ratio * 100).rounded()))%")]

        // Live throughput (bytes/s) from cumulative block-storage counters.
        let (rd, wr) = Self.ioCounters()
        let now = Date.timeIntervalSinceReferenceDate
        let dt = max(0.001, now - prevTime)
        let first = prevRead == 0 && prevWrite == 0
        let rRate = first ? 0 : max(0, Double(rd - prevRead)) / dt
        let wRate = first ? 0 : max(0, Double(wr - prevWrite)) / dt
        prevRead = rd; prevWrite = wr; prevTime = now
        if rd > 0 || wr > 0 {
            m.rows.append((L("Read"), "\(rate(rRate))/s"))
            m.rows.append((L("Write"), "\(rate(wRate))/s"))
        }
        return m
    }

    private func bytes(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }
    private func rate(_ bps: Double) -> String {
        if bps >= 1_000_000_000 { return String(format: "%.1f GB", bps / 1_000_000_000) }
        if bps >= 1_000_000 { return String(format: "%.1f MB", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f KB", bps / 1_000) }
        return "\(Int(bps)) B"
    }

    /// Summed read/write bytes across all IOBlockStorageDriver instances.
    static func ioCounters() -> (read: Int64, write: Int64) {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iter) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iter) }
        var r: Int64 = 0, w: Int64 = 0
        var svc = IOIteratorNext(iter)
        while svc != 0 {
            if let stats = IORegistryEntryCreateCFProperty(svc, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] {
                r += (stats["Bytes (Read)"] as? Int64) ?? 0
                w += (stats["Bytes (Write)"] as? Int64) ?? 0
            }
            IOObjectRelease(svc)
            svc = IOIteratorNext(iter)
        }
        return (r, w)
    }
}

/// GPU utilization via the IOAccelerator `PerformanceStatistics` dictionary
/// ("Device Utilization %"). Undocumented but unentitled; capability-gated —
/// stays unavailable (never faked) on hardware/OS where the key can't be read.
final class GPUProvider: MetricProvider {
    let id = ModuleID.gpu
    private(set) var available = false

    func sample() -> Metric? {
        guard let stats = Self.perfStats(), let dev = stats["Device Utilization %"] as? Int else {
            available = false
            return Metric(available: false, value: 0, short: "")
        }
        available = true
        var m = Metric(available: true, value: Double(dev) / 100, short: "\(dev)%")
        m.widthTemplate = "100%"
        m.rows = [(L("Usage"), "\(dev)%")]
        if let r = stats["Renderer Utilization %"] as? Int { m.rows.append((L("Renderer"), "\(r)%")) }
        if let t = stats["Tiler Utilization %"] as? Int { m.rows.append((L("Tiler"), "\(t)%")) }
        if let cores = Self.coreCount, cores > 0 { m.rows.append((L("Cores"), "\(cores)")) }
        return m
    }

    /// First IOAccelerator service exposing a readable "Device Utilization %".
    static func perfStats() -> [String: Any]? {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iter) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iter) }
        var result: [String: Any]?
        var svc = IOIteratorNext(iter)
        while svc != 0 {
            if result == nil,
               let props = IORegistryEntryCreateCFProperty(svc, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                   .takeRetainedValue() as? [String: Any], props["Device Utilization %"] != nil {
                result = props
            }
            IOObjectRelease(svc)
            svc = IOIteratorNext(iter)
        }
        return result
    }

    /// GPU core count (read once) from the IORegistry, if the property exists.
    static let coreCount: Int? = {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iter) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iter) }
        var svc = IOIteratorNext(iter)
        while svc != 0 {
            defer { IOObjectRelease(svc); svc = IOIteratorNext(iter) }
            if let n = IORegistryEntrySearchCFProperty(svc, kIOServicePlane, "gpu-core-count" as CFString,
                                                       kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)) as? Int {
                return n
            }
        }
        return nil
    }()
}

// MARK: - SMC (fans + temperatures)

/// Minimal AppleSMC reader (fan speeds + temperatures). Undocumented but unentitled;
/// used only through the capability-gated Sensors module — values are read live,
/// never synthesized, and a key that doesn't read is simply omitted.
final class SMC {
    static let shared = SMC()
    private var conn: io_connect_t = 0
    let opened: Bool

    private typealias Bytes32 = (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                                 UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8)
    private struct Vers { var major: UInt8 = 0; var minor: UInt8 = 0; var build: UInt8 = 0; var reserved: UInt8 = 0; var release: UInt16 = 0 }
    private struct PLimit { var version: UInt16 = 0; var length: UInt16 = 0; var cpu: UInt32 = 0; var gpu: UInt32 = 0; var mem: UInt32 = 0 }
    private struct KeyInfo { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0 }
    private struct Param {
        var key: UInt32 = 0; var vers = Vers(); var pLimit = PLimit(); var keyInfo = KeyInfo()
        var padding: UInt16 = 0; var result: UInt8 = 0; var status: UInt8 = 0; var data8: UInt8 = 0; var data32: UInt32 = 0
        var bytes: Bytes32 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private init() {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard svc != 0 else { opened = false; return }
        defer { IOObjectRelease(svc) }
        opened = IOServiceOpen(svc, mach_task_self_, 0, &conn) == kIOReturnSuccess
    }

    private static func fourCC(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }

    private func call(_ input: inout Param, _ output: inout Param) -> Bool {
        let size = MemoryLayout<Param>.stride
        var outSize = size
        return IOConnectCallStructMethod(conn, 2, &input, size, &output, &outSize) == kIOReturnSuccess
    }

    /// Read a numeric SMC key (fpe2/flt/sp78/ui8/ui16), decoded to a Double.
    func read(_ key: String) -> Double? {
        guard opened else { return nil }
        var info = Param(); info.key = Self.fourCC(key); info.data8 = 9   // key info
        var infoOut = Param()
        guard call(&info, &infoOut), infoOut.result == 0, infoOut.keyInfo.dataSize > 0 else { return nil }
        let size = Int(infoOut.keyInfo.dataSize), type = infoOut.keyInfo.dataType
        var rd = Param(); rd.key = Self.fourCC(key); rd.keyInfo.dataSize = UInt32(size); rd.data8 = 5   // read bytes
        var out = Param()
        guard call(&rd, &out), out.result == 0 else { return nil }
        var b = [UInt8]()
        for (i, ch) in Mirror(reflecting: out.bytes).children.enumerated() where i < size { b.append(ch.value as! UInt8) }
        switch type {
        case Self.fourCC("ui8 "), Self.fourCC("ui8"): return b.isEmpty ? nil : Double(b[0])
        case Self.fourCC("ui16"): return b.count >= 2 ? Double(UInt16(b[0]) << 8 | UInt16(b[1])) : nil
        case Self.fourCC("fpe2"): return b.count >= 2 ? Double(UInt16(b[0]) << 8 | UInt16(b[1])) / 4 : nil
        case Self.fourCC("sp78"): return b.count >= 2 ? Double(Int16(bitPattern: UInt16(b[0]) << 8 | UInt16(b[1]))) / 256 : nil
        case Self.fourCC("flt "), Self.fourCC("flt"):
            return b.count >= 4 ? Double(Float(bitPattern: UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24)) : nil
        default: return nil
        }
    }
}

/// Sensors via SMC: hottest readable temperature as the headline value, with per-sensor
/// temperatures and fan speeds in the popover. Capability-gated — unavailable (never
/// faked) when SMC can't be opened or exposes neither a temperature nor a fan.
final class SensorsProvider: MetricProvider {
    let id = ModuleID.sensors
    private(set) var available = false

    /// Conservatively labelled temperature keys (only ones we can name with confidence;
    /// unreadable keys are skipped). Values are filtered to a plausible 1…130 °C range.
    private let tempKeys: [(key: String, label: String)] = [
        ("TB0T", L("Battery")), ("Ts0P", L("Enclosure")), ("Ts1P", L("Enclosure 2")),
        ("TW0P", L("Wi-Fi")), ("TA0P", L("Ambient")), ("TH0P", L("SSD")), ("Tm0P", L("Mainboard")),
    ]

    func sample() -> Metric? {
        guard SMC.shared.opened else { available = false; return Metric(available: false, value: 0, short: "") }
        var temps: [(String, Double)] = []
        for t in tempKeys { if let v = SMC.shared.read(t.key), v > 1, v < 130 { temps.append((t.label, v)) } }
        let fanCount = Int(SMC.shared.read("FNum") ?? 0)
        var fans: [Double] = []
        for i in 0..<max(0, min(fanCount, 8)) { if let r = SMC.shared.read("F\(i)Ac"), r >= 0 { fans.append(r) } }

        guard !temps.isEmpty || !fans.isEmpty else { available = false; return Metric(available: false, value: 0, short: "") }
        available = true

        var m: Metric
        if let maxTemp = temps.map(\.1).max() {
            m = Metric(available: true, value: min(1, maxTemp / 100), short: "\(Int(maxTemp.rounded()))°")
            m.widthTemplate = "999°"
        } else {
            let rpm = fans.max() ?? 0
            m = Metric(available: true, value: 0, short: "\(Int(rpm)) rpm")
            m.widthTemplate = "9999 rpm"
        }
        m.rows = temps.map { ($0.0, "\(Int($0.1.rounded()))°C") }
        for (i, r) in fans.enumerated() { m.rows.append((String(format: L("Fan %lld"), i + 1), "\(Int(r)) rpm")) }
        return m
    }
}

// MARK: - Central service

final class MonitorService {
    static let shared = MonitorService()
    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.peachcommander.sysmon", qos: .utility)
    private let providers: [ModuleID: MetricProvider]
    private(set) var metrics: [ModuleID: Metric] = [:]
    private var history: [ModuleID: Ring] = [:]
    private var observers: [ObjectIdentifier: () -> Void] = [:]
    private var sampling = false

    private init() {
        providers = [.cpu: CPUProvider(), .gpu: GPUProvider(), .memory: MemoryProvider(),
                     .network: NetworkProvider(), .battery: BatteryProvider(), .disk: DiskProvider(),
                     .sensors: SensorsProvider()]
        for id in providers.keys { history[id] = Ring(capacity: 1800) }   // 30 min @ 1 s
    }

    /// Which modules are actually available on this machine (capability gate).
    func isAvailable(_ id: ModuleID) -> Bool { providers[id]?.available ?? false }

    func addObserver(_ token: AnyObject, _ block: @escaping () -> Void) {
        observers[ObjectIdentifier(token)] = block
        startIfNeeded()
    }
    func removeObserver(_ token: AnyObject) {
        observers.removeValue(forKey: ObjectIdentifier(token))
        if observers.isEmpty { stop() }
    }

    func history(_ id: ModuleID, max: Int) -> [Double] { history[id]?.samples(max) ?? [] }

    private func startIfNeeded() {
        guard timer == nil, ConfigStore.shared.config.enabled else { return }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    func restart() { stop(); startIfNeeded(); observers.values.forEach { $0() } }
    private func stop() { timer?.invalidate(); timer = nil }

    private func tick() {
        guard !sampling, ConfigStore.shared.config.enabled else { return }
        // Only sample modules that are enabled in config AND available.
        let active = ConfigStore.shared.config.modules
            .filter { $0.enabled }.map(\.id)
            .filter { providers[$0] != nil }
        sampling = true
        let provs = active.compactMap { id in providers[id].map { (id, $0) } }
        queue.async { [weak self] in
            var results: [ModuleID: Metric] = [:]
            for (id, p) in provs { if let m = p.sample() { results[id] = m } }
            Task { @MainActor in
                guard let self else { return }
                self.sampling = false
                for (id, m) in results {
                    self.metrics[id] = m
                    if m.available { self.history[id]?.push(m.value) }
                }
                self.observers.values.forEach { $0() }
            }
        }
    }
}

// MARK: - Small UI helpers

enum Palette {
    static func color(_ hex: String) -> NSColor {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return .secondaryLabelColor }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

/// Draw a sparkline path into `rect` (flipped coords). `maxValue` 0 → auto-scale
/// to the sample maximum (for open-ended metrics like network throughput);
/// otherwise values are normalized against it (e.g. 1.0 for 0…1 utilization).
func drawSparkline(_ samples: [Double], in rect: NSRect, color: NSColor, maxValue: Double, lineWidth: CGFloat = 1.5) {
    guard samples.count > 1 else { return }
    let mx = maxValue > 0 ? maxValue : Swift.max(samples.max() ?? 1, 0.000001)
    let path = NSBezierPath(); path.lineWidth = lineWidth
    let n = samples.count
    for (i, v) in samples.enumerated() {
        let x = rect.minX + rect.width * CGFloat(i) / CGFloat(n - 1)
        let y = rect.maxY - rect.height * CGFloat(max(0, min(1, v / mx)))
        if i == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
    }
    color.setStroke(); path.stroke()
}

/// A tiny history sparkline.
final class Sparkline: NSView {
    var samples: [Double] = [] { didSet { needsDisplay = true } }
    var color: NSColor = .systemGreen
    var maxValue: Double = 1.0 { didSet { needsDisplay = true } }   // 0 → auto-scale
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.quaternaryLabelColor.withAlphaComponent(0.25).setFill(); bounds.fill()
        drawSparkline(samples, in: bounds, color: color, maxValue: maxValue)
    }
}

// MARK: - Titlebar chips view

final class TitlebarMonitorView: NSView {
    private var chips: [(rect: NSRect, id: ModuleID)] = []
    private var popover: NSPopover?
    private var popoverModule: ModuleID?
    var openInPanel: ((Int, String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        MonitorService.shared.addObserver(self) { [weak self] in self?.refresh() }
        ConfigStore.shared.onChange = { [weak self] in MonitorService.shared.restart(); self?.refresh() }
        syncWidth()
    }
    required init?(coder: NSCoder) { fatalError() }
    func teardown() { MonitorService.shared.removeObserver(self) }

    /// Drive the accessory width by our own frame (TAMIC): the titlebar accessory
    /// measures the view's fittingSize once, so we size the frame directly and let
    /// the accessory track it.
    private func syncWidth() {
        let w = max(1, layoutChips(dryRun: true))
        let h = frame.height > 0 ? frame.height : 28
        if abs(frame.width - w) > 0.5 { frame = NSRect(x: frame.minX, y: frame.minY, width: w, height: h) }
    }

    override var isFlipped: Bool { true }

    /// Ordered, enabled + available modules.
    private var visibleModules: [ModuleConfig] {
        guard ConfigStore.shared.config.enabled else { return [] }
        return ConfigStore.shared.config.modules.filter { $0.enabled && MonitorService.shared.isAvailable($0.id)
            && (MonitorService.shared.metrics[$0.id]?.available ?? true) }
    }

    private var scale: CGFloat { CGFloat(ConfigStore.shared.config.scale) }
    private func font(_ bold: Bool = false) -> NSFont {
        .monospacedDigitSystemFont(ofSize: 11 * scale, weight: bold ? .semibold : .regular)
    }

    private func refresh() {
        // Value widths are stable (monospacedDigit) but the module set can change.
        syncWidth()
        needsDisplay = true
        if let m = popoverModule, let cv = popover?.contentViewController as? PopoverContentController {
            cv.update(metric: MonitorService.shared.metrics[m])
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: max(1, layoutChips(dryRun: true)), height: 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        _ = layoutChips(dryRun: false)
        for chip in chips {
            guard let cfg = configFor(chip.id) else { continue }
            let metric = MonitorService.shared.metrics[chip.id] ?? Metric(available: true, value: 0, short: "")
            drawChip(cfg: cfg, metric: metric, in: chip.rect, hovered: chip.id == popoverModule)
        }
    }

    private func configFor(_ id: ModuleID) -> ModuleConfig? { ConfigStore.shared.config.modules.first { $0.id == id } }

    /// Compute chip rects (and total width). `dryRun` avoids storing when sizing.
    @discardableResult
    private func layoutChips(dryRun: Bool) -> CGFloat {
        var frames: [(NSRect, ModuleID)] = []
        var x: CGFloat = 6
        let h = bounds.height > 0 ? bounds.height : 28
        let attrs: [NSAttributedString.Key: Any] = [.font: font(true)]
        for cfg in visibleModules {
            // Reserve the widest the value can get (monospacedDigit template) so the
            // layout stays put as digit counts change; never narrower than the text
            // actually drawn (guards a value that outgrows its template).
            let reserved = (chipWidthText(cfg) as NSString).size(withAttributes: attrs).width
            let actual = (chipText(cfg) as NSString).size(withAttributes: attrs).width
            let graphW: CGFloat = cfg.showGraph ? graphChipWidth + 4 * scale : 0
            let w = max(reserved, actual) + 22 * scale + graphW
            frames.append((NSRect(x: x, y: 0, width: w, height: h), cfg.id))
            x += w + 8 * scale
        }
        if !dryRun { chips = frames }
        return x
    }

    /// Text drawn in the chip (label + current value).
    private func chipText(_ cfg: ModuleConfig) -> String {
        chipText(cfg, value: MonitorService.shared.metrics[cfg.id]?.short ?? "")
    }

    /// Text used only to reserve a stable chip width (label + value template).
    private func chipWidthText(_ cfg: ModuleConfig) -> String {
        let m = MonitorService.shared.metrics[cfg.id]
        let template = (m?.widthTemplate.isEmpty == false) ? m!.widthTemplate : (m?.short ?? "")
        return chipText(cfg, value: template)
    }

    private func chipText(_ cfg: ModuleConfig, value rawValue: String) -> String {
        let value = cfg.showValue ? rawValue : ""
        let label = cfg.showLabel ? cfg.id.label : ""
        return [label, value].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func drawChip(cfg: ModuleConfig, metric: Metric, in rect: NSRect, hovered: Bool) {
        if hovered {
            NSColor.secondaryLabelColor.withAlphaComponent(0.15).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 4), xRadius: 4, yRadius: 4).fill()
        }
        var x = rect.minX + 4 * scale
        // Accent dot.
        let dot = NSRect(x: x, y: rect.midY - 3, width: 6, height: 6)
        let accent = Palette.color(cfg.colorHex)
        accent.setFill(); NSBezierPath(ovalIn: dot).fill()
        x += 10 * scale
        let text = chipText(cfg)
        let attrs: [NSAttributedString.Key: Any] = [.font: font(true), .foregroundColor: NSColor.labelColor]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: x, y: rect.midY - size.height / 2), withAttributes: attrs)
        // Optional inline history sparkline in the chip's reserved trailing slot.
        if cfg.showGraph {
            let reservedW = max((chipWidthText(cfg) as NSString).size(withAttributes: attrs).width, size.width)
            let gx = x + reservedW + 4 * scale
            let gRect = NSRect(x: gx, y: rect.midY - 6, width: graphChipWidth, height: 12)
            drawSparkline(MonitorService.shared.history(cfg.id, max: 60), in: gRect,
                          color: accent, maxValue: cfg.id.graphMax, lineWidth: 1)
        }
    }

    private var graphChipWidth: CGFloat { 24 * scale }

    // MARK: Click → popover

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let chip = chips.first(where: { $0.rect.contains(p) }) else { return }
        showPopover(for: chip.id, at: chip.rect)
    }

    private func showPopover(for id: ModuleID, at rect: NSRect) {
        popover?.close()
        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentViewController = PopoverContentController(module: id, openInPanel: openInPanel)
        pop.delegate = popoverDelegate
        popover = pop; popoverModule = id
        (pop.contentViewController as? PopoverContentController)?.update(metric: MonitorService.shared.metrics[id])
        pop.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        needsDisplay = true
    }

    private lazy var popoverDelegate = PopoverDelegate { [weak self] in self?.popoverModule = nil; self?.needsDisplay = true }
}

final class PopoverDelegate: NSObject, NSPopoverDelegate {
    private let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func popoverDidClose(_ notification: Notification) { onClose() }
}

// MARK: - Popover content

final class PopoverContentController: NSViewController {
    private let module: ModuleID
    private let openInPanel: ((Int, String) -> Void)?
    private let stack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let bigValue = NSTextField(labelWithString: "")
    private let spark = Sparkline()
    private let rowsStack = NSStackView()
    private let coreGrid = NSStackView()
    private let coreScroll = NSScrollView()

    init(module: ModuleID, openInPanel: ((Int, String) -> Void)?) {
        self.module = module; self.openInPanel = openInPanel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 10))
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bigValue.font = .monospacedDigitSystemFont(ofSize: 26, weight: .regular)
        spark.color = Palette.color(ConfigStore.shared.config.modules.first { $0.id == module }?.colorHex ?? "#8E8E93")
        spark.maxValue = module.graphMax
        spark.translatesAutoresizingMaskIntoConstraints = false
        spark.heightAnchor.constraint(equalToConstant: 34).isActive = true
        spark.widthAnchor.constraint(equalToConstant: 272).isActive = true
        rowsStack.orientation = .vertical; rowsStack.alignment = .leading; rowsStack.spacing = 3
        coreGrid.orientation = .vertical; coreGrid.spacing = 2
        coreScroll.documentView = coreGrid; coreScroll.hasVerticalScroller = true; coreScroll.drawsBackground = false
        coreScroll.translatesAutoresizingMaskIntoConstraints = false
        coreScroll.heightAnchor.constraint(equalToConstant: 120).isActive = true
        coreScroll.widthAnchor.constraint(equalToConstant: 272).isActive = true

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(bigValue)
        stack.addArrangedSubview(sectionLabel(L("HISTORY")))
        stack.addArrangedSubview(spark)
        stack.addArrangedSubview(sectionLabel(L("DETAILS")))
        stack.addArrangedSubview(rowsStack)
        if module == .cpu {
            stack.addArrangedSubview(sectionLabel(L("CORE LOAD")))
            stack.addArrangedSubview(coreScroll)
        }
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
        titleLabel.stringValue = module.label
    }

    private func sectionLabel(_ s: String) -> NSTextField {
        let f = NSTextField(labelWithString: s)
        f.font = .systemFont(ofSize: 9, weight: .semibold); f.textColor = .tertiaryLabelColor
        return f
    }

    func update(metric: Metric?) {
        guard isViewLoaded else { return }
        bigValue.stringValue = metric?.short ?? "—"
        spark.samples = MonitorService.shared.history(module, max: 90)
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (k, v) in (metric?.rows ?? []) {
            let row = NSStackView(); row.orientation = .horizontal; row.distribution = .fill
            let key = NSTextField(labelWithString: k); key.font = .systemFont(ofSize: 11); key.textColor = .secondaryLabelColor
            let val = NSTextField(labelWithString: v); val.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            val.alignment = .right
            row.addArrangedSubview(key); row.addArrangedSubview(val)
            val.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: 272).isActive = true
            rowsStack.addArrangedSubview(row)
        }
        if module == .cpu { updateCores(metric?.cores ?? []) }
    }

    private func updateCores(_ cores: [Double]) {
        coreGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let hw = HardwareInfo.shared
        for (i, u) in cores.enumerated() {
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 6
            let tag = hw.isPerformanceCore(i) ? "P" : (hw.eCores > 0 ? "E" : "")
            let name = NSTextField(labelWithString: "\(tag)\(i + 1)")
            name.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular); name.textColor = .secondaryLabelColor
            name.widthAnchor.constraint(equalToConstant: 28).isActive = true
            let bar = UtilBar(); bar.value = u
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.widthAnchor.constraint(equalToConstant: 180).isActive = true
            bar.heightAnchor.constraint(equalToConstant: 8).isActive = true
            let val = NSTextField(labelWithString: "\(Int((u * 100).rounded()))%")
            val.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular); val.textColor = .secondaryLabelColor
            row.addArrangedSubview(name); row.addArrangedSubview(bar); row.addArrangedSubview(val)
            coreGrid.addArrangedSubview(row)
        }
    }
}

/// A slim utilization bar.
final class UtilBar: NSView {
    var value: Double = 0 { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.quaternaryLabelColor.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
        let w = bounds.width * CGFloat(max(0, min(1, value)))
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: w, height: bounds.height), xRadius: 3, yRadius: 3).fill()
    }
}

// MARK: - Settings window

final class MonitorSettingsWindow: NSObject, NSWindowDelegate {
    static let shared = MonitorSettingsWindow()
    private var window: NSWindow?

    func present(over parent: NSWindow?) {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = L("System Monitor"); w.delegate = self; w.center()
        w.contentView = SettingsView()
        window = w
        w.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { window = nil }
}

final class SettingsView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let enableCheck = NSButton(checkboxWithTitle: L("Show system monitor in title bar"), target: nil, action: nil)
    private let profilePopup = NSPopUpButton()
    private let table = NSTableView()
    private var modules: [ModuleConfig] { ConfigStore.shared.config.modules }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        enableCheck.state = ConfigStore.shared.config.enabled ? .on : .off
        enableCheck.target = self; enableCheck.action = #selector(toggleEnabled)
        enableCheck.translatesAutoresizingMaskIntoConstraints = false

        profilePopup.addItems(withTitles: [L("Minimal"), L("Medium"), L("Maximal")])
        profilePopup.selectItem(at: ["minimal", "medium", "maximal"].firstIndex(of: ConfigStore.shared.config.profile) ?? 1)
        profilePopup.target = self; profilePopup.action = #selector(chooseProfile)
        profilePopup.translatesAutoresizingMaskIntoConstraints = false
        let profLabel = NSTextField(labelWithString: L("Profile:")); profLabel.translatesAutoresizingMaskIntoConstraints = false

        // Widths (+ tight intercell spacing) sum small enough to fit both the
        // standalone window and the narrower embedded pane in the host Settings dialog.
        table.intercellSpacing = NSSize(width: 2, height: 2)
        for (id, title, w) in [("on", "", CGFloat(22)), ("mod", L("Module"), 78), ("val", L("Value"), 38),
                               ("gr", L("History"), 48), ("col", L("Color"), 40), ("ord", "", 28)] {
            let c = NSTableColumn(identifier: .init(id)); c.title = title; c.width = w; table.addTableColumn(c)
        }
        table.dataSource = self; table.delegate = self; table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 26
        table.columnAutoresizingStyle = .noColumnAutoresizing   // keep fixed widths; don't expand & clip the last column
        // Drag & drop row reordering (module order).
        table.registerForDraggedTypes([.string])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.borderType = .bezelBorder

        addSubview(enableCheck); addSubview(profLabel); addSubview(profilePopup); addSubview(scroll)
        NSLayoutConstraint.activate([
            enableCheck.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            enableCheck.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            profLabel.topAnchor.constraint(equalTo: enableCheck.bottomAnchor, constant: 14),
            profLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            profilePopup.centerYAnchor.constraint(equalTo: profLabel.centerYAnchor),
            profilePopup.leadingAnchor.constraint(equalTo: profLabel.trailingAnchor, constant: 8),
            profilePopup.widthAnchor.constraint(equalToConstant: 140),
            scroll.topAnchor.constraint(equalTo: profilePopup.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }

    @objc private func toggleEnabled() {
        ConfigStore.shared.update { $0.enabled = enableCheck.state == .on }
    }
    @objc private func chooseProfile() {
        let p = ["minimal", "medium", "maximal"][profilePopup.indexOfSelectedItem]
        ConfigStore.shared.applyProfile(p)
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { modules.count }

    // MARK: Drag & drop reordering

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem(); item.setString(String(row), forType: .string); return item
    }
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int, proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
        op == .above ? .move : []
    }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation op: NSTableView.DropOperation) -> Bool {
        guard let s = info.draggingPasteboard.pasteboardItems?.first?.string(forType: .string),
              let src = Int(s), src != row, src != row - 1 else { return false }
        ConfigStore.shared.update { cfg in
            guard cfg.modules.indices.contains(src) else { return }
            let m = cfg.modules.remove(at: src)
            cfg.modules.insert(m, at: src < row ? row - 1 : row)
        }
        table.reloadData()
        return true
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard modules.indices.contains(row) else { return nil }
        let m = modules[row]
        let available = MonitorService.shared.isAvailable(m.id)
        switch tableColumn?.identifier.rawValue {
        case "on":
            let b = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleModule(_:)))
            b.state = m.enabled ? .on : .off; b.tag = row; b.isEnabled = available
            return b
        case "mod":
            let f = NSTextField(labelWithString: m.id.label + (available ? "" : L(" (n/a)")))
            f.textColor = available ? .labelColor : .tertiaryLabelColor
            return f
        case "val":
            let b = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleValue(_:)))
            b.state = m.showValue ? .on : .off; b.tag = row; return b
        case "gr":
            let b = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleGraph(_:)))
            b.state = m.showGraph ? .on : .off; b.tag = row; return b
        case "col":
            let well = NSColorWell(); well.color = Palette.color(m.colorHex); well.tag = row
            well.target = self; well.action = #selector(chooseColor(_:))
            return well
        case "ord":
            let up = NSButton(title: "▲", target: self, action: #selector(moveModuleUp(_:))); up.tag = row; up.bezelStyle = .roundRect
            return up
        default: return nil
        }
    }

    private func setModule(_ row: Int, _ mut: (inout ModuleConfig) -> Void) {
        ConfigStore.shared.update { cfg in if cfg.modules.indices.contains(row) { mut(&cfg.modules[row]) } }
    }
    @objc private func toggleModule(_ s: NSButton) { setModule(s.tag) { $0.enabled = s.state == .on } }
    @objc private func toggleValue(_ s: NSButton) { setModule(s.tag) { $0.showValue = s.state == .on } }
    @objc private func toggleGraph(_ s: NSButton) { setModule(s.tag) { $0.showGraph = s.state == .on } }
    @objc private func chooseColor(_ w: NSColorWell) { setModule(w.tag) { $0.colorHex = w.color.hexString } }
    @objc private func moveModuleUp(_ s: NSButton) {
        let row = s.tag; guard row > 0 else { return }
        ConfigStore.shared.update { $0.modules.swapAt(row, row - 1) }
        table.reloadData()
    }
}

extension NSColor {
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}
