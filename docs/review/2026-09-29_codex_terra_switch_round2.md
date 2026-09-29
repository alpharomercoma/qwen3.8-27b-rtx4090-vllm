# Codex QA, model switch round 2: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Previous # | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| 1 | FIXED | `edge/install.sh:33-56` locates the target site block and checks/inserts the import only inside it. |
| 2 | FIXED | `api-access.tsx:68-70` uses `<model id>` until status identifies the live model. |
| 3 | FIXED | `start.sh:42-43` writes `.model` only after the selected served ID responds. |
| 4 | FIXED | `docs/ARCHITECTURE.md:15` names both served IDs. |
| 5 | FIXED | `docs/DEPLOY.md:125` accepts either selected model ID. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | HIGH | `pod/fetch_model.sh:10` | A first download fails before the disk-space fallback runs. | With `set -euo pipefail`, `du` returns nonzero when the model directory does not exist; therefore the `have=$(du \| cut)` assignment exits before `have=${have:-0}`. A local equivalent failing pipeline exited 1 without reaching the fallback. `start.sh` creates `/workspace/models`, not either model-specific directory. | Initialize `have=0`, then run `du` only when `[ -d "$MODEL_DIR" ]`; retain failure for an existing but unreadable directory. |

Checked and fine:

- No production, pod, or edge contact occurred.
- `bash -n`, `git diff --check`, ESLint, and TypeScript checks passed.
- Model presets consistently map both repositories, pinned commits, directories, IDs, and manifests. The 22 non-comment Heretic manifest entries exactly match the pre-move manifest; the original manifest has 12 well-formed, non-duplicate entries.
- `serve.sh` uses the selected preset directory and served ID; `start.sh` waits for that specific ID and preserves the prior choice on a failed switch.
- `run_suite.sh` selects `qwen3.8-27b` for `original`.
- Web discovery caches for one minute, clears on chat-model 404, and the shared provider supplies header, welcome view, composer, pill, and dialog.
- The dialog has two jq builders; `CLIENTS.md` has two corresponding jq lines, and the E2E source asserts their equality. Installed pi is 0.87.1 and opencode is 1.18.23; the pi provider schema is documented locally.
- Documentation consistently describes two selectable models and instructs rerunning this repository’s edge installer—not editing the other project.
- Credential-pattern scan of all tracked/untracked candidates found only the intentional `PASTE-YOUR-KEY-HERE` placeholders.

Read-only caveat: I inadvertently invoked `npm run typecheck`, whose script runs Next type generation; no Git-visible candidate-file changes resulted.

VERDICT: NEEDS FIXES
## Resolution (2026-09-29)

| # | Verdict | What changed |
|---|---|---|
| 1 | Fixed | `fetch_model.sh` starts from `have=0` and runs `du` only if the model directory exists (an existing but unreadable directory still fails). Reproduced first: under `set -euo pipefail` the old line exits 1 for a missing directory; the new code continues with `have=0` |
