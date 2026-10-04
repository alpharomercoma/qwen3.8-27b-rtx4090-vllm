# Codex QA, held-out eval round 15: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Read-only review complete. All published aggregates and headline/A–B judge totals reconcile with the JSONL artifacts; syntax and shell checks pass. No harmful-response fields, credential-shaped values, routable IPs, or personal home-directory paths were found in the added content.

| Round | Status | Note |
|---|---|---|
| R1 | FIXED | R1-1 through R1-8 verified. |
| R2 | FIXED | R2-1 through R2-8 verified. |
| R3 | FIXED | R3-1 through R3-5 verified. |
| R4 | FIXED | N/A filtering, normalized KL proxy, completeness gate, and staged pull verified. |
| R5 | FIXED | UID cleanup, required metric matrix, wording, and forced restart verified. |
| R6 | FIXED | R6-2 remains an accepted, accurately documented limitation. |
| R7 | FIXED | R7-3 remains an accepted, accurately documented limitation. |
| R8 | FIXED | Recursive harmful-artifact scan, dependencies, and logprob documentation verified. |
| R9 | FIXED | Private staging, bounded metadata, and wording verified. |
| R10 | FIXED | Tests arrive on stdin; artifact matrix validation is present. |
| R11 | FIXED | Strict judge parsing, fixed lists, permissions, and contamination wording verified. |
| R12 | FIXED | Data/cache access checks, row identity metadata, parsed verdicts, and parser bound verified. |
| R13 | FIXED | Legacy override, exact canary count, per-tool checks, and range wording verified. |
| R14 | FIXED | Canonical task rows, current metadata hash, and full-value secret scan verified. R14-4 is intentionally not applicable. |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | medium | `scripts/pull_eval.sh:20-29,32-66` | Pull validation checks artifact structure but never recomputes or compares `summary.json` / `summary.md` metrics to the pulled JSONL rows. A stale or altered summary with correct model IDs can be published beside valid raw evidence. | Recompute and compare all raw-derivable values before swap: counts, caps, tokens, timings, refusal rates, judge totals, and KL. Rebuild pinned gold data for accuracy verification, or explicitly mark it unverified. |
| 2 | medium | `bench/evals/evalsuite.py:505,573-584,624-646` | `score` rejects duplicate base-answer rows, but not duplicate or extraneous judge rows. It also accepts unknown JBB IDs into denominators because it checks only missing expected IDs. This can silently alter a refusal rate before `pull_eval.sh` later detects the malformed artifact. | Validate every task and judge file before scoring: unique IDs exactly equal to the expected set, correct judge ID, valid schema, and no extra rows. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | `score` records the SHA-256 of every input (all answer, verdict and injection-check files; the data files and manifest); `metadata` records the hashes of `summary.json` and `summary.md`; `pull_eval.sh` verifies all of them, so a summary that does not come from the published files is refused. Accuracy against the gold answers is bound through the data hashes and the pinned dataset commits | 34 inputs; a copy with one verdict changed is refused, the real one passes |
| 2 | `score` rejects ids that are not in the dataset, duplicate verdict rows, and verdicts from another judge | Re-scored; passes |
