# Codex QA, model switch round 1: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

Review of the change that adds the original (Red Hat) model next to Heretic and drops the dependency on the other project's Caddyfile template.

| # | Severity | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | HIGH | edge/install.sh:33 | Import detection is global, not scoped to the `alphaexperiments.com` site block. | An import in any other Caddy site block makes the condition false; validation can still pass while `/heretic-inference` is never imported. | Detect the import within the matched target site block; insert when absent there. |
| 2 | MED | apps/web/src/components/api-access.tsx:68-69 | The terminal dialog still defaults to Heretic before status resolves. | `served?.id ?? MODEL_IDS[0]` selects `qwen3.8-27b-heretic`; on an Original pod the dialog can say “unknown” yet offer commands that 404. | Do not render a model-specific invocation until status supplies an ID; offer model discovery/retry instead. |
| 3 | MED | pod/start.sh:27-34 | Failed switches are persisted before their model is downloaded and confirmed serving. | `.model` is written before `fetch_model.sh`; a disk/checksum/download failure leaves the old server running but makes later argument-less starts select the failed target. | Write `.model` atomically only after `serving` confirms the chosen model, or restore the prior value on failure. |
| 4 | LOW | docs/ARCHITECTURE.md:15 | Diagram still states that vLLM serves Heretic only. | It names only `qwen3.8-27b-heretic`, contradicting the two-model table immediately below. | Say it serves the selected model, with both IDs. |
| 5 | LOW | docs/DEPLOY.md:125 | Acceptance criterion requires the Heretic ID. | An Original deployment correctly returns `qwen3.8-27b`, but fails the written criterion. | Accept either served ID, or say “the selected model ID.” |

Checked and fine:

- No files changed; no production, pod, or edge contact was made.
- `git diff --check`, Bash parsing, ShellCheck, TypeScript (`tsc --noEmit`), and ESLint passed.
- Both production `serve.sh` presets use their matching model directory and served ID; `start.sh` waits specifically for that ID.
- `fetch_model.sh` checks available-plus-reusable disk capacity, pins the revision, and verifies manifest entries before writing `.download-complete`.
- Heretic manifest hash entries are byte-identical to HEAD’s pre-move manifest; both manifests are well-formed and their declared commits match `models.sh`.
- `run_suite.sh` selects `qwen3.8-27b` for `original`; client verification discovers the live ID and configures both models.
- Web discovery caches for one minute, clears its cache on a model 404, and the shared status provider feeds header, welcome, composer, pill, and dialog.
- The two dialog `jq` lines exactly equal `docs/CLIENTS.md`; installed pi 0.87.1 and opencode 1.18.23 support the documented provider/model mechanisms.
- Credential scan of all 299 commit candidates found only the intentional `PASTE` placeholders in the dialog and client docs; no apparent credential material.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| # | Verdict | What changed |
|---|---|---|
| 1 | Fixed | `edge/install.sh` finds the `alphaexperiments.com {` block, its closing brace by brace counting, and checks for the import line inside that block only; it inserts (with a backup) only when absent there. Tested on the edge on copies of the live Caddyfile: unchanged when present, added when removed, added when the line existed only in the `penge.alphaexperiments.com` block; `caddy validate` passes |
| 2 | Fixed | The terminal dialog shows `<model id>` in the run and curl lines until the status poll reports the served model |
| 3 | Fixed | `start.sh` writes `/workspace/.model` (atomically) only after vLLM serves the chosen model; a failed switch keeps the previous choice. `docs/OPERATIONS.md` says so |
| 4 | Fixed | `docs/ARCHITECTURE.md` diagram: `serving qwen3.8-27b-heretic or qwen3.8-27b` |
| 5 | Fixed | `docs/DEPLOY.md` check: either served id |
