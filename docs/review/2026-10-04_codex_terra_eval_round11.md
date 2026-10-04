# Codex QA, held-out eval round 11: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

## Prior-finding status

| Round | Status |
|---|---|
| R1 | R1-1 FIXED; R1-2 FIXED; R1-3 FIXED; R1-4 PARTLY — parser accepts punctuation-modified labels; R1-5–R1-8 FIXED. |
| R2 | R2-1–R2-8 FIXED. |
| R3 | R3-1–R3-5 FIXED. |
| R4 | R4-1–R4-4 FIXED. |
| R5 | R5-1–R5-4 FIXED. |
| R6 | R6-1 FIXED; R6-2 FIXED as the accepted, accurately documented injection-sensitive limitation. |
| R7 | R7-1–R7-2 FIXED; R7-3 FIXED as the accepted, accurately documented limitation. |
| R8 | R8-1–R8-3 FIXED. |
| R9 | R9-1–R9-3 FIXED. |
| R10 | R10-1 FIXED; R10-2 PARTLY — pull validation still trusts an unvalidated remote model/judge list and omits A/B artifact presence checks. |

The raw evidence reconciles: 3,824 rows/model, token totals, timing, refusal counts, canaries, A/B/headline judge rates, KL, `summary.json`, `summary.md`, EVAL tables, and README headline. No harmful-response field exists in any `jbb_harmful*.jsonl`; no credentials, routable IPs, pod IDs, or personal home-directory paths were found. Only intentional loopback addresses remain.

## New findings

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `evalsuite.py` | `judge_word()` removes all nonletters, so malformed values such as `Y.e.s` and `n-o` are silently counted as valid verdicts. This conflicts with the documented exact Yes/No rule and partially reopens R1-4. | Accept only `response.strip().upper()` equal to `YES` or `NO`; record all other values as invalid. |
| 2 | Medium | `pull_eval.sh` | Validation derives required models/judges from the remote `summary.json`; an empty list skips every raw-row and verdict check. It also does not require the A/B judge artifacts supporting EVAL’s prompt-sensitivity table. | Assert the expected two model IDs and two headline judges, then explicitly require/count A/B artifacts and applicable canary records. |
| 3 | Medium | `bootstrap.sh` | An existing `/workspace/.api_key` is not chmodded or ownership-checked. A preexisting permissive key remains readable despite SECURITY claiming mode 600. HumanEval later aborts, but the live service key remains exposed locally. | On every bootstrap, verify root ownership and enforce `chmod 600 /workspace/.api_key`; fail if that cannot be established. |
| 4 | Low | `EVAL.md` | “Contamination … affects both equally” is stronger than the evidence supports: different abliteration and quantization can change how memorized material is expressed. | Say contamination may inflate absolute scores and does not necessarily cancel in the comparison. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | Judge reply must be exactly "Yes" or "No" (any case, one trailing full stop allowed); the exact reply is stored as `raw` | Re-judged all 800 verdicts: every reply was exactly `Yes` or `No`; all refusal counts identical |
| 2 | `pull_eval.sh` asserts the two expected models and judges, and requires complete prompt-A/B verdict files | Pull passes |
| 3 | `bootstrap.sh` makes existing key files root-only (`chown root`, mode 600; `.secrets` without group/other access) and stops if `.api_key` is not | `bash -n` |
| 4 | Contamination: may inflate absolute scores and need not cancel between the models | EVAL.md |
