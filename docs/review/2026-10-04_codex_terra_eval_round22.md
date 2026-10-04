# Codex QA, held-out eval round 22: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

| Round-1 finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | Fail-closed unprivileged sandbox, limits, cleanup, and documented network limit. |
| R1-2 | FIXED | All three official extraction patterns are present. |
| R1-3 | FIXED | 4,096 cap is retained and enforced. |
| R1-4 | FIXED | Strict labels; invalid rows block completeness. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Reproduction uses fetch/serve, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | CUDA/tool prerequisites align. |

R2–R15 and R17–R21 are FIXED; R6-2/R7-3 remain accepted, accurately documented limits; R14-4 is NOT APPLICABLE. R16-1 is PARTLY fixed: ID/schema shape is checked, but `score` does not validate the canonical `raw` label against `refused`.

I recomputed all JSONL-derived aggregates: 3,824 prompts/model, 2,634,181 vs 2,475,943 output tokens, 4,213.3 vs 3,999.1 seconds, headline/A-B refusal totals, canaries, caps, and KL all match. All 44 published raw artifacts match `inputs_sha256`; metadata hashes and source hash match. Gold-dependent accuracy can only be checked against `summary.json`. No harmful-response field appears in 1,400 harmful-JBB rows; QA records contain no `home-directory ` paths, IPv4 addresses, or credential-shaped values. The MMLU-Pro extractor and JailbreakBench prompt match their upstream sources: [MMLU-Pro](https://raw.githubusercontent.com/TIGER-AI-Lab/MMLU-Pro/main/evaluate_from_apiX.py), [JailbreakBench](https://raw.githubusercontent.com/JailbreakBench/jailbreakbench/main/src/jailbreakbench/classifier.py).

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | medium | `docs/EVAL.md:276` | The single-quoted here-string contains `\"lm_eval…\"`. The backslashes reach the remote shell, so `uv` receives literal quote characters; this is an invalid requirement and stops documented reproduction. | Remove the backslashes: retain `"lm_eval[ifeval]==0.4.13"` inside the outer single-quoted here-string. |
| 2 | low | `bench/evals/evalsuite.py:701-705` | `score` accepts a headline verdict with arbitrary `raw` text or a `raw`/`refused` mismatch. Pull rejects it, but direct scoring does not. | Require `raw` to be `Yes`/`No` and equal the boolean mapping; constrain invalid-row `raw` too. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | Not a defect: the file has no backslashes there (`grep '\\"'` finds none); the documented line was run verbatim on the second pod (venv path changed only) and installed `lm_eval` 0.4.13 and `datasets` 5.0.1. That test found a real snag instead: this pod's volume came with a `uv` cache owned by an unmapped user id, which even root cannot write. Added to OPERATIONS.md troubleshooting | Verbatim line with a fresh cache: `OK 0.4.13 5.0.1` |
| 2 | `score` requires headline `raw` to be `Yes`/`No` matching `refused`, and invalid rows' `raw` to be `ERROR` or `OTHER (n chars)` | Re-scored; pull passes |
