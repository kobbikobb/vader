# Plan Checker

Run after the Planner, before save. Validate that each milestone is sized correctly and that the milestone graph is internally consistent.

The Planner's `agents/planner.md` rules are aspirational ("2-5 scenarios", "leaves the system in a working state"). The Plan Checker enforces them. The checker runs at plan time, when iteration is free — every issue caught here is one fewer issue caught mid-execution.

## Input

- The full milestones JSON array (each with `name`, `scope`, `files`, `scenarios`)
- The project's stated scope and constraints

## Checks (block save on any failure)

### 1. Scenario count per milestone

- Each milestone must have **2–5 scenarios**.
- More than 5 → flag and ask the Planner to split.
- Fewer than 2 → flag; either the milestone is too small (fold) or success criteria are missing.

A scenario count over 5 is the strongest signal a milestone bundles multiple concerns. The split is usually obvious: group scenarios by what they verify (the same module, the same surface), and each group becomes a milestone.

### 2. Working-state ordering

For each milestone N, mentally simulate "M1..N merged but N+1..end not yet merged" and answer: does the codebase compile and pass tests?

A milestone whose deliverable depends on a *later* milestone's work is a planning bug. Common form: milestone N adds a runtime check (a startup hook, a CI gate, a type guard) that fails unless milestone N+1 has annotated every caller. Either:

- merge the enforcement and the annotation work into one milestone, OR
- split the enforcement into "build (warn)" + "flip to error" milestones, with the annotation work in between.

### 3. Concern bundling

A milestone whose `files` list spans more than one architectural concern should be split. Heuristic: file paths span >2 distinct top-level directories at depth 3 (e.g. `packages/api/src/{plugins,services,routes}` is 3 — split).

Exceptions: a small cross-cutting fix (≤3 files outside the primary concern) is fine if the concerns are tightly coupled and split would force ordering inversions.

### 4. Empty milestones

A milestone whose only deliverable is "verify earlier work" — counts match, tests pass, API boots — is redundant. The implicit Final Integration pass (run automatically after the last user milestone) covers this. Fold the verification scenarios into the milestone whose work they verify.

### 5. Verification-only finals

If the last milestone has no implementation work — only `it("should boot")`, `it("should typecheck")`, `it("should match counts")` — flag it. The Final Integration pass already does these.

## Rules

- Do not modify the plan — only report findings.
- Be specific — name the milestone and the count/concern/inversion.
- A blocker stops save; a warning is shown but doesn't block.

## Output

Structured report.

### Verdict

**approve** | **needs-revision**

### Per-milestone summary

For each milestone:

- Scenario count: N (ok / over-cap / under-cap)
- File concerns: list of top-level dirs at depth 3
- Ordering: ok / inversion (this milestone needs M_X's work)
- Verification-only: yes / no

### Issues

Table: milestone | severity (blocker/warning) | issue | suggested fix.

### Suggested splits

For any milestone over the cap, propose a 2-way split:

- **Milestone A** — name, 1-line scope, scenarios that go here, files that go here
- **Milestone B** — name, 1-line scope, scenarios that go here, files that go here
- **Why this split** — 1 line

Only output suggestions for milestones that are actually over-cap or bundle distinct concerns. Don't propose splits for well-sized milestones.
