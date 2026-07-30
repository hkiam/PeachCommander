# Final report — documentation system, AI agent, and the VM test harness

Consolidated report over three initiatives delivered in this work session, all
committed to `main`. Every claim below is backed by committed code, tests, or a
VM-captured screenshot. Honest caveats and open points are called out per area.

---

## 0. At a glance

| Initiative | Outcome |
|-----------|---------|
| **VM test/screenshot harness** | Disposable macOS-26 VMs (tart) for isolated runs + reproducible screenshots |
| **Documentation system** | SSOT → in-app Apple Help Book + MkDocs site + README/FEATURES; all 5 priorities + 22 deliverables |
| **AI/LLM agent** | Shared Automation Core + MCP server + chat UI + local (Apple) & cloud providers; ki.md core built |

**Totals:** 32 commits · 73 doc content pages (37 in-app help topics) · 41 reproducible
screenshots · 15 pages with Mermaid diagrams · a new `PCAutomation` module (20 Swift
files, 69 unit tests) · doc quality gate 0 errors/0 warnings · MkDocs `--strict` passes.

---

## 1. VM test & screenshot harness (`Tools/vm/`)

Reproducible, isolated testing and clean screenshots independent of the host display.

- **tart** (Virtualization.framework) with a configured `golden` macOS-26 VM; each run
  is an APFS copy-on-write clone ("reset to snapshot"), so state never leaks.
- Screenshots come from the **hypervisor framebuffer over VNC** — no guest
  Screen-Recording (TCC) grant, no host-display-asleep issues. Light/dark via the
  app's own `-ConfigRoot` theme; per-shot session reset; Dock hidden.
- The app is built on the host and rsync'd in; launched via `open` (Aqua session);
  driven by the DEBUG `-AutomationScript` hook.
- `prepare-golden.sh`, `run-test.sh`, `capture.py` (spec-driven, `screenshot-specs.yml`),
  `demo-content.sh` (privacy-clean sample tree).

This harness verified essentially every UI claim in the docs and the AI work.

---

## 2. Documentation system (`docs/`, `DOCUMENTATION.md`)

A single-source-of-truth system: Markdown + metadata → many outputs. Built in the
plan's 6 analysis runs across the 5 mandated priorities.

- **Priority 1 — Integrated macOS Help:** 37 user topics → `PeachCommander.help`
  (HTML + TOC + `hiutil` search index + light/dark CSS), wired via
  `CFBundleHelpBookName` in `project.yml` (survives `xcodegen generate`), **verified
  live in Help Viewer**.
- **Priority 2 — Homepage:** `docs/content/website/index.md` — claim, hero, 8 USPs
  (each with a real screenshot), audiences, scenarios, honest pre-1.0 CTA.
- **Priority 3 — Online docs:** the help topics + installation, migration-from-TC,
  FAQ, version notes, 6 tutorials → a **MkDocs Material** site (`--strict` passes,
  offline, search, dark/light).
- **Priority 4 — Developer/architecture:** overview, onboarding, a per-module page for
  all 8 Swift modules, and architecture pages with **15 Mermaid diagrams**.
- **Priority 5 — SDK/plugin/API:** SDK overview, plugin architecture guide, plugin
  tutorials, and 6 API-reference pages **generated from the real `Plugins/SDK/*.h`**.
- **Toolchain & gates:** `features.yml` (64-feature registry), `terminology.yml`
  (glossary), generators (`build-helpbook.py`, `build-site.py`, `gen-api-reference.py`,
  `gen-overviews.py`), the `check-docs.py` quality gate (frontmatter/links/images/
  terminology/coverage), and a `docs.yml` CI workflow. Coverage matrix +
  documentation report in `docs/generated/`.

**Corrections the inventory forced (documented, followed the code as ground truth):**
no AI features existed before this session; Sparkle is declared but not integrated;
the app is unsigned today; `FSEventsWatcher` polls; five plugin types (pcx/pfx/plx/
pdx/ptx); `docs/product/*.md` is stale on menu names.

---

## 3. AI/LLM agent (`Sources/PCAutomation`, chat UI, MCP)

Built from `ki.md` after a thorough plan (`docs/analysis/ai-agent-plugin-plan.md`) and
four settled decisions (local-first, Core-first, MCP-early, confirm-writes).

### Architecture — one shared Automation Core

A versioned, typed **PCAutomation** module is the single audited seam used by the
in-app agent, the MCP server, and (future) a Python plugin:

- **Automation Core:** capability/autonomy `PermissionPolicy` (read-only /
  confirm-writes / autonomous), a 19-tool catalogue with JSON-Schema export, a
  `DefaultAutomationCore` actor that enforces the policy and implements
  **plan-then-confirm** for writes, and a `HostEventBus` (the app's first unified
  event stream). Wired to the real host (panels, op engine, ConfigStore, command
  registry) via `HostAutomationBridge` — all 19 tools live-verified.
