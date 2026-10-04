# Codex QA, held-out eval round 17: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Static/artifact review complete; I did not run a live pod. Headline docs/README figures reconcile with `summary.json`, `summary.md`, and JSONL: 3,824 prompts/model, zero errors, primary judge counts 96/23 harmful and 24/1 benign, and passed canaries. No harmful-response fields, credentials, real personal home-directory paths, or harmful text in the new QA records found.

| Prior set | Status |
|---|---|
| R1 | R1-1 through R1-8: **FIXED**. Sandbox now fails closed and uses an isolated UID; extraction matches the [official evaluator](https://github.com/TIGER-AI-Lab/MMLU-Pro/blob/main/evaluate_from_apiX.py); cap, retry, statistics, and reproduce fixes are present. |
| R2 | R2-1 through R2-8: **FIXED**. Private paths are protected, cleanup repeatedly kills the dedicated UID, invalid replies are redacted, and limits are accurately disclosed. |
| R3 | R3-1 through R3-5: **FIXED**. Capability dropping, Holm’s six-test correction, pipeline failure handling, and wording are correct. |
| R4 | R4-1 through R4-4: **FIXED**. The N/A filter exists, KL is consistently normalized as a proxy, scoring fails closed on incomplete data, and pull staging is validated before swap. |
| R5 | R5-1 through R5-4: **FIXED**. Required-metric/judge matrix, UID cleanup, wording, and forced server restart are present. |
| R6 | R6-1: **FIXED**. R6-2: **FIXED as an accepted, accurately documented limitation**; A/B and headline counts match their artifacts. |
| R7 | R7-1 and R7-2: **FIXED**. R7-3: **FIXED as an accepted, accurately documented limitation**. |
| R8 | R8-1 through R8-3: **FIXED**. |
| R9 | R9-1 through R9-3: **FIXED**. |
| R10 | R10-1 and R10-2: **FIXED**. |
| R11 | R11-1 through R11-4: **FIXED**. |
| R12 | R12-1 through R12-4: **FIXED**. |
| R13 | R13-1 through R13-4: **FIXED**. |
| R14 | R14-1 through R14-3: **FIXED**. R14-4: **NOT APPLICABLE**, as directed. |
| R15 | R15-1 and R15-2: **FIXED**. |
| R16 | R16-1 through R16-5: **FIXED**. |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `compare_pod.sh:35`, `pull_eval.sh:53`, `EVAL.md:267` | Clean reproduction fails at `pull_eval.sh`: it requires 16 A/B sensitivity verdict files plus B canaries, but `compare_pod.sh` only generates the headline JailbreakBench prompt and canaries. | Add a versioned A/B prompt runner to `compare_pod.sh`, including its canary behavior; or remove these artifacts/table from the required reproducible output. |
| 2 | Medium | `evalsuite.py:691`, `pull_eval.sh:90`, `EVAL.md:114` | The A/B sensitivity JSONLs used by the published table are schema/count-checked but excluded from `summary.json`’s input hashes. Their verdict counts could change without invalidating `summary.json`, `summary.md`, or metadata hashes. | Hash A/B files and canaries in `summary.json`; preferably compute/store the sensitivity aggregates there and generate the documentation table from them. |

NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| 1 | Prompts A and B are now selectable judge prompts (`judge --prompt A|B`, text in `evalsuite.py`, injection checks recorded but not blocking), and `compare_pod.sh` runs all three prompts with both judges, so a clean reproduction produces every file `pull_eval.sh` requires. This run's A/B files are kept: the pod holding the harmful answers was stopped during the re-judge, and harmful answers are never copied elsewhere | `bash -n`; the stopped pod's re-judge did not finish |
| 2 | `score` hashes the prompt-A/B files into `inputs_sha256` and stores their refusal counts (`judge_prompt_sensitivity`), which match the EVAL.md table | Re-scored on a second fresh RTX 4090 pod: datasets rebuilt from the pinned commits byte-identical, `summary.md` identical, A 95/91 and B 84/73 for the original's harmful answers |
| — | Found while re-scoring: on a fresh pod the Reproduce line's log redirect failed before `bootstrap.sh` created `/workspace/logs`; it now creates it first | Bootstrap passed on the new pod |
