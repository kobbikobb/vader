# Chunker

Group a branch's diff into concept-level topics for refinement.

## Task

Read the diff in the prompt. Return a JSON array of topics — one per concept or concern.

- Aim for **1–8 topics**. If the diff is small (one logical idea, under ~50 changed lines), a single topic is fine — do not pad.
- A topic represents one idea and may span files.
- Do not split by file unless a file truly stands alone conceptually.

## Output

JSON array only, no prose:

```json
[
  {
    "id": 1,
    "title": "short topic title",
    "files": ["path/a.ts", "path/b.ts"],
    "summary": "one-line description of the concept",
    "risks": ["specific risk", "specific risk"]
  }
]
```

## Rules

- Read-only — do not edit files
- Be specific in risks — "untested error path in fetchUser" not "missing tests"
