# Codex QA, held-out eval round 23: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Read-only audit complete; no files changed.

| R1 finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | Fail-closed unprivileged HumanEval sandbox, limits, cleanup, and network limitation documented. |
| R1-2 | FIXED | All three official MMLU-Pro extraction patterns present. |
| R1-3 | FIXED | 4,096 cap is recorded and enforced; legacy rows disclosed. |
| R1-4 | FIXED | Strict canonical verdict schema; invalid rows block scoring. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Reproduction uses `fetch_model.sh` and `serve.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | Bootstrap/start prerequisites align. |

| Later findings | Status |
|---|---|
| R2–R5 | FIXED |
| R6-1 | FIXED |
| R6-2 | FIXED as accepted, accurately documented limitation |
| R7-1–R7-2 | FIXED |
| R7-3 | FIXED as accepted, accurately documented limitation |
| R8–R13 | FIXED |
| R14-1, R14-3 | FIXED |
| R14-2 | NOT FIXED — metadata evaluator hash is stale |
| R14-4 | NOT APPLICABLE |
| R15–R16 | FIXED |
| R17–R21 | Individual gates/wording fixed; the “final code” rescore attestation is undermined by R14-2 |
| R22-1 | FIXED — byte check confirms no backslashes in the reproduce command |
| R22-2 | FIXED — scorer validates `raw` against `refused` |

I recomputed all raw-derived totals: 3,824 prompts/model, token totals, timings, caps, refusal rates, A/B rates, canaries, and KL all match `summary.json`, `summary.md`, `docs/EVAL.md`, and the README sentence. The 44 public raw-artifact hashes match `summary.json`; both summary hashes match metadata. Gold-dependent accuracy cannot be independently recomputed because data items are intentionally absent. No harmful-answer `response`/`error` fields appeared in the 14 harmful-JBB artifacts; no credentials, public IPs, or `home-directory ` paths were found in the QA records. The current `VLLM_API_KEY` launch approach is supported by [vLLM’s documentation](https://github.com/vllm-project/vllm/blob/main/docs/getting_started/quickstart.md).

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | medium | `docs/EVAL.md`, `run_metadata.json`, `pull_eval.sh` | Metadata records evaluator SHA-256 `34f05d…`, while committed `bench/evals/evalsuite.py` hashes to `2766acc…`. `pull_eval.sh` therefore rejects this committed bundle as produced by another evaluator. This also makes the claim that the second-pod rescore used the committed “final code” unsupported. | Freeze the evaluator, re-run `score`, `report`, and `metadata` with that exact source (preserving the original attestation), then re-pull the bundle; otherwise narrow the documentation and remove the failing source-hash gate. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | A push to the pod had failed partway (transient `tar` errors), so the re-score could not run and the local bundle still had the previous scorer's hash. `pull_eval.sh` refused the stale bundle as designed. Pushed again, re-scored, reported and wrote the metadata with the committed code; code frozen from here | Pod, metadata and checkout all `2766acc1…`; pull passes |
