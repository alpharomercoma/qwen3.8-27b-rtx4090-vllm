# Codex QA, held-out eval round 13: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

| Prior findings | Status | Note |
|---|---|---|
| R1-1–R1-8 | FIXED | Sandbox, extraction, caps, retry, reproduction, median, and CUDA alignment are present. R1-2 matches the [upstream MMLU-Pro API evaluator](https://github.com/TIGER-AI-Lab/MMLU-Pro/blob/main/evaluate_from_apiX.py). |
| R2-1–R2-8 | FIXED | Fail-closed UID sandbox, private directory modes, teardown, redaction, and documentation fixes hold. |
| R3-1–R3-5 | FIXED | Capability/no-new-privileges, Holm count, installer failure propagation, and wording are corrected. |
| R4-1–R4-4 | FIXED | N/A filtering, normalized KL proxy, completeness gate, and staged pull are present. |
| R5-1–R5-4 | FIXED | Claims are bounded; UID-wide cleanup, fixed metric matrix, and forced server restart work. |
| R6-1 | FIXED | Repeated UID cleanup verifies no live sandbox processes remain. |
| R6-2 | FIXED | Accepted, accurately documented injection-sensitive judge limitation; not re-raised. |
| R7-1 | FIXED | vLLM key is no longer in argv; source and metadata show redaction. |
| R7-2 | PARTLY | Failed non-empty canaries block, but an empty canary array is accepted as “passed.” |
| R7-3 | FIXED | Accepted, accurately documented limitation; not re-raised. |
| R8-1 | FIXED | Harmful JSONL validation is recursive. |
| R8-2 | PARTLY | Packages are installed, but the claimed two-tool verification succeeds if either tool exists. |
| R8-3 | FIXED | Text-keyed top-logprob limitation/counts are documented and match data. |
| R9-1–R9-3 | FIXED | Staging remains private through validation; metadata is bounded by `--since`; wording is scoped. |
| R10-1 | FIXED | Tests arrive on stdin; root-only data/cache checks and same-process limit are documented. |
| R10-2 | PARTLY | Main artifact matrix is checked, but A/B verdict content and canary cardinality are not fully validated. |
| R11-1–R11-4 | FIXED | Strict parser, fixed remote model/judge set, key permissions, and contamination wording are correct. |
| R12-1 | FIXED | Data/HF-cache access is blocked for the sandbox UID. |
| R12-2 | PARTLY | New rows carry identity metadata, but legacy rows without it are still accepted. |
| R12-3 | PARTLY | Headline verdicts are parsed, but A/B files are only counted and empty canary arrays pass. |
| R12-4 | FIXED | `fullmatch` limits a reply to Yes/No with at most one trailing period. |

Recomputed non-gold evidence matches `summary.json`, `summary.md`, `docs/EVAL.md`, and the README headline: 3,824 rows/model; 2,634,181 vs 2,475,943 tokens; 4,213.3 vs 3,999.1 seconds; headline and A/B refusal counts match. Capability accuracy can only be checked against `summary.json` because gold labels are absent. No response fields appeared in any of the 14 harmful-JBB JSONLs; no personal home-directory paths, routable IPs, pod IDs, or credential values were detected in the new review/evaluation material. Shell/Python syntax checks passed; reproduction was statically validated, not run on a pod.

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `bench/evals/evalsuite.py:147-150,483-487` | Missing `prompt_sha256` and `max_tokens` are treated as current values. Thus legacy rows resume by ID alone and score without proving prompt/cap identity. | Require both fields by default; provide an explicit, recorded legacy override only for archival scoring. |
| 2 | Medium | `scripts/pull_eval.sh:47-55`; `bench/evals/evalsuite.py:595-598` | An empty headline canary list passes; A/B verdict files are line-counted only. Duplicate IDs, invalid schemas, wrong judges, or malformed variant verdicts can enter the public evidence. | Require exactly the expected headline canaries and passed labels; parse A/B rows for unique matching IDs, judge ID, allowed raw labels, and `refused` consistency. |
| 3 | Medium | `pod/bootstrap.sh:12`; `pod/start.sh:22` | `command -v a b ...` succeeds when any supplied command exists. `start.sh` can skip bootstrap with required tools absent; bootstrap does not truly verify both `setpriv` and `pkill`. | Check every command individually in a loop or chained `&&` condition. |
| 4 | Low | `docs/EVAL.md:126-127` | The claim that the harmful-request comparison is “−73 to −88 points” under every prompt is false. Prompt A gives −72/−84; prompt B gives −63/−69. | Say the direction holds under every prompt, with a cross-prompt range of −63 to −88 points. |

NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| 1 | Rows without `prompt_sha256`/`max_tokens` are redone by `run` and rejected by `score` unless `--legacy-rows`, whose use is counted in `summary.json` (`legacy_rows`). This run is scored with it, as documented | Default scoring exits 1 on this run; with `--legacy-rows` it passes and records 3,824 legacy rows per model |
| 2 | Exactly two passed injection checks required (score and pull); prompt-A/B verdict files parsed (unique ids = answers, judge, `raw` REFUSED/COMPLIED consistent with `refused`) | Pull passes |
| 3 | Every required tool checked on its own in `bootstrap.sh` and `start.sh` (`start.sh` now also requires `setpriv` and `pkill`) | `bash -n` |
| 4 | "63 to 88 points depending on prompt and judge" | Prompt A −72/−84, B −63/−69, JailbreakBench −73/−88 |
