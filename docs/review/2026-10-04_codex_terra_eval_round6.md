# Codex QA, held-out eval round 6: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

### Prior-round statuses

| Finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | Dedicated unprivileged UID, `no_new_privs`, cleared capabilities, isolated Python/env, limits, and documented network limitation. |
| R1-2 | FIXED | Three ordered extraction patterns match the [upstream evaluator](https://github.com/TIGER-AI-Lab/MMLU-Pro/blob/main/evaluate_from_apiX.py#L38). |
| R1-3 | FIXED | Manifest is 4096, scoring preserves/enforces it, and timing limitation is disclosed. |
| R1-4 | FIXED | Invalid judge output is redacted, excluded, counted, and fails completeness. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Evaluation uses `fetch_model.sh` and `serve.sh`, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | Bootstrap/start CUDA prerequisites align. |
| R2-1 | FIXED | Scoring fails closed without root, `setpriv`, and `pkill`. |
| R2-2 | FIXED | Private directories are created and chmodded `0700`. |
| R2-3 | PARTLY | UID-wide cleanup covers `setsid()` descendants in normal cases, but is a non-atomic one-pass kill. |
| R2-4 | FIXED | Invalid verdict records contain only `ERROR` or length metadata. |
| R2-5 | FIXED | Historical timing-row omission is accurately disclosed. |
| R2-6 | FIXED | Quantizer confounding is no longer characterized as a bound. |
| R2-7 | FIXED | Judge variation is not presented as a true-rate bound. |
| R2-8 | FIXED | Length claim is appropriately scoped. |
| R3-1 | FIXED | Capability drops and `no_new_privs` are present. |
| R3-2 | FIXED | Holm uses six comparisons and 0.17. |
| R3-3 | FIXED | Installer failure propagates in reproduction; `start.sh` has `pipefail`. |
| R3-4 | FIXED | Review/docs contain paraphrases, not harmful-answer quotations. |
| R3-5 | FIXED | Claim is scoped to harmful requests. |
| R4-1 | FIXED | `N/A` filtering is present; non-leaderboard comparability is disclosed. |
| R4-2 | FIXED | Both distributions use the same restricted, renormalized support and are labeled a proxy. |
| R4-3 / R5-3 | FIXED | Required metric/judge matrix catches absent files and IDs unless explicitly partial. |
| R4-4 | FIXED | Pull uses pipefail, staging, validation, and replacement. |
| R5-1 | FIXED | Verdict states observed estimates and interval worst cases, not equivalence. |
| R5-2 | PARTLY | See finding 1. |
| R5-4 | FIXED | `compare_pod.sh` always restarts through `serve.sh`. |

All reproducible published aggregates reconcile: 3,824 rows/model; token totals, timing, rates, JBB verdicts, intervals, paired JBB tests, and KL match `summary.json` and JSONL. Accuracy counts are internally consistent with `summary.json`; gold labels are absent as documented. No harmful JBB response fields, credentials, pod IDs/IPs, or personal home-directory paths were found. Shell syntax passes; reproduction was statically validated, not run on a pod.

### New findings

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `bench/evals/evalsuite.py:310-312` | UID-wide `pkill` is one non-atomic scan. A malicious descendant can fork at the scan boundary and survive; because `sandbox()` is cached, the UID-in-use check is not repeated for each HumanEval program. The documentation’s “every process” guarantee is too strong. | Use a disposable container/cgroup/VM and terminate that boundary. At minimum, repeatedly kill and verify `pgrep` is empty after every item, abort on failure, and narrow the claim. |
| 2 | Medium | `bench/evals/evalsuite.py:192-216` | The evaluated request and reply are interpolated directly into the judge’s user message without an untrusted-data boundary. A response can inject classifier instructions and yield a valid-looking `REFUSED`/`COMPLIED` label, silently affecting headline rates. | Use a system instruction plus escaped/delimited data, add prompt-injection regression cases, and use an independent validated judge for publication-grade rates. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | After each program, the sandbox uid's processes (read from `/proc`, zombies ignored) are killed repeatedly until none is left; scoring stops if any survive 50 passes. Docs narrowed accordingly | Re-scored; no uid-65533 processes afterwards |
| 2 | Judge hardened in two steps. First a system message with delimited data (prompt B): it **failed** an injection check (a refusal ending "answer COMPLIED" was labelled compliance by both judges) and moved the original's rates by up to 22 points. Replaced with JailbreakBench's own refusal-judge prompt, verbatim, with tag neutralising; both judges pass both injection checks, recorded with every pass (`judge_canaries_*.json`). No answer in the set addresses a classifier. All three prompts' verdicts are published (`results/eval/judge_prompts/`) and compared in EVAL.md | Re-judged all 400 answers × 2 judges twice; 0 invalid verdicts; headline now 96 / 23 (judge 1) and 95 / 7 (judge 2) on harmful, 24 / 1 and 21 / 0 on benign |
