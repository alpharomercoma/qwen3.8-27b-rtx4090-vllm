# Codex QA, model switch round 4: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Previous # | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| R1-1 | FIXED | Edge import detection/insertion is bounded to the `alphaexperiments.com` block. |
| R1-2 | FIXED | Dialog uses `<model id>` until an online status supplies the model. |
| R1-3 | FIXED | `start.sh` persists `.model` only after the selected ID is serving. |
| R1-4 | FIXED | Architecture diagram names both served IDs. |
| R1-5 | FIXED | Deploy acceptance allows either selected model ID. |
| R2-1 | FIXED | Missing model directory starts with `have=0`; `du` runs only if it exists. |
| R3-1 | FIXED | Actionable dialog content uses `useLiveModel()`, not last-known status. |
| R3-2 | FIXED | E2E reads the status-pill model and checks dialog commands use it. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | LOW | `docs/DEPLOY.md:49` | The deployment table says `serve.sh <model>` waits for the selected model. | `pod/serve.sh:140-147` kills/starts tmux and returns immediately; the actual model-ID wait loop is in `pod/start.sh:35-41`. | Attribute the wait to `start.sh`, or say `serve.sh` only starts vLLM. |
| 2 | LOW | `docs/CLIENTS.md:25-26` | It says every command below was tested on 2026-09-28, but that day’s evidence is explicitly single-model. | `docs/CLIENTS.md:197` scopes the 2026-09-28 result to the old single-model config; the two-model `jq` commands were added in this change. | Narrow the historical claim or document a dated test of the two-model commands. |

What I checked that is fine:

- No production, pod, edge, or public endpoint was contacted; no repository files changed.
- `git diff --check`, Bash parsing, ShellCheck, embedded edge-Python parsing, and TypeScript (`tsc --noEmit --incremental false`) passed.
- Both presets consistently map repo, pinned revision, model directory, served ID, and manifest. The Heretic manifest’s 22 data entries are byte-identical to HEAD’s pre-move manifest; Original has 12 well-formed entries.
- `fetch_model.sh` verifies space and checksums before marking completion. `start.sh` waits for the selected model ID; `serve.sh` and `run_suite.sh` select the right IDs for both production presets.
- Model discovery caches for one minute, chat clears it on a 404, and one status provider drives the header, welcome view, composer, pill, and dialog.
- The dialog’s two generated `jq` lines exactly match `docs/CLIENTS.md`; installed pi is 0.87.1 and opencode is 1.18.23.
- No remaining instruction tells users to edit PengePassportPH’s template; the edge installer restores its own import after regeneration.
- A filename-only credential-pattern scan of all 302 commit candidates found no standard credential material; generic hits were expected environment references and the intentional `PASTE` placeholder.

VERDICT: NEEDS FIXES
## Resolution (2026-09-29)

| # | Verdict | What changed |
|---|---|---|
| 1 | Fixed | `docs/DEPLOY.md`: `serve.sh` starts vLLM; `start.sh` waits for the model |
| 2 | Fixed | Re-tested the two-model setup commands on a fresh config as well (pi 0.87.1 lists `qwen3.8-27b` and `qwen3.8-27b-heretic`; opencode 1.18.23 lists both under `heretic/`); `docs/CLIENTS.md` now dates that test and scopes the 2026-09-28 end-to-end run to its single-model config |
