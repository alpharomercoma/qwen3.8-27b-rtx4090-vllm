# Codex QA, held-out eval round 10: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

| R1 finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | HumanEval Python runs as UID 65533 with isolated env, no-new-privs, dropped capabilities, limits, and key checks. |
| R1-2 | FIXED | All three official MMLU-Pro extraction patterns are present. |
| R1-3 | FIXED | Manifest cap is 4096, enforced without overwrite; historical timing limitation is disclosed. |
| R1-4 | FIXED | Judge parsing is strict; invalid replies are excluded and redacted. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Evaluation uses `fetch_model.sh` and `serve.sh`, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | CUDA prerequisite checks align. |

R2–R5, R6-1, R7-1/2, R8, and R9 remain fixed. R6-2 and R7-3 remain the accepted, accurately documented judge-injection limitations; I did not re-raise them.

Raw JSONL counts, timing, token totals, headline and A/B judge rates, canaries, KL, `summary.json`, `summary.md`, EVAL tables, and README headline reconcile. Accuracy can only be checked against `summary.json` because gold data is absent. I found no harmful-answer fields/text, credentials, pod IDs, routable IPs, or personal home-directory paths in this change set.

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `bench/evals/evalsuite.py:395-401` | HumanEval candidate code runs from a readable `prog.py` that already contains the official test source appended after the candidate code. An adversarial completion can read `__file__`, derive expected cases, and tailor or interfere with execution; UID/capability isolation does not protect score integrity. Current 328 HumanEval answers show no obvious self-file, workspace, file-open, trace, or network indicators. | Run candidates in a disposable test boundary with no test/data/workspace visibility during candidate initialization; use a separately controlled runner and resource/device quotas. |
| 2 | Medium | `scripts/pull_eval.sh:12-24` | Pull validation checks only `manifest.json`, `summary.json`, and `summary.md`. A successful but incomplete remote results tree can replace the local evidence while omitting raw task rows, judge artifacts, canaries, or run metadata. | Require and parse the full expected artifact matrix: both models’ task JSONLs, judge files, canaries, prompt variants, timing, and `run_metadata.json`; validate row counts against the manifest before swapping. |

`VLLM_API_KEY` is a supported vLLM server configuration mechanism per the [vLLM documentation](https://github.com/vllm-project/vllm/blob/main/docs/getting_started/quickstart.md).

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | The HumanEval program reaches Python on stdin (`python -I -`), so no file holds the tests; the scratch directory is empty. Documented that, as in the official harness, candidate and tests share one process | Re-scored: 154 / 164 for both, same 2 / 2 split |
| 2 | `pull_eval.sh` requires `run_metadata.json` and checks every model's task files (unique ids = manifest items), every judge's verdict files, timing and canaries before swapping | A copy missing one judge file is rejected; the complete copy passes |
