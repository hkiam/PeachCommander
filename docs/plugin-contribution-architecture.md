# Plugin Contribution Architecture (SPEC-013, backlog item 29)

Status: DESIGN. Supersedes the ad-hoc, hard-wired way tools reach the UI. Goal:
a plugin can extend the application at nearly any functional and visual seam —
main menu, context menus, keybindings, side/preview areas — and its **entire
presence is driven by the plugin itself**. When a plugin is disabled or removed,
every trace of it disappears *without any core code running*. Nothing plugin-
specific remains hard-wired in the base app.

## Approved decisions

1. **Hiding, not overriding (first pass).** Plugins add their own entries and may
   *hide* existing entries (by stable command id). Arbitrary override/replacement
   of built-in commands and plugin-vs-plugin precedence battles are out of scope
   for v1 (the model leaves room to add them later).
2. **The whole menu is contribution-driven.** The built-in menu bar is expressed
   as *built-in contributions* through the same registry that plugins use. There
   is no second, static menu-building path. This fixes the class of bug where a
   menu item exists independently of the feature behind it (the Uninstaller bug).
3. **First surfaces:** menu bar, context menus, keybindings, and **one** view
   container (the side panel) as the reference. Other containers (preview,
   status bar, toolbar, bottom bar) follow the identical pattern afterwards.

## Layers

```
 Manifest (Info.plist)  ──parse──►  ContributionModel      (pure, PCPluginHost)
      declares WHAT + WHERE                                  │
                                                             ▼
 dylib (C-ABI)          ──behavior──►  ContributionRegistry  (@MainActor, PCApp)
      PcRunCommand / PcMakeView            aggregates ENABLED plugins + built-ins
                                                             │  emits change events
                          ┌──────────────────┬──────────────┼───────────────┐
                          ▼                  ▼               ▼               ▼
                    MenuBuilder      ContextMenuBuilder  KeybindingReg  ViewContainerReg
                     (menu bar)        (per surface)                     (side panel, …)
                          └──────── WhenEvaluator (context snapshot) ────────┘
                                            │
                                     CommandDispatcher
                              built-in handler │ plugin → PcRunCommand
```

## Manifest: `PCContributions`

A plugin's Info.plist gains a top-level `PCContributions` dict. It is orthogonal
to `PCPluginType` — a `pfx` file-system plugin may also contribute menus/views.
All ids are plugin-namespaced (reverse-DNS) to avoid collisions.

```xml
<key>PCContributions</key>
<dict>
  <!-- Named actions the plugin exposes; menus/keys/context refer to these. -->
  <key>commands</key>
  <array>
    <dict>
      <key>id</key>      <string>com.pc.uninstaller.uninstall</string>
      <key>title</key>   <string>Uninstall Application…</string>
      <key>category</key><string>Tools</string>        <!-- optional -->
    </dict>
  </array>

  <!-- Main menu-bar placements. `menu` is a menu path; `group` clusters items
       (separators are drawn BETWEEN groups); `order` sorts within a group.
       A slash-separated path nests submenus: "Commands/Git" places the item in
       a "Git" submenu inside the top-level Commands menu (created on first use;
       items sharing the path share the submenu). -->
  <key>menus</key>
  <array>
    <dict>
      <key>command</key><string>com.pc.uninstaller.uninstall</string>
      <key>menu</key>   <string>File</string>          <!-- or "File/Export" for a submenu -->
      <key>group</key>  <string>2_tools</string>
      <key>order</key>  <integer>100</integer>
      <key>when</key>   <string>cursorIsApp</string>    <!-- optional visibility/enable expr -->
    </dict>
  </array>

  <!-- Context-menu placements, keyed by a well-known surface id. The optional
       `submenu` groups items sharing that title under one nested menu in the
       surface (e.g. "Git") instead of listing them directly. -->
  <key>contextMenus</key>
  <array>
    <dict>
      <key>command</key><string>com.pc.uninstaller.uninstall</string>
      <key>surface</key><string>panel.item</string>    <!-- panel.item | panel.background | tab | drivebar -->
      <key>submenu</key><string>Git</string>           <!-- optional: group under a nested menu -->
      <key>group</key>  <string>9_plugins</string>
      <key>when</key>   <string>cursorIsApp</string>
    </dict>
  </array>

  <!-- Keybindings. -->
  <key>keybindings</key>
  <array>
    <dict><key>command</key><string>com.pc.uninstaller.uninstall</string>
          <key>key</key><string>cmd+shift+u</string>
          <key>when</key><string>cursorIsApp</string></dict>
  </array>

  <!-- Embedded views in a named host container. Behavior via PcMakeView. -->
  <key>views</key>
  <array>
    <dict><key>id</key><string>com.pc.treemap.view</string>
          <key>container</key><string>sidebar</string> <!-- sidebar | preview | bottombar -->
          <key>title</key><string>Disk Map</string>
          <key>when</key><string>panelScheme == "file"</string></dict>
  </array>

  <!-- Additive hiding of built-in / other entries by command id. -->
  <key>hides</key>
  <array>
    <dict><key>command</key><string>com.pc.builtin.someCommand</string>
          <key>when</key><string>true</string></dict>
  </array>
</dict>
```

