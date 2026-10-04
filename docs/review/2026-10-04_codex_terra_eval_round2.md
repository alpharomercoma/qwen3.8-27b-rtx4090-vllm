# Codex QA, held-out eval round 2: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

| Round-1 | Status | Note |
|---|---|---|
| R1-1 | PARTLY | Main path drops to `nobody`, isolates Python/env and sets limits, but silently falls back to root/current user if `setpriv` is unavailable. |
| R1-2 | FIXED | Three-tier extraction is present and matches the [upstream evaluator](https://github.com/TIGER-AI-Lab/MMLU-Pro/blob/main/evaluate_from_apiX.py). |
| R1-3 | PARTLY | Manifest cap/note and cap enforcement are fixed; published timing rows still omit `max_tokens`. |
| R1-4 | FIXED | Only `REFUSED`/`COMPLIED` verdicts count; invalid verdicts are excluded and current artifacts report zero. |
| R1-5 | FIXED | Error records are excluded from `done` and retried. |
| R1-6 | FIXED | `compare_pod.sh` uses `fetch_model.sh` and `serve.sh`, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | `start.sh` now checks the same CUDA components as bootstrap. |

All publicly checkable score, refusal, length, timing, and aggregate values reconcile with the JSONL/summary artifacts; accuracy necessarily only cross-checks to `summary.json` because gold labels are absent. I found no harmful-JBB `response` fields, credential values, pod IDs, routable IPs, or personal home-directory paths. Loopback endpoints are intentionally present.

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | High | `bench/evals/evalsuite.py:274-277` | HumanEval fails open: absent `setpriv`, model code runs as root/current user despite the documentation’s `nobody` claim. | Require `setpriv` and an unprivileged UID; abort scoring if either is unavailable. Assert the child UID in a test. |
| 2 | Medium | `bench/evals/compare_pod.sh:25`; `bench/evals/evalsuite.py:142-153` | `chmod 700 /workspace/eval/private` happens before the directory exists. On a fresh run, Python creates it with umask defaults, commonly making harmful answers readable by other pod users. | Create the directory first, then enforce and verify mode `0700`. |
| 3 | Medium | `bench/evals/evalsuite.py:293-297` | The 20-second timeout kills only the direct HumanEval process. Since it creates a new session, forked descendants can survive the timeout. | Use `Popen`; on timeout kill the process group and reap it. Document that a determined process still requires stronger container isolation. |
| 4 | Medium | `bench/evals/evalsuite.py:209-212` | An invalid judge reply is stored in `raw`. A malformed judge can echo part of the harmful answer, defeating the no-harmful-answer artifact boundary. Current artifacts have zero invalid rows, but future runs can leak. | Store only an invalid flag and a non-content error class/hash/length; never persist judge free text for harmful rows. |
| 5 | Medium | `results/eval/qwen3.8-27b/timing.jsonl:1`; `results/eval/qwen3.8-27b-heretic/timing.jsonl:1` | All 15 published timing rows lack `max_tokens`, although current producer code writes it. The checked-in evidence was not regenerated from the corrected producer. | Regenerate/pull timing artifacts, then rerun `score` and `report`. |
| 6 | Medium | `docs/EVAL.md:142-143` | Different quantizers make the observed capability gap confounded; it is not necessarily an “upper bound” on abliteration cost. A favorable Heretic quantization could mask a larger abliteration loss. | Say the effect cannot be bounded or attributed without a matched-quantization control. |
| 7 | Medium | `docs/EVAL.md:89-92`; `docs/EVAL.md:148-150` | The 7–23% judge range is not a bound on the true refusal rate: both judges are models under test and may share or oppose bias. | Describe it as variation across these two judges, not a bound; use an independent validated judge for a substantive estimate. |
| 8 | Low | `docs/EVAL.md:20-21` | “Answers are the same length (±10%)” is unsupported: the ordinary-instruction experiment forces exactly one output token, while harmful outputs differ by about 24% (206 vs 256 mean tokens). | Limit the claim to first-token similarity, or report task-specific output lengths. |

NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| 1 | `score` exits unless it can drop to `nobody` with `setpriv` | Re-scored on the pod |
| 2 | `evalsuite.py run` creates the private directories itself, mode 0700 | `ls -ld /workspace/eval/private`: `drwx------` |
| 3 | `Popen` + `killpg` of the program's session after it ends or times out | No `nobody` processes left after scoring |
| 4 | Invalid judge replies store only `ERROR` or `OTHER (n chars)` | Code review |
| 5 | Documented that this run's timing rows predate `max_tokens` (evidence not edited) | EVAL.md Limits, results/eval/README.md |
| 6, 7, 8 | Reworded: quantizer confound, judge spread not a bound, length claim scoped with numbers | EVAL.md |
