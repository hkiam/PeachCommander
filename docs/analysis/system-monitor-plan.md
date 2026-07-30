# Titlebar System Monitor — analysis, capability matrix, integration plan

External plugin (`SystemMonitor.ptxplugin`) showing compact live monitoring chips
in the window titlebar, each opening a native NSPopover with details. Built in
increments following the brief's phases.

## Phase 1 — existing architecture (verified)

- **Titlebar**: standard system titlebar, no custom titlebar/toolbar/accessory
  today (MainWindowController.start / MainWindow). → attach an
  `NSTitlebarAccessoryViewController(layoutAttribute: .trailing)` in `start()`.
- **View containers**: `ViewContainerRegistry` mounts plugin views into a
  free-form named container (matched by string equality; no whitelist). "sidebar"
  is wired to the preview panel. → add a `"titlebar"` container the same way; the
  plugin declares `container: "titlebar"` in Info.plist (no model change).
- **Data → view push**: `ViewContainerRegistry.notifyViews(key,value)` already
  fans `PcNotifyView` to live plugin views on the main thread.
- **Settings**: AppKit `SettingsWindowController` (source-list `SettingsPage` enum
  + `SettingsSnapshot` + onSetBool/onSetString → `ConfigStore`).
- **Persistence**: `ConfigStore` actor over `peachcmd.ini` (host settings);
  plugins self-persist JSON under `~/Library/Application Support/PeachCommander/<plugin>/`.
- **Concurrency**: `@MainActor` UI; heavy work on background Task/queue; 1 s
  `Timer` precedent (previewTimer). `ByteSize` formatter reusable (in-process).
- **No existing CPU/GPU/mem/net/battery code** — providers are net-new. Plugins
  are in-process dylibs, so they can call mach/sysctl/IOKit + build NSPopover
  directly; the only host help needed is the titlebar mount point.

## Phase 2 — capability matrix (macOS APIs, no private-API core dependency)

| Metric | Source | Public/stable | Apple Silicon | Intel | Notes / fallback |
|---|---|---|---|---|---|
| CPU total + per-core % | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` (delta of user/sys/idle/nice ticks) | yes (mach) | yes | yes | P/E split via `sysctl hw.perflevelN.logicalcpu` on AS; degrade to flat list otherwise |
| CPU core topology | `sysctlbyname hw.perflevel0/1.logicalcpu`, `hw.logicalcpu` | yes | yes (P/E) | flat | never assume a fixed count |
| Chip name | `sysctlbyname machdep.cpu.brand_string` / `hw.model` | yes | yes | yes | |
| RAM used/free/total | `host_statistics64(HOST_VM_INFO64)` (active/wired/compressed/free) + `hw.memsize` | yes (mach) | yes (unified) | yes | Unified memory: report one pool, don't split CPU/GPU |
| Memory pressure | `host_statistics64` + kern; simple = used ratio; precise pressure via `DISPATCH_SOURCE_TYPE_MEMORYPRESSURE` | yes | yes | yes | start with used-ratio bands |
| Swap | `sysctlbyname vm.swapusage` (`xsw_usage`) | yes | yes | yes | |
| Disk capacity | `URLResourceValues` volume keys (already used by `Volume`) | yes | yes | yes | slow interval |
| Disk I/O throughput | IOKit `IOBlockStorageDriver` stats (`Statistics` dict) | semi (IOKit, no entitlement) | yes | yes | capability-gate; **deferred** |
| Network throughput | `getifaddrs` → `if_data` in/out byte counters (delta) | yes | yes | yes | pick default route iface |
| Battery | IOKit `IOPSCopyPowerSourcesInfo` / `IOPSGetProvidingPowerSourceType` | yes (IOKit.ps) | yes | yes | absent on desktops → module unavailable |
| GPU utilization | IOKit `IOAccelerator` `PerformanceStatistics` (Device Utilization %) | **semi-private** (IOKit, unentitled but undocumented) | yes | varies | capability-gate; show only if the key reads; **deferred**, never faked |
| GPU cores | `sysctl`/`IORegistry gpu-core-count` | semi | yes | n/a | show only if read |
| Sensors (temp/fan) | SMC (`AppleSMC`) / IOHID | **private/unstable** | yes | yes | **not** a core dependency; capability-gated, off by default; **deferred** |

Decision: this increment ships the **public-API providers** (CPU, Memory, Swap,
Network, Battery, Disk capacity). GPU, Disk-I/O and Sensors are **capability-gated
and reported unavailable** until implemented behind their IOKit/SMC reads — per
the brief, no simulated values.

## Integration plan (minimally invasive)

**Host (small):**
1. `MainWindowController.start()` — create an `NSTitlebarAccessoryViewController`
   (trailing) whose view is a flipped container; `addTitlebarAccessoryViewController`.
2. Register `ViewContainerRegistry` container `"titlebar"` whose mount closure puts
   the (single) provider view into the accessory container; refresh alongside
   "sidebar".
3. No ABI change needed (reuses PcMakeView/PcCloseView/PcNotifyView + the existing
   `presentSidebarView`-style is not needed; the titlebar view is always mounted
   when enabled via `when`). Enable/disable via the plugin's own config +
   `notifyViews`.

**Plugin `SystemMonitor` (net-new, self-contained):**
- `MonitorService`: one 1 s timer (main), samples providers on a background queue,
  publishes current metrics + per-metric ring-buffer history; drives the titlebar
  view and any open popover from the same data.
- `HardwareInfo`: chip, CPU P/E topology, RAM, (GPU cores if readable).
- Providers conform to a `Provider` protocol advertising capabilities
  (`supportsTotalUtilization`, `supportsPerCore`, `supportsHistory`, …).
- `TitlebarMonitorView`: space-adaptive chips (SF Symbol + monospacedDigit value +
  optional label/graph/accent), click → `NSPopover` anchored to the chip.
- Detail popovers share a layout; CPU popover first (total/user/sys/idle/cores +
  per-core bars + history), then the rest.
- Config (enable, scale, profile Minimal/Mittel/Maximal, per-module order/flags/
  color) persisted as JSON under `…/PeachCommander/systemmonitor/config.json`;
  a config command (Commands ▸ System Monitor…) opens the plugin's settings.

**Phasing:** (this increment) host seam + MonitorService + CPU/Memory/Network/
Battery/Disk-capacity providers + titlebar chips + CPU popover + config/persist +
profiles. (next) remaining popovers, GPU/Disk-I/O/Sensors behind capability reads,
full drag&drop settings UI, per-core P/E grouping polish.
