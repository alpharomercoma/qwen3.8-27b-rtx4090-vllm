# Codex QA, held-out eval round 18: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

All current published aggregates reconcile: counts, tokens, timings, caps, headline/A–B refusal totals, canaries, KL, `summary.json`, `summary.md`, EVAL tables, and README summary. Accuracy can only be checked against `summary.json` because gold labels are absent. No harmful response fields/text, real credentials, IPs/pod IDs, or personal personal home-directory paths were found; retained `/workspace` paths are the accepted operational exception.

| Round-1 finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | Fails closed without root, `setpriv`, and `pkill`; UID/capability limits and repeated cleanup are present. |
| R1-2 | FIXED | Three ordered extraction patterns match the [upstream MMLU-Pro evaluator](https://raw.githubusercontent.com/TIGER-AI-Lab/MMLU-Pro/main/evaluate_from_apiX.py). |
| R1-3 | FIXED | Manifest cap is 4,096; score enforces it and does not overwrite the manifest. |
| R1-4 | FIXED | Exact valid verdicts only; invalids are redacted and fail completeness. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Reproduction uses fetch/serve, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | CUDA prerequisite checks align. |

| Later findings | Status | Note |
|---|---|---|
| R2-1–R2-8 | FIXED | Sandbox, private permissions, timeout cleanup, archival-timing disclosure, and wording are correct. |
| R3-1–R3-5 | FIXED | Capability drop, six-test Holm correction, installer failure handling, and claim scope are correct. |
| R4-1–R4-4 | FIXED | N/A filtering, normalized KL proxy, default completeness failure, and staged pull work. |
| R5-1–R5-4 | FIXED | Required score matrix, repeated UID cleanup, wording, and forced restart work. |
| R6-1 | FIXED | Repeated UID cleanup stops on surviving processes. |
| R6-2 | FIXED / accepted limit | The template matches the [JailbreakBench refusal judge](https://raw.githubusercontent.com/JailbreakBench/jailbreakbench/main/src/jailbreakbench/classifier.py); its documented injection limitation remains accurate. |
| R7-1–R7-2 | FIXED | Key is off vLLM argv; failed headline canaries block verdict creation. |
| R7-3 | FIXED / accepted limit | Documented judge exposure is accurate. |
| R8-1–R8-3 | FIXED | Recursive scan, dependencies, and text-keyed-logprob disclosure are present. |
| R9-1–R9-3 | FIXED | Staging remains private until validation; metadata and wording are correct. |
| R10-1–R10-2 | FIXED | Tests are stdin-delivered and the pull matrix is present. |
| R11-1–R11-4 | FIXED | Strict parser, fixed judge/model set, key permissions, and wording are correct. |
| R12-1–R12-4 | FIXED | Sandbox data/cache access, row identity, verdict parsing, and full-match parsing work. |
| R13-1–R13-4 | FIXED | Legacy override, canary count, tool checks, and range wording are correct. |
| R14-1–R14-3 | FIXED | Canonical rows, source hash, and complete-value secret scan are present. |
| R14-4 | NOT APPLICABLE | Accepted generic pod paths only. |
| R15-1–R15-2 | FIXED | Summary input hashes and verdict schemas/ID sets are validated. |
| R16-1–R16-2, R16-4–R16-5 | FIXED | Verdict validation, pinned item matrix, persisted start time, and wording are correct. |
| R16-3 | PARTLY | File/field allowlists exist, but the allowed harmful-row `error` field remains an arbitrary text channel (finding 3). |
| R17-1–R17-2 | FIXED | Fresh runs generate A/B files; A/B artifacts are hashed and summarized. |
| R17 rescore attestation | PARTLY | The claimed identical re-score is not preserved or verified by metadata (finding 1). |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `evalsuite.py`, `docs/EVAL.md` | `metadata --rescore-of` merely appends environment details, then overwrites the original dataset and summary hashes. It neither compares nor preserves the first-pod hashes, so the documented “byte-identical” datasets and identical summary claim cannot be verified and a divergent re-score could be attested as matching. | Preserve immutable original metadata; append a full rescore record with data and summary hashes, and fail on unequal datasets or summaries. |
| 2 | Medium | `compare_pod.sh`, `evalsuite.py`, `pull_eval.sh` | `EVAL_SCORE_FLAGS=--allow-partial` permits an incomplete capability score, and `pull_eval.sh` accepts it: it checks IDs, but not a nonempty `summary.json.incomplete` or that each ordinary-answer row has a response. A partial denominator can therefore be pulled for publication. | Make pull reject `incomplete`; require one valid non-error answer row per expected item. Do not forward `--allow-partial` in the public pipeline. |
| 3 | Medium | `evalsuite.py`, `pull_eval.sh` | A failed harmful-generation request stores the first 300 characters of an arbitrary HTTP error body. `pull_eval.sh` bans only a `response` field but permits this unrestricted `error` field, leaving a path for server-returned harmful text or sensitive diagnostics into the repository. Current harmful rows contain no errors. | For harmful tasks, retain only a fixed error class/status (or reject error rows outright during pull); never serialize remote error text. |

NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| 1 | `metadata --rescore-of` keeps the run's record, refuses unless the new `summary.md` is byte-identical to the run's (by the hash the run recorded), and appends a re-scoring entry with the original and new code and summary hashes and the rebuilt data's hashes | Re-scored on the second pod against the first pod's metadata: `summary.md` hash equal (`568ed0e6…`), entry `summary_md_identical: true` |
| 2 | `pull_eval.sh` rejects a summary scored from incomplete results and any answer row without an answer (or with an error); `compare_pod.sh` no longer forwards score flags | Pull passes |
| 3 | A failed request records only `HTTP <status>` or the exception class, never server text; harmful-answer rows may not contain an `error` field at all | Code review; no error rows in this run |
