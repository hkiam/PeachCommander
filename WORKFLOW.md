# WORKFLOW — Operating Protocol for LLM Sessions

This file defines EXACTLY how any LLM (or human) session must work on this project.
It is designed for small context windows and interruption at any moment.

## Session start (always, no exceptions)

1. Read `STATE.md` completely.
2. Read the iteration file referenced by STATE.md (e.g. `docs/iterations/I03.md`).
3. Read the spec(s) linked from the current task.
4. If anything in STATE.md is inconsistent with the working tree (e.g. files missing,
   build broken), FIX THE STATE FIRST: run the build, run the tests, record actual
   status in STATE.md before doing new work.
5. Only then pick the next unchecked task.

## Work unit loop

A "work unit" is ONE task checkbox in an iteration file. Never work on two at once.

```
pick next unchecked task in current iteration
  -> read linked spec section
  -> implement (smallest change that satisfies acceptance criteria)
  -> build: xcodegen generate (if project.yml changed) && xcodebuild build
  -> test:  xcodebuild test (targets listed in the task; at minimum the module touched)
  -> manual check: run the app if the task has a "Demo" line
  -> update the iteration file: check the box, add one-line note if noteworthy
  -> update STATE.md (current task pointer, timestamp, any new blockers/decisions)
  -> update feature-inventory.md status column if a F-xxx feature became "done"
  -> git commit (format below)
```

If a task turns out to be too large for one session, split it: add sub-checkboxes
in the iteration file, complete at least one, and record the split in STATE.md.

## Commit format

```
I<NN>-T<MM>: <imperative summary>

Refs: SPEC-xxx, F-xxx (if applicable)
```

Example: `I04-T03: implement copy queue with progress coalescing`

## Verification rules

- The project must BUILD and all EXISTING tests must PASS before every commit.
  A commit that knowingly breaks the build is forbidden; if blocked, revert and
  record the blocker in STATE.md.
- New functionality requires tests as specified in the task. No task is "done"
  without its acceptance criteria met. Do not weaken acceptance criteria; if one
  is impossible, record why in STATE.md under "Blockers / escalations".
- Performance-sensitive code (listing, copy engine, viewer, search) must respect
  the budgets in `docs/architecture/performance.md` and keep its perf tests green.

## When you are blocked

1. Write the blocker into STATE.md (`## Blockers / escalations`) with:
   what you tried, error output, your best 1-2 proposed solutions.
2. If an alternative approach exists that does NOT contradict DECISIONS.md, take it
   and record the deviation.
3. If it contradicts DECISIONS.md: STOP that task, mark it `[blocked]`, move to the
   next independent task. A human (or stronger model) resolves ADR conflicts.

## Scope discipline

- Do not implement features from later iterations "while you're at it".
- Do not refactor outside the current task unless the build is broken.
- Do not add dependencies not listed in `docs/architecture/tech-stack.md`
  (adding one requires a new ADR in DECISIONS.md).
- Do not edit specs to match the code; code follows spec. Spec bugs -> note in
  STATE.md, a spec fix is its own explicit step.

## Iteration exit

An iteration is complete when ALL its checkboxes are checked and the "Exit checklist"
at the bottom of the iteration file passes. Then:
1. Update STATE.md: mark iteration done, set next iteration as current.
2. Run the full test suite + the iteration's demo script; record results.
3. Tag: `git tag i<NN>-done`.

## Context-saving tips for small models

- Specs are chunked with stable heading anchors — read only the section a task links.
- `feature-inventory.md` is a lookup table; never load it fully, grep the F-ID.
- Prefer `rg`/grep over reading whole files.
- The Xcode project is generated from `project.yml` (XcodeGen). NEVER hand-edit
  `.xcodeproj` — edit `project.yml` and regenerate.
