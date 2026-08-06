---
title: "API: Contributions ABI (contrib)"
slug: api-contrib
section: API reference
order: 60
related: [sdk-overview, plugin-architecture-guide]
---

# Contributions ABI (contrib)

> Source: `Plugins/SDK/contrib.h` — this page is generated from that header by `docs/scripts/gen-api-reference.py`; edit the header, not this page.

contrib.h — Peach Commander plugin contributions, behavior ABI (SPEC-013).

 The declarative side of a contribution (WHAT commands/views a plugin offers and
 WHERE they appear: menus, context menus, keybindings, view containers) lives in
 the plugin's Info.plist `PCContributions`. This header is ONLY the behavior ABI:
 the host runs a declared command or builds a declared view by id. It is id-based
 and supersedes PTX's index-based tool ABI (PtxGetToolCount/Info/Execute).

 A single plugin of ANY type (pcx/pfx/plx/pdx) may also carry contributions — the
 layer is orthogonal to the file-op ABIs. Self-contained C11 on pc_common.h; all
 char* are UTF-8; version-checked via PcGetApiVersion.

## Entry points & functions

- `PcCloseView`
- `PcConfigure`
- `PcGetApiVersion`
- `PcInvokeTool`
- `PcMakeView`
- `PcNotifyThemeChanged`
- `PcNotifyView`
- `PcRunCommand`


## Callbacks & service members

- `cursorPath`
- `localCursorPath`
- `selectionCount`
- `selectionPath`
- `moveToTrash`
- `deletePermanently`
- `reloadActivePanel`
- `presentInfo`
- `getContext`
- `invokeCommand`
- `crypt`
- `registerToolWindow`
- `openPath`
- `openPathInPanel`
- `presentSidebarView`
- `dismissSidebarView`
- `automationToolsJson`
- `automationContextJson`
- `automationInvoke`
- `automationConfirm`
- `automationFree`
- `getFileComment`
- `setFileComment`


## Full header

