# Codex QA, model switch round 3: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Previous # | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| R1-1 | FIXED | Edge import detection is scoped to the target Caddy site block. |
| R1-2 | FIXED | Before an initial status result, terminal commands use `<model id>`, not Heretic. |
| R1-3 | FIXED | `start.sh` persists the choice only after the selected model is serving. |
| R1-4 | FIXED | Architecture diagram names both served IDs. |
| R1-5 | FIXED | Deploy acceptance accepts either served model ID. |
| R2-1 | FIXED | `fetch_model.sh` initializes `have=0` and runs `du` only for an existing model directory. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | MED | `apps/web/src/components/api-access.tsx:68-70`; `server-status.tsx:43-52` | The terminal dialog can label a previous model as “Serving now” and generate commands for it while the status pill says Offline during a switch/restart. | `useServedModel()` intentionally returns the last known model when current status has no model. The dialog treats that value as current. | Have the dialog use the current `online` status model only; otherwise show unknown and `<model id>`. Keep last-known behavior only for non-actionable UI labels if desired. |
| 2 | LOW | `apps/web/e2e/chat.spec.ts:117` | E2E does not verify that terminal commands select the currently served model. | It merely requires the Heretic ID, which is always present in the dialog’s two-model list—even when Original is live. | Obtain the live status ID and assert it appears in the dialog’s “Serving now” value and executable command suffixes. |

What I checked that is fine:

- No production, pod, edge, or public URL was contacted. No files were modified.
- `git diff --check`, Bash parsing, embedded edge Python parsing, changed-file ESLint, and `tsc --noEmit` passed.
- Presets, served IDs, pinned commits, directories, manifests, production `serve.sh` commands, `start.sh` wait/persistence logic, and `run_suite.sh original` are consistent.
- Both manifests are safe, well-formed, non-duplicate; commits match `models.sh`. All 22 Heretic entries are byte-identical to the pre-move manifest.
- Discovery caches for one minute, chat clears it on a 404, and the status route correctly handles a pinned override.
- The two dialog `jq` lines exactly match `docs/CLIENTS.md`; installed pi 0.87.1 and opencode 1.18.23 support the documented provider shapes.
- Docs consistently describe both models and instruct rerunning this repo’s installer, not editing PengePassportPH’s template.
- Credential scan covered 301 tracked/untracked commit candidates; it found only the intentional placeholder in `docs/CLIENTS.md`, not credential material.

VERDICT: NEEDS FIXES
## Resolution (2026-09-29)

| # | Verdict | What changed |
|---|---|---|
| 1 | Fixed | New `useLiveModel()` (the model only while the status is online); the terminal dialog uses it, so during a restart or switch it shows "unknown" and `<model id>`. The last-known model (`useServedModel()`) stays for labels only (header, welcome text). Tested against a mock server: online → the live model; mock stopped → pill Offline, dialog "unknown: the GPU server does not answer right now", run and curl lines `<model id>` |
| 2 | Fixed | `e2e/chat.spec.ts` reads the live model from the status pill and asserts the dialog's "Serving now", `pi --model`, `opencode run -m` and curl lines name it. Passes against a mock serving `qwen3.8-27b` and one serving `qwen3.8-27b-heretic` |