### Grouping & ordering (VS Code-style)

Items carry `group` (string) and `order` (int). Within a menu, items are sorted
by group, then order; a separator is inserted between adjacent groups. Built-in
groups get low-sorting names (`1_navigation`, `2_tools`, …) so plugins slot in
predictably (`9_plugins` = end). This gives deterministic placement without
plugins needing to know absolute indices.

## `when` expression language

A small, host-evaluated boolean grammar (no dylib call — works for disabled
plugins and every menu-open without IPC). Evaluated against a `ContributionContext`
snapshot taken when a menu opens / key is pressed / view visibility is recomputed.

- Context keys: `cursorPath`, `cursorName`, `cursorExt`, `cursorIsDir`,
  `cursorIsApp`, `selectionCount`, `hasSelection`, `panelScheme`, `panelPath`,
  `activeSide` (`left`/`right`), `focusedControl`.
- Operators: `==` `!=` `=~` (regex) `startswith` `endswith` `contains`
  `>` `<` `>=` `<=` `&&` `||` `!` `( )`, literals `true`/`false`, string/number.
- Example: `cursorIsApp && selectionCount <= 1`, `cursorExt in ("log","txt")`.
- Absent `when` ⇒ always visible & enabled.

Pure and unit-testable (lexer → parser → evaluator), lives in PCPluginHost.

## C-ABI (SDK: `contrib.h`, on top of `pc_common.h`)

Command/view behavior is id-based (manifest declares placement; the dylib only
executes). This supersedes PTX's index-based `PtxGetToolCount/Info/Execute`.

```c
int   PcGetApiVersion(void);                                   /* handshake */

/* Run a declared command. `services` is the unified host table. */
void  PcRunCommand(const char *commandId, const PcHostServices *services);

/* Build a declared view (NSView* as void*) for a container, or NULL. */
void *PcMakeView(const char *viewId, const char *containerId,
                 const PcHostServices *services);
void  PcCloseView(void *view);

/* Optional configuration UI. */
void  PcConfigure(void *parentWindow);
```

`PcHostServices` is the **superset** of today's `PtxHostServices` / `PfxHostServices`:
cursor & selection accessors, local-path resolution, Trash/delete, reload,
`presentInfo`, `parentWindow`, a Keychain-backed `crypt`, plus:

- `int getContext(void *host, const char *key, char *out, int maxlen)` — read a
  context value (so a plugin *can* branch at runtime if it wants; placement/
  enablement stays declarative).
- `void invokeCommand(void *host, const char *commandId)` — trigger any host or
  plugin command (composition: plugins can drive built-in actions).

`localCursorPath` must resolve a VFS file to a real temp path **asynchronously** on
the host; the host does this *before* calling `PcRunCommand` for commands whose
manifest sets `needsLocalPath: true`, so the C accessor stays non-blocking.

## Integration with the existing architecture (grounded in the code map)

The app already has the right spine — the design *reuses* it rather than adding a
parallel one:

- **Command spine = `CommandRegistry`** (`PCCommands.swift:344`, an actor of
  `cm_*` name → `PCCommand{handler}`). Single dispatch funnel
  `MainWindowController.runCommandNamed` (`MainWindowController.swift:2071`),
  shared by menus, keymap, command line and the function/button bars. **A plugin
  command is registered here as a normal `PCCommand`** whose handler dispatches to
  the plugin's `PcRunCommand`. It then rides menus/keys/command-line for free. Ids
  are namespaced (`plugin.<bundle>.<cmd>`), coexisting with `cm_*`.
- **Menu items are uniform already:** every item is built by
  `AppMenu.command(title, cmd, key, mask)` with `representedObject = cm_name` and a
  single action `runMenuCommand` (`AppMenu.swift:489`). So the menu is *already* a
  declarative list of (menu, title, command, key) tuples — decision #2 is a
  **mechanical refactor**, not a rewrite: `AppMenu.build` is changed to emit
  `[MenuContribution]` (built-in contributions) that `MenuBuilder` renders, and
  plugin contributions merge into the same list.
