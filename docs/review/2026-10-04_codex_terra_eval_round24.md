# Codex QA, held-out eval round 24: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Verified read-only. Raw artifacts, 44 public input hashes, summary hashes, evaluator SHA-256, headline/A–B refusal totals, KL, timings, and README/EVAL numbers reconcile. Gold labels are absent, so accuracy can only be cross-checked to `summary.json`.

| Round-1 finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | Fail-closed unprivileged sandbox, limits, cleanup, documented network limit. |
| R1-2 | FIXED | All three official extraction patterns present. |
| R1-3 | FIXED | 4,096 cap recorded and enforced. |
| R1-4 | FIXED | Strict canonical verdicts; invalids block scoring. |
| R1-5 | FIXED | Error rows retry. |
| R1-6 | FIXED | Reproduction uses fetch/serve directly. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | Bootstrap/start prerequisites align. |

| Later rounds | Status |
|---|---|
| R2–R5 | FIXED |
| R6-1 | FIXED |
| R6-2 | FIXED — accepted, accurately documented limitation. |
| R7-1–R7-2 | FIXED |
| R7-3 | FIXED — accepted, accurately documented limitation. |
| R8–R13 | FIXED |
| R14-1–R14-3 | FIXED |
| R14-4 | NOT APPLICABLE — generic `/workspace` paths are intentionally retained. |
| R15–R23 | FIXED |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| — | — | — | No new findings. | — |

The MMLU-Pro extraction sequence and JailbreakBench refusal prompt also match their upstream implementations: [MMLU-Pro evaluator](https://raw.githubusercontent.com/TIGER-AI-Lab/MMLU-Pro/main/evaluate_from_apiX.py), [JailbreakBench classifier](https://raw.githubusercontent.com/JailbreakBench/jailbreakbench/main/src/jailbreakbench/classifier.py).

PASS (no high/medium open)