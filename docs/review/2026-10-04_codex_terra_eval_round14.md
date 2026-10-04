# Codex QA, held-out eval round 14: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Round 1 status

| Finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | Fails closed into the UID/capability-limited sandbox; network limitation is disclosed. |
| R1-2 | FIXED | All three MMLU-Pro extraction patterns exist. |
| R1-3 | FIXED | Cap enforcement and manifest behavior are correct; legacy timing omission is disclosed. |
| R1-4 | FIXED | Exact Yes/No parsing; invalid verdicts excluded. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Reproduction uses `fetch_model.sh` and `serve.sh`, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | CUDA prerequisite checks align. |

R2–R8, R10–R13 are FIXED, including the accepted/documented R6-2 and R7-3 limits. R9-1 and R9-3 are FIXED; R9-2 is PARTLY fixed because run metadata exists but does not match the committed evaluator source.

Published artifacts reconcile: 3,824 rows/model; token totals, timings, caps, refusal counts, A/B sensitivity counts, canaries, and KL match `summary.json`/`summary.md`/EVAL/README. Accuracy can only be cross-checked to `summary.json` because gold data is absent. No harmful response fields, credential values, personal home-directory paths, IPs, or pod IDs were found. The headline JBB prompt matches the upstream refusal judge. [JailbreakBench source](https://github.com/JailbreakBench/jailbreakbench/blob/main/src/jailbreakbench/classifier.py)

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `evalsuite.py:149`, `evalsuite.py:161`, `pull_eval.sh:31` | Retried/stale rows are appended, while scoring and pulling collapse IDs into sets/dicts. Duplicate attempts can therefore be accepted and prior errors disappear from reported error counts. Current artifacts have no duplicates. | Atomically rewrite each task file with one canonical row per ID, or reject duplicate IDs in both scoring and pulling. |
| 2 | Medium | `run_metadata.json:21` | Recorded `evalsuite_sha256` (`b2ab…`) differs from the committed evaluator (`a90d…`). The metadata cannot bind the published summary to the current harness. | Regenerate final metadata after the code freeze; record separate generation/scoring/report hashes and verify them during pull. |
| 3 | Medium | `evalsuite.py:371` | The command-line secret scan extracts only contiguous 24+ character fragments. Valid shorter or punctuation-separated API keys can evade it, despite the fail-closed claim. | Compare complete parsed secret values from the protected files, not length-filtered fragments. |
| 4 | Low | `round1.md:7` | The QA records contain generic absolute `/workspace` paths in rounds 1, 2, 11, and 12. No secret values are present, but this conflicts with the literal “no paths” requirement. | Replace absolute operational paths with generic labels if that requirement is intentional. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | After each task `run` rewrites the file atomically to one row per id (the last current answer, else the last attempt) and records `rows_dropped` in timing; `score` and `pull_eval.sh` reject duplicate ids | This run's files have no duplicates; scoring and pull pass |
| 2 | Metadata regenerated after the code freeze; `pull_eval.sh` refuses results whose `evalsuite_sha256` is not the checkout's. EVAL.md Limits says which revisions generated and which scored | Pull passes the hash check |
| 3 | The command-line scan compares complete key values (the whole `.api_key`, the key field of each team-key line, every line of the tunnel key files; 8+ characters) | Re-scored; scan passes |
| 4 | Not changed: the QA records name generic pod paths (`/workspace/...`), which are operational, not personal | — |
