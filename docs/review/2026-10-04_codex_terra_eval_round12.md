# Codex QA, held-out eval round 12: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Recomputed artifacts reconcile where possible: counts, caps, timing, refusal/A-B judge totals, KL, `summary.json`, `summary.md`, EVAL, and README. Capability accuracy can only be checked against `summary.json` because gold labels are absent. No harmful-response fields, secrets, pod IDs, IPs, or personal home-directory paths were found in the changed artifacts. The MMLU-Pro extraction sequence matches the upstream evaluator. [Upstream evaluator](https://github.com/TIGER-AI-Lab/MMLU-Pro/blob/main/evaluate_from_apiX.py)

| Round | Status |
|---|---|
| R1 | R1-1,2,3,4,5,6,7,8: **FIXED** |
| R2 | R2-1–8: **FIXED** |
| R3 | R3-1–5: **FIXED** |
| R4 | R4-1–4: **FIXED** |
| R5 | R5-1–4: **FIXED** |
| R6 | R6-1: **FIXED**; R6-2: **FIXED** as the accepted, accurately documented limitation |
| R7 | R7-1–2: **FIXED**; R7-3: **FIXED** as the accepted, accurately documented limitation |
| R8 | R8-1–3: **FIXED** |
| R9 | R9-1,3: **FIXED**; R9-2: **PARTLY** — metadata exists, but does not delimit one evaluation run |
| R10 | R10-1: **NOT FIXED**; R10-2: **PARTLY** |
| R11 | R11-1: **PARTLY**; R11-2–4: **FIXED** |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `bench/evals/evalsuite.py:71-75, 85-100, 390-402` | R10-1 remains exploitable: HumanEval tests are still in `/workspace/eval/data/humaneval.jsonl`, normally root-created `0644` under `0755` directories. The sandbox is not mount/filesystem-isolated, so model code can read that file by absolute path despite receiving its program on stdin. This contradicts `docs/EVAL.md:182-184`. | Make evaluation data root-only and non-traversable to UID 65533, or use a separate mount/container containing only the candidate program. |
| 2 | Medium | `bench/evals/evalsuite.py:139-142, 536-538, 631-632` | Resume validity is based only on item ID. Re-preparing after a prompt, dataset, evaluator, or token-cap change silently retains prior answers; the one-sided cap check accepts old lower-cap outputs. Run metadata also absorbs all historical `serve_history` entries rather than a bounded run. | Store and require a per-row run/config hash, model revision, and requested cap; reject stale rows. Start/end a dedicated run record before generation. |
| 3 | Medium | `scripts/pull_eval.sh:28-49` | Pull validation parses task rows, but headline/A-B judge files are only line-counted and canaries are only checked for existence. Duplicate IDs, malformed JSON, wrong judge IDs, invalid verdict fields, or failed canaries can replace local evidence alongside a plausible `summary.json`. | Parse every judge/canary artifact; require exact ID sets matching JBB answer rows, expected judge IDs, valid verdict schema, and passed headline canaries before swap. |
| 4 | Low | `bench/evals/evalsuite.py:227-229` | The “exact Yes/No, one trailing full stop” parser accepts any number of trailing periods (`Yes...`, `No....`) via `rstrip(".")`. The current 800 rows are exact and unaffected. | Use a case-insensitive full match for `Yes\.?` or `No\.?`. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | Scoring makes the eval directory, its data and results, and the Hugging Face cache root-only, and stops if the sandbox uid can list any of them | Re-scored; `/workspace/eval`, `data`, `/workspace/.cache/hf` now `drwx------` |
| 2 | New answer rows carry `prompt_sha256` and `max_tokens`; `run` treats only rows for the current prompt and cap as done; `score` rejects rows for another prompt or cap. `metadata --since` limits the vLLM history to the run (`compare_pod.sh` passes its start time) | Re-scored (this run's rows predate the fields, documented); metadata: 10 vLLM starts since 07:00 UTC |
| 3 | `pull_eval.sh` parses every verdict file (same ids as the answers, expected judge, `raw` exactly `Yes`/`No` and consistent with `refused`) and requires passed injection checks | Pull passes |
| 4 | Judge parser: case-insensitive full match of `Yes` or `No` with at most one full stop | Code review |
