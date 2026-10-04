# Codex QA, held-out eval round 20: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

### Round 1 status

| Finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | HumanEval now fails closed and uses the dedicated unprivileged UID, reduced privileges, empty environment, limits, and cleanup. |
| R1-2 | FIXED | All three ordered MMLU-Pro extraction patterns are present; the local implementation is equivalent to the upstream evaluator. [Upstream](https://raw.githubusercontent.com/TIGER-AI-Lab/MMLU-Pro/main/evaluate_from_apiX.py) |
| R1-3 | FIXED | Manifest cap is 4096, is not overwritten, and over-cap outputs fail scoring. |
| R1-4 | FIXED | Verdict parsing is strict; invalid rows are redacted, excluded, and completeness-gated. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Reproduction uses `fetch_model.sh` and `serve.sh`, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | Bootstrap and start CUDA/tool checks align. |

| Later round(s) | Status |
|---|---|
| R2–R5 | FIXED |
| R6-1 | FIXED |
| R6-2 / R7-3 | FIXED as accepted, accurately documented limitations; not re-raised. The headline template matches JailbreakBench’s refusal judge. [Upstream](https://raw.githubusercontent.com/JailbreakBench/jailbreakbench/main/src/jailbreakbench/classifier.py) |
| R7-1–R7-2 | FIXED |
| R8–R13 | FIXED |
| R14-1–R14-3 | FIXED |
| R14-4 | NOT APPLICABLE, as directed. |
| R15–R16 | FIXED |
| R17-1–R17-2 | FIXED; A/B artifacts are generated, hashed, and summarized. The broader rescore/data-equality claim is only partly attested; see finding 1. |
| R18-1 | FIXED for byte-identical `summary.md`; broader “every number” claim remains unsupported; see finding 1. |
| R18-2–R18-3 | FIXED |
| R19-1 | FIXED in code: headline rows are canonical `Yes`/`No`; README wording is now inaccurate; see finding 2. |

Checks: all 3,824 rows per model are present with zero errors; JSONL-derived timing/token aggregates, headline/A/B refusal totals, canaries, caps, and KL match `summary.json`/`summary.md`. Metadata hashes match both summaries, the evaluator hash matches current code, and all 44 published input hashes verify. All 14 harmful-JBB JSONLs contain no `response` field. No credential-shaped values or non-loopback IPs were found.

### New findings

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | medium | `evalsuite.py`, `EVAL.md` | The rescore gate compares only `summary.md`. It does not compare rebuilt dataset hashes to original hashes, nor semantic `summary.json` fields omitted from the report, including IFEval instruction-level strict accuracy and prompt-sensitivity values. Thus “datasets byte-identical” and “every number came out the same” are stronger than the retained evidence. | Preserve original data/input hashes before overwrite and compare them; compare a canonical projection containing every published metric, interval, and sensitivity value, or narrow the claim to identical `summary.md`. |
| 2 | medium | `README.md`, `evalsuite.py` | The README calls `raw` the judge’s “exact reply,” but R19 deliberately stores a canonical parsed `Yes`/`No`; valid source replies such as lowercase or one trailing period are not retained verbatim. | Describe `raw` as the canonical parsed label, or store the constrained original valid reply separately. |
| 3 | low | `round16.md` | A generic personal home-directory placeholder remains in a QA record. It is not a personal path, but it defeats a literal no-`home-directory ` scan. | Replace it with “personal home paths.” |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | EVAL.md narrowed: `summary.md` (every number in the tables) byte-identical by hash; the dataset hashes were compared by hand, because the run's `summary.json` was not kept. New `metadata --original-summary`: for future re-scorings, also requires the same dataset hashes and the same `tasks`, KL and prompt-sensitivity values | Re-scored again: `summary.md` identical; pull passes |
| 2 | Results README: `raw` is the canonical label of a reply that had to be exactly Yes/No | — |
| 3 | QA records reworded so they name no home-directory path, not even as a placeholder | a search for home-directory paths finds none in them |