- **Validation seam is missing and must be added.** Today enablement is static
  (`KeymapMenu.apply` sets `isEnabled = registered.contains(cmd)`, `autoenablesItems
  = false`, no `validateMenuItem`/`menuNeedsUpdate` anywhere). For `when`-based
  enable/visibility we attach an **`NSMenuDelegate`** to menus carrying conditional
  items and re-evaluate `when` in `menuNeedsUpdate(_:)` against a fresh context —
  localized, no responder-chain rework.
- **Context menus** are per-site imperative builders; the reference hook is
  `PanelListView.buildContextMenu()` (`PanelListView.swift:1221`), which already
  supports `cm_`-style items via `ctxRunCommand`→`onRunCommand`→`runCommandNamed`.
  `ContextMenuBuilder` injects contributions for surface `panel.item` there.
- **Side view** reference container is `PreviewPanelView`
  (`PreviewPanelView.swift:11`) — today fixed modes; we add a provider seam so a
  `views` contribution (container `sidebar`/`preview`) mounts a plugin `PcMakeView`.
- **Manifest parsing** extends `PluginManifestParser` (`PluginManifest.swift:80`)
  with a `PCContributions` section → `ContributionModel`.

## Host components (pure parts in PCPluginHost; UI parts in PCApp)

- **ContributionModel** (PCPluginHost, pure): typed structs + parser from an
  Info.plist dict; validates ids/keys. Unit-tested.
- **WhenExpression** (PCPluginHost, pure): lexer→parser→evaluator + a
  `ContributionContext` value type. Unit-tested.
- **ContributionRegistry** (`@MainActor`, PCApp): merges built-in contributions
  with those of every *enabled* plugin; fires `onChange` when a plugin is
  enabled/disabled/removed (driven by PluginManager + the Plugins… dialog). Owns
  registering plugin commands into `CommandRegistry` and tearing them down.
- **MenuBuilder** (PCApp): renders the menu bar from the registry — groups, order,
  `when`, `hides`; attaches the `menuNeedsUpdate` validation delegate. Replaces the
  static tail of `AppMenu.build`.
- **ContextMenuBuilder** (PCApp): injects contributions per surface on demand.
- **KeybindingRegistry** (PCApp): key → command with `when` (feeds the keymap).
- **ViewContainerRegistry** (PCApp): named mount points; instantiates/removes view
  contributions via `PcMakeView`/`PcCloseView` as `when` changes.

## Migration & cleanup (with anchors)

1. Refactor `AppMenu.build` (`AppMenu.swift:12`) to emit built-in
   `MenuContribution`s (ids `builtin.*` reusing existing `cm_*` names); render via
   `MenuBuilder`. `installMainMenu` (`MainWindowController.swift:2029`) drives it.
2. Route `KeymapMenu.apply` enablement through the registry; add the
   `menuNeedsUpdate` `when` re-evaluation.
3. **Uninstaller**: manifest declares command `plugin.uninstaller.uninstall`
   (title "Uninstall Application…") + File-menu (group `2_tools`) &
   `panel.item` context contributions, `when: cursorIsApp`; dylib switches
   `PtxExecute`→`PcRunCommand`. **Delete** the hard-wired File item
   (`AppMenu.swift:96`), the `cm_UninstallApp` registration
   (`PCCommands.swift:832`), and `showUninstallApp` (`MainWindowController.swift:621`).
   Result: the item exists **iff** the plugin is enabled and is enabled **iff** the
   cursor is an `.app` — the reported bug fixed at the root.
4. **Context menus**: hook `ContextMenuBuilder` into `PanelListView.buildContextMenu`.
5. **Keybindings** via `KeybindingRegistry`.
6. **Side panel**: provider seam in `PreviewPanelView`; migrate one reference view.
7. **WebDAV**: manifest declares `plugin.webdav.connect`; drop the
   `cm_WebDAVConnect` hard-wiring (`AppMenu.swift:195`, `MainWindowController.swift:610`).
   Log-Viewer/Git/RAR/Treemap follow the same manifest pattern.

## Phasing

- **P1 SDK & model:** `contrib.h`, manifest schema, `ContributionModel` parser,
  `WhenEvaluator` — all with unit tests.
- **P2 Menu bar:** registry + built-in contributions + `MenuBuilder`; convert the
  built-in menu; wire plugin menu contributions; enable/disable rebuilds live.
- **P3 Uninstaller migration:** prove the bug is fixed end-to-end.
- **P4 Context menus.**
- **P5 Keybindings.**
- **P6 Side-panel view container** + a reference view contribution.
- **P7** roll the rest of the plugins/containers onto the model.

Each phase builds + tests green before the next; commits are local-only.
