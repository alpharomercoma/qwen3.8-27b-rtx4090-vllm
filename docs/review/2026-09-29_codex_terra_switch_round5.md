# Codex QA, model switch round 5: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Previous # | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| R1-1 | FIXED | Edge import detection/insertion is bounded to `alphaexperiments.com`’s block. |
| R1-2 | FIXED | Dialog uses `<model id>` until online status supplies a live model. |
| R1-3 | FIXED | `start.sh` persists `.model` only after the selected ID is serving. |
| R1-4 | FIXED | Architecture diagram names both served IDs. |
| R1-5 | FIXED | Deploy acceptance allows either model ID. |
| R2-1 | FIXED | Missing model directory starts with `have=0`; `du` is conditional. |
| R3-1 | FIXED | Actionable dialog uses `useLiveModel()`, not last-known status. |
| R3-2 | FIXED | E2E derives the live ID from the status pill and checks dialog commands. |
| R4-1 | FIXED | Docs correctly assign readiness waiting to `start.sh`. |
| R4-2 | FIXED | Client docs distinguish the newer two-model setup test from old single-model E2E evidence. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| — | — | — | No new verified findings. | Static/local review completed. | — |

What I checked that is fine:

- Both presets consistently map repository, pinned commit, directory, served ID, manifest, `serve.sh`, `start.sh`, and `run_suite.sh`; the Heretic manifest’s 22 data entries exactly match HEAD’s pre-move manifest. Original has 12 unique, well-formed entries.
- `fetch_model.sh` performs the capacity check before download and verifies manifest entries before creating `.download-complete`. `start.sh` waits for the selected model ID.
- Discovery caches for one minute, clears on chat-model 404, and the shared status provider drives header, welcome, composer, pill, and dialog.
- Dialog `jq` lines exactly equal `docs/CLIENTS.md`; both parse. Local pi 0.87.1 documentation supports the config shape; OpenCode 1.18.23 supports provider-filtered models and `-m provider/model`.
- No remaining documentation instructs editing PengePassportPH’s repository/template.
- `git diff --check`, Bash parsing, ShellCheck warning/error-level checks, TypeScript, and changed-source ESLint passed.
- Credential-pattern scan found no matches in all 303 tracked/untracked commit candidates; only three intentional `PASTE-YOUR-KEY-HERE` placeholders.

VERDICT: PASS

