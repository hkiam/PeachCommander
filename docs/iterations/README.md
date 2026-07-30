# Iterations — How to Read & Execute

Each `I<NN>.md` is a self-contained work package. Structure:

- **Goal / Demo** — what exists at the end, phrased as something a human can see.
- **Prerequisites** — iterations/decisions that must be done.
- **Read first** — the minimal doc set for this iteration.
- **Tasks** — ordered checkboxes `[ ] T<MM> …`. Execute strictly in order unless
  marked `(parallel-ok)`. Each task: scope, spec link, acceptance criteria (AC),
  tests, sometimes a Demo line. One task = one work unit = one commit (WORKFLOW.md).
- **Exit checklist** — gate to the next iteration.

Rules:
- Check boxes IN THE FILE as you complete tasks; add one-line notes after the box
  when something noteworthy happened (`— note: …`). This is the resume record.
- If a task must be split/reordered, edit the file (add sub-boxes) and log the
  deviation in STATE.md.
- Feature IDs (F-xxx) in a task: set them `done` in feature-inventory.md when
  the task completes.
- Estimates are intentionally absent — iterations are sized by scope, not time.
  A capable model should finish an early iteration in a handful of sessions.

Index: I01–I06 shell & core ops · I07–I13 power features · I14–I16 plugins &
network · I17–I20 parity, macOS polish, performance, release. See PLAN.md.