```c
// SPDX-License-Identifier: Apache-2.0
/*
 * contrib.h — Peach Commander plugin contributions, behavior ABI (SPEC-013).
 *
 * The declarative side of a contribution (WHAT commands/views a plugin offers and
 * WHERE they appear: menus, context menus, keybindings, view containers) lives in
 * the plugin's Info.plist `PCContributions`. This header is ONLY the behavior ABI:
 * the host runs a declared command or builds a declared view by id. It is id-based
 * and supersedes PTX's index-based tool ABI (PtxGetToolCount/Info/Execute).
 *
 * A single plugin of ANY type (pcx/pfx/plx/pdx) may also carry contributions — the
 * layer is orthogonal to the file-op ABIs. Self-contained C11 on pc_common.h; all
 * char* are UTF-8; version-checked via PcGetApiVersion.
 */

#ifndef PC_CONTRIB_H
#define PC_CONTRIB_H

#include <stdint.h>
#include "pc_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Unified host-services table — the superset of the per-type service tables
 * (PtxHostServices / PfxHostServices). `host` is an opaque token passed back to
 * each callback. "get" callbacks fill a caller-allocated UTF-8 buffer and return
 * 1 on success / 0 if unavailable.
 */
typedef struct PcHostServices {
    void *host;

    /* Cursor & selection. */
    int  (*cursorPath)(void *host, char *out, int maxlen);        /* full path            */
    int  (*localCursorPath)(void *host, char *out, int maxlen);   /* local (VFS→temp)     */
    int  (*selectionCount)(void *host);
    int  (*selectionPath)(void *host, int index, char *out, int maxlen);

    /* Mutations (routed through the host's op engine). */
    void (*moveToTrash)(void *host, const char *const *paths, int count);
    void (*deletePermanently)(void *host, const char *const *paths, int count);
    void (*reloadActivePanel)(void *host);

    /* UI + composition. */
    void (*presentInfo)(void *host, const char *title, const char *message);
    /* Read a context value by key (same keys the declarative `when` sees), e.g.
       "cursorPath", "selectionCount", "panelScheme". 1 on success.

       Colour theme (F-338): "theme.id", "theme.isDark" ("1"/"0"), and colours as
       "#RRGGBB" — or "#RRGGBBAA" when translucent. A semantic set a plugin view can
       draw with directly: theme.background, theme.windowBackground, theme.text,
       theme.secondaryText, theme.accent, theme.separator,
       theme.selectionBackground, theme.selectionText, theme.markedText,
       theme.controlBackground, theme.controlText. Every host panel colour is also
       available raw as "theme.color.<name>" (the names a user theme file uses).
       Read them when building a view and again on PcNotifyThemeChanged; fall back to
       the system colours if a key is absent, which is what an older host returns. */
    int  (*getContext)(void *host, const char *key, char *out, int maxlen);
    /* Trigger any host or plugin command by id (composition). */
    void (*invokeCommand)(void *host, const char *commandId);
    /* Keychain-backed credential store (mode is a PC_CRYPT_* value). */
    int  (*crypt)(void *host, int mode, const char *store, char *password, int maxlen);

    /* Register a plugin WINDOW's own menu-bar menus so the host installs them
       while that window is key (like the built-in tool windows). Call this once,
       synchronously, while opening the window; `window` is an NSWindow pointer and
       `editMenu` / `contentMenu` are NSMenu pointers (the plugin owns them and
       keeps the window alive). The host removes them automatically when the window
       closes - no teardown call is needed. `title` names the content menu (may be
       NULL). */
    void (*registerToolWindow)(void *host, void *window, void *editMenu,
                               void *contentMenu, const char *title);

    void *parentWindow;   /* NSWindow* to present sheets over (may be NULL)          */
    void *parentView;     /* NSView* container for view commands (may be NULL)       */

    /* Resolve an internal link: navigate to a folder, or reveal/open a file, in
       the active panel. Appended at the end so the struct stays ABI-compatible
       with plugins built before this field existed. */
    void (*openPath)(void *host, const char *path);

    /* Open `path` in a SPECIFIC main panel (side: 0 = left, 1 = right). If `path`
       is a file, the host navigates to its parent folder and selects it.
       Appended at the end for ABI compatibility. */
    void (*openPathInPanel)(void *host, int side, const char *path);

    /* On-demand sidebar view. `presentSidebarView` mounts the plugin's view
       `viewId` in the sidebar immediately, rooted at `rootPath`; the view reads
       its root via getContext("sidebarViewRoot"). `dismissSidebarView` removes it
       again. Both appended at the end for ABI compatibility. */
    void (*presentSidebarView)(void *host, const char *viewId, const char *rootPath);
    void (*dismissSidebarView)(void *host, const char *viewId);

    /* Automation core — the host's file-manager tool engine (the same one that
       drives the MCP server), so a plugin (e.g. the AI assistant) can run tools
       under the host's permission policy. Each returns a host-allocated UTF-8
       JSON string the caller MUST release with `automationFree` (NULL on error).
       The host applies its configured autonomy policy: `automationInvoke` returns
       an outcome envelope {"status":"ok","payloadB64":..} / {"status":
       "needsConfirmation","plan":..,"token":..} / {"status":"refused","reason":..}
       / {"status":"failed","error":..}; a "needsConfirmation" is executed by
       calling `automationConfirm` with its token. `automationToolsJson` returns the
       tool catalogue (JSON array); `automationContextJson` the live UI context.
       IMPORTANT: these BLOCK until the async host op completes, so they must be
       called OFF the main thread. Appended at the end for ABI compatibility. */
    char *(*automationToolsJson)(void *host);
    char *(*automationContextJson)(void *host);
    char *(*automationInvoke)(void *host, const char *toolName, const char *argumentsJson);
    char *(*automationConfirm)(void *host, const char *token);
    void  (*automationFree)(void *host, char *str);

    /* Per-file comments — the `descript.ion` entry the host shows in its Comment
       column and edits with Ctrl+Z, mirrored into the macOS Finder comment for local
       files. A plugin cannot reach these on its own: they live in a file the host
       reads through the VFS, so they are available on network locations too, and the
       Finder mirror is the host's business.

       This exists so a note-taking plugin does not become a *second*, disconnected
       place where a note about a file can live. `getFileComment` writes at most
       `maxlen` bytes including the terminator and returns 1 on success (0 when there
       is no comment or the path is unknown); `setFileComment` with NULL or an empty
       string clears it. Both appended at the end for ABI compatibility. */
    int  (*getFileComment)(void *host, const char *path, char *out, int maxlen);
    void (*setFileComment)(void *host, const char *path, const char *comment);
} PcHostServices;

/* ---- Behavior entry points --------------------------------------------- */

/* ABI handshake. */
int   PcGetApiVersion(void);

/* Run the command declared with `commandId` (Info.plist PCContributions.commands).
   The plugin performs its work (may open its own windows) via `services`. */
void  PcRunCommand(const char *commandId, const PcHostServices *services);

/* Build the view declared with `viewId` for the named `containerId`
   (e.g. "sidebar", "preview"). Returns an NSView* as void*, or NULL. The plugin
   owns it until PcCloseView; `services` stays valid for the view's lifetime. */
void *PcMakeView(const char *viewId, const char *containerId, const PcHostServices *services);

/* Release a view previously returned by PcMakeView. */
void  PcCloseView(void *view);

/* Show the plugin's configuration UI (parentWindow may host a sheet). */
void  PcConfigure(void *parentWindow);

/* Execute a tool the plugin declared (Info.plist PCContributions.tools) by id, with
   JSON arguments, returning a host-allocated UTF-8 result string (the host frees it).
   Lets a plugin add tools to the assistant's catalogue; the host gates them by the
   declared capability and routes calls here. May be NULL if the plugin has no tools. */
char *PcInvokeTool(const char *toolName, const char *argumentsJson, const PcHostServices *services);

/* Notify the plugin that the host's colour theme changed, so any window or view it
   already opened can re-read the `theme.*` context keys (see getContext) and repaint.
   Optional — a plugin that does not export it is simply not called, and a plugin that
   does still works with an older host that never calls it. Called on the main thread.

   Views built with PcMakeView also receive PcNotifyView(view, "theme", <themeId>);
   this entry point exists for the plugin's OWN windows, which the host cannot address
   by view pointer. */
void  PcNotifyThemeChanged(void);

/* Notify a view previously returned by PcMakeView that a host context value
   changed, e.g. key "cursorPath" or "dir" (both UTF-8). Lets an embedded view
   (e.g. a sidebar panel) follow the active panel. Optional; called on the main
   thread. */
void  PcNotifyView(void *view, const char *key, const char *value);

#ifdef __cplusplus
}
#endif

#endif /* PC_CONTRIB_H */
```
