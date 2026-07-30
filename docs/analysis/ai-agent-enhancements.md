# Making the AI a great file-manager integration — enhancement roadmap

Status: analysis + roadmap. Grounded in the shipped AI stack (PCAutomation core,
host bridge, MCP server, AgentSession, Apple Foundation Models provider, chat UI,
"AI ▸" skills, sessions). Each item notes value, effort, and whether it can be
runtime-verified in the current headless VM (which has no Apple Intelligence).

## 0. Where we are

The agent can already, through one audited seam (Automation Core), read/search/
navigate/configure and — with plan-then-confirm — change files, driven by the in-app
chat, the "AI ▸" context menu, or an external agent over MCP. The on-device model is
wired and now tool-capable via a text tool-call protocol (`ToolCallProtocol`), so the
local model actually drives the tools rather than only chatting.

## 1. Local execution (Apple Intelligence) — optimizations

1. **Native FoundationModels tool-calling** *(high value; needs on-device verification)*.
   Replace/augment the text protocol with the framework's native `Tool` protocol so
   the model calls tools with a real schema and the framework manages the loop:
   - Bridge each `ToolDefinition` to a `Tool` whose `Arguments = GeneratedContent`,
     `Output = String`, and `parameters = GenerationSchema(root:​DynamicGenerationSchema(
     name:​description:​properties:[…]))` built from our `ToolParameter`s; `call` does
     `content.value(String.self, forProperty:)` extraction → `AutomationCore.invoke`.
   - Reconcile with **plan-then-confirm**: expose read/navigate tools natively (safe,
     no confirmation); for writes, expose a single `propose_changes` tool that records
     the plan and returns "queued", then the app surfaces it for the user to confirm
     after generation — keeping the safety model with native tools.
   - Keep the text protocol as the fallback for non-FM/cloud providers.
2. **Guided generation (`@Generable`)** for structured outputs: a rename suggestion,
   an organize plan, or a table becomes a typed value the UI renders precisely (no
   fragile text parsing). Great fit for the "AI ▸" skills.
3. **Session reuse + prewarm**: keep one `LanguageModelSession` per chat session
   (it holds the transcript) instead of rebuilding per turn; `prewarm()` on chat open
   and after each user keystroke lull. Lower latency, better multi-turn coherence.
4. **Streaming** (`streamResponse`): render tokens as they arrive in the chat — the
   single biggest perceived-speed win for a small local model.
5. **Context-window budgeting + compaction**: a budgeted assembler (system + skill +
   compact live-context snapshot + only the file slices needed via `FileSlice` +
   rolling history) with summarize-older-turns compaction when the window fills.
6. **On-device embeddings** (NaturalLanguage) for semantic features (§2.6) — fully
   local, no cloud.

## 2. Deeper file-manager integration — what makes it "mega"

1. **Rich, actionable results** *(high value; verifiable)*. Render tool results as UI,
   not text: file chips you can click to reveal/open, a real diff view for edits, a
   table for `make_table`, a plan as a checklist with per-step approve. Reuse the
   existing viewer/diff/OverwriteResolver components.
2. **Plan preview = real operation preview**. Route an approved plan through the
   existing `TransferManager`/`OperationQueue` so AI-initiated copies/moves get the
   same progress, bandwidth limit, conflict resolver and Trash-based undo as manual
   ones. (Deletes already go to Trash → reversible.)
3. **Attach context to a query** *(high value)*: drag files/the selection/the current
   folder into the chat; the agent gets those paths as first-class context. Image
   files → on-device Vision/FM description; big files → chunked reads via `FileSlice`.
4. **AI columns** *(high value; native fit)*: an AI-computed panel column (summary,
   detected topic, suggested tags) exposed through the existing PDX/content-field
   provider system — the file list itself becomes AI-augmented, computed lazily on a
   background worker and cached.
5. **Semantic search**: an opt-in on-device embedding index of file contents, surfaced
   as a search mode that feeds the existing results filesystem — "find the invoice about
   the roof repair" beyond keyword matching. Integrates with `FileSearchEngine`/`ResultsFS`.
6. **Batch skills over a multi-selection**: run a skill on every selected file with
   progress in the Transfer Manager (e.g. "rename all these by content").
7. **Proactive, opt-in suggestions**: on entering a messy folder, a subtle "Organize
   with AI?" affordance (never automatic actions) — driven by cheap heuristics + a
   confirm-first plan.
8. **Voice input/control** (ki.md later stage): Speech framework → the same
   AgentSession; read answers back with AVSpeechSynthesizer.
9. **Explainability + audit**: an "AI actions" log view (every Core tool call the
   agent made, with args + outcome), an "explain what you just did" command, and a
   one-click "undo last AI change" (Trash/rename are reversible).
10. **Per-folder project memory + preferences**: an opt-in, user-visible/editable
    memory (a Markdown file per project the agent reads/writes; global prefs like
    "always keep originals") — the long-term memory ki.md asks for, kept inspectable.

## 3. Extensibility

1. **Skills as data**: move `SkillCatalog` to user-editable skill files (title +
   prompt + tool allow-list) under the config root, so users/teams add their own
   "AI ▸" actions without code.
2. **Plugin-contributed tools**: let a plugin register additional Automation Core
   tools (via the contribution ABI), so a Git/Docker/DB plugin can expose actions the
   agent can call — the agent grows with the plugin ecosystem.
3. **MCP client**: consume *external* MCP servers (the mirror of our MCP server) so
   the agent gains tools from other apps; merge them into the tool catalogue with the
   same permission gating.

## 4. Providers & routing

1. **Cloud providers** (Anthropic / OpenAI-compatible) behind the existing
   `ModelProvider`; keys in the Keychain; file contents sent only with explicit
   consent (a clear indicator; local model needs none).
2. **Local server** (Ollama / LM Studio / llama.cpp) via an OpenAI-compatible base URL
   for users wanting a bigger local model than Apple FM.
3. **Routing**: default local for quick skills; escalate to a stronger model for
   multi-step planning, with a visible per-session choice.

## 5. Safety & trust (deepen what exists)

- Per-session capability scoping already exists (`PermissionPolicy`); surface it in the
  UI (read-only / confirm-writes / autonomous toggle per session).
- Secret redaction before any cloud call; never log file contents.
- MCP server: add auth + a visible "external agent connected" indicator; keep it
  loopback + off by default.

## 6. Prioritized roadmap

**P0 (high value, verifiable now):** rich/actionable results (§2.1–2.2), attach-context
(§2.3), streaming (§1.4), skills-as-data (§3.1), AI actions/undo (§2.9), Settings page
(providers/policy/MCP toggle).

**P1:** native FM tool-calling + guided generation (§1.1–1.2, verify on a real Mac),
cloud/local-server providers (§4), AI columns (§2.4), batch skills (§2.6), per-folder
memory (§2.10).

**P2:** semantic search (§2.5), plugin-contributed tools + MCP client (§3.2–3.3),
proactive suggestions (§2.7), voice (§2.8), routing (§4.3).

## 7. Verification note

Anything touching the live on-device model (native tool-calling, guided generation,
streaming quality) needs a Mac with Apple Intelligence enabled — the headless test VM
has none, so those land behind availability guards and are validated on a real device.
Everything else (UI, tools, search, providers via a mock server, skills, memory,
persistence) is verifiable in the existing VM harness and by unit tests, as today.
