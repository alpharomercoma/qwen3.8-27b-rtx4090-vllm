# Codex QA, held-out eval round 19: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Evidence check: raw-derivable counts, timings, refusal totals, A/B results, hashes, and README wording match. Accuracy matches `summary.json`; gold labels are not committed, so it cannot be independently recomputed.

| Prior round | Status |
|---|---|
| R1 | R1-1–R1-8: **FIXED** |
| R2 | R2-1–R2-8: **FIXED** |
| R3 | R3-1–R3-5: **FIXED** |
| R4 | R4-1–R4-4: **FIXED** |
| R5 | R5-1–R5-4: **FIXED** |
| R6 | R6-1: **FIXED**; R6-2: **FIXED / accepted documented limit** |
| R7 | R7-1–R7-2: **FIXED**; R7-3: **FIXED / accepted documented limit** |
| R8 | R8-1–R8-3: **FIXED** |
| R9 | R9-1–R9-3: **FIXED** |
| R10 | R10-1–R10-2: **FIXED** |
| R11 | R11-1–R11-4: **FIXED** |
| R12 | R12-1–R12-4: **FIXED** |
| R13 | R13-1–R13-4: **FIXED** |
| R14 | R14-1–R14-3: **FIXED**; R14-4: **NOT APPLICABLE** |
| R15 | R15-1–R15-2: **FIXED** |
| R16 | R16-1–R16-5: **FIXED** |
| R17 | R17-1–R17-2: **FIXED**; rescore dataset hashes and identical `summary.md` attestation match. |
| R18 | R18-1–R18-3: **FIXED** |

| # | Severity | File:line | Finding | Suggested fix |
|---|---|---|---|---|
| 1 | medium | `bench/evals/evalsuite.py:256-258,335-336`; `scripts/pull_eval.sh:85-88` | `judge_word` deliberately accepts valid headline replies such as `yes`, `Yes.`, and `No.`, and `score` accepts the resulting verdict. But `pull_eval.sh` accepts only raw `Yes`/`No`. A valid clean run can therefore finish scoring but fail the documented pull/reproduction step. | Store a canonical `Yes` or `No` in headline verdict rows after parsing, or make pull use the same full-match parser and normalize before checking consistency. |

Audit note: an attempted syntax-check command inadvertently generated the ignored file `bench/evals/__pycache__/evalsuite.cpython-314.pyc`; I left it untouched to honor the read-only request.

NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| 1 | Headline verdict rows store the canonical `Yes` / `No` after parsing, matching what `pull_eval.sh` requires | This run's 800 replies were already exact; re-scored on the second pod (`summary.md` identical to the run's), pull passes |