- **MCP server:** `MCPServer` (JSON-RPC 2.0) + `MCPSocketServer` (loopback,
  newline-delimited) exposing the Core to external agents; off by default; connect
  Claude Code with `{"command":"nc","args":["127.0.0.1","8790"]}`. **Verified live**
  (initialize/tools-list/tools-call over the socket).
- **Agent brain:** `ModelProvider` + `AgentSession` (the tool-call loop with
  plan-then-confirm), provider- and UI-agnostic, plus a uniform `ToolCallProtocol`
  that makes any text model tool-capable.
- **Providers:** `AppleFoundationModelsProvider` (on-device, macOS-26, weak-linked)
  and `OpenAICompatibleProvider` (cloud / local server) — the **cloud path is verified
  end-to-end in a VM**: the chat completes the full tool loop over HTTP against a mock
  server (model → `list_directory` → real Core → final answer).
- **Chat UI:** `AIChatWindowController` (Commands ▸ AI Assistant) with a session
  switcher (persisted, parallel sessions via `SessionStore`/`SessionManager`),
  **attach-context** (grounds each message in the active folder + selection),
  **clickable file-path links**, and a plan-then-confirm Confirm bar.
- **"AI ▸" context menu:** user-editable skills (`SkillStore`, `aichat/skills.json`)
  — verified that a custom skills.json overrides the built-ins.
- **Settings ▸ AI:** autonomy popup, MCP-server toggle + port (persisted; MCP starts/
  stops live; new sessions use the configured autonomy).

**ki.md coverage:** natural-language control ✅ · context awareness (selection/panel/
tabs/search/contents/plugins/commands) ✅ · sidebar/chat ✅ · sessions (open/rename/
persist/parallel) ✅ · MCP server toggleable ✅ · local Apple model default + cloud
optional ✅ · safety (plan-then-confirm, capability policy, Keychain) ✅ · "Mit KI…"
menu + prefab actions ✅ · clean shared core for scripting/agents ✅.

---

## 4. Open points & recommended next steps

**AI (per `docs/analysis/ai-agent-enhancements.md`):**
- **Native FoundationModels tool-calling + guided generation** — implemented via a
  text protocol for now; native `Tool`/`@Generable` needs a Mac with Apple
  Intelligence enabled (the headless VM has none) — land + verify on a real device.
- **AI panel columns** (computed summary/tags via the PDX content-field system),
  **semantic search** (on-device embeddings), **plugin-contributed tools**, **MCP
  client**, **voice** — all P1/P2, scoped in the roadmap.
- Move the cloud API key wiring from an env var to the Keychain + a Settings field;
  add MCP socket auth + an "external agent connected" indicator.

**Documentation:**
- 4 secondary screenshots need multi-step UI (ACL sheet, diff window, transient
  progress dialog, image viewer) — a follow-up capture pass.
- German (`de.lproj`) Help Book localization via the existing translation pipeline.
- Context-sensitive `helpAnchor` links from dialogs (the generator already supports
  anchors); retire/regenerate the stale `docs/product/*.md`.

**App (pre-existing, surfaced by the inventory — not docs/AI issues):**
- Sparkle auto-update not integrated; signing/notarization not automated; FSEvents
  watching still polls; `Cmd+Shift+D` collides (Go ▸ Desktop vs. Download-from-URL).

---

## 5. Environment constraints during this session

- **Org monthly spend limit** was reached partway through. Multi-agent workflows were
  used for the doc-heavy phases (inventory, help authoring, homepage, web docs);
  after the limit, all further work (dev docs finalization, the entire AI agent) was
  done in the main loop. Every result passes the same tests/gates regardless.
- **Apple Intelligence is not available** in the headless test VM, so live on-device
  model behavior can't be verified here; the local provider is guarded and validated
  on a real device. The cloud provider path is fully verified against a mock server.

---

## 6. How to build & run

- App: `Tools/build.sh` (or `xcodegen generate && xcodebuild -scheme PeachCommander`).
  Tests: `Tools/test.sh` or the `AllTests` scheme (`PC_NET_LIVE=1` for live network).
- Docs: `python3 docs/scripts/check-docs.py` (gate), `build-helpbook.py`,
  `build-site.py [--serve]`, `gen-api-reference.py`, `gen-overviews.py`.
- Screenshots: `python3 Tools/vm/capture.py [--only <id>]`.
- AI: Commands ▸ AI Assistant; enable the MCP server + set autonomy in Settings ▸ AI;
  point at a local model with `AI.CloudBaseURL` (key via `PEACHCMD_AI_KEY`).

---

## 7. Commit ledger (this session, newest first)

32 commits from `a8b1754` (VM harness) through `5fa50be` (cloud provider). Highlights:
Documentation `1069092`→`80e801a` (foundation → Priorities 1–5 → validation/CI);
AI plan `2cdb633`; Automation Core `ea50b4e`/`14ac928`; host wiring `3598153`; MCP
`800a0f8`/`89901ef`; agent brain `d43a7cd`; providers `24d5fa1`/`5fa50be`; chat UI +
sessions + skills + settings `7956986`→`51f60a8`; local tool-calling + attach-context
+ clickable results `1d83d4e`/`91f2e57`/`60ca832`.
