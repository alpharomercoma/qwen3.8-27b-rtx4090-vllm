# Codex QA, held-out eval round 5: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Recomputed results reconcile. Accuracy counts match `summary.json` (gold labels are not committed); all other aggregates match raw JSONL. No harmful JBB answer fields, credential values, pod IDs, or personal home-directory paths found. Only loopback and generic `/workspace` paths appear.

| Finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | Fails closed without root + `setpriv`; drops UID/capabilities and sets `no_new_privs`. |
| R1-2 | FIXED | Uses the three ordered [upstream extraction patterns](https://github.com/TIGER-AI-Lab/MMLU-Pro/blob/main/evaluate_from_apiX.py#L38), plus explicit-only scoring. |
| R1-3 | FIXED | Manifest cap is 4096, retained by scoring, enforced; old timing-field omission is disclosed. |
| R1-4 | FIXED | Invalid judge output is excluded and redacted. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Evaluation uses fetch/serve directly. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | CUDA checks align. |
| R2-1 | FIXED | Sandbox requires root and `setpriv`. |
| R2-2 | FIXED | Private directories are created and chmodded `0700`. |
| R2-3 | PARTLY | Normal descendants are killed, but a child can fork and `setsid()` to escape the killed process group. |
| R2-4 | FIXED | Invalid replies retain only an error class or length. |
| R2-5 | FIXED | Historical timing limitation is accurately disclosed. |
| R2-6 | FIXED | Quantizer confounding is no longer called an upper bound. |
| R2-7 | FIXED | Judge spread is not presented as a true-rate bound. |
| R2-8 | FIXED | Length statement is scoped to capability benchmarks. |
| R3-1 | FIXED | Capability bounding and `no_new_privs` are present. |
| R3-2 | FIXED | Holm count/value use six comparisons and 0.17. |
| R3-3 | FIXED | Reproduction command propagates installer failure. |
| R3-4 | FIXED | Harmful-answer references are paraphrased. |
| R3-5 | FIXED | “No request” claim is scoped to harmful requests. |
| R4-1 | FIXED | `N/A` filtering is present; setup is clearly not leaderboard-comparable. |
| R4-2 | FIXED | Both distributions are restricted and renormalized; labelled proxy. |
| R4-3 | PARTLY | Missing rows within an existing file fail, but a wholly missing IFEval or judge file is silently omitted. |
| R4-4 | FIXED | Pull is pipefail-protected, staged, checked, and swapped. |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `docs/EVAL.md:11` | “At most about a point lower” and “no difference statistically solid” overstate what nonsignificance establishes. Point estimates differ by at most 1.4 points, but reported CIs permit losses up to 3.1–3.5 points; this is not an equivalence/non-inferiority test. | Say these are observed point estimates; state that the intervals permit larger differences. |
| 2 | Medium | `evalsuite.py:270` | `killpg(proc.pid)` does not contain a descendant that forks and calls `setsid()`. It can outlive the 20-second wall timeout and retain network access, contradicting “everything it starts.” | Run code in a disposable VM/container/cgroup and terminate that boundary; otherwise narrow the guarantee. |
| 3 | Medium | `evalsuite.py:392` | Completeness checking only visits metrics added to `per_item`. A missing IFEval output file or wholly missing judge file adds no metric, produces no gap, and allows `score` to succeed with omitted results. | Define the required task/metric/judge matrix before scoring; require each file and all expected IDs. |
| 4 | Medium | `compare_pod.sh:14` | `serve` accepts any already-running endpoint with the requested model ID, without verifying it is vLLM with the prescribed production flags. A rerun can therefore reuse different serving settings and invalidate speed/reproducibility claims. | Always restart through `serve.sh` after conditionally downloading, or verify the server process and exact flags. |

NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| R4-3 / 3 | `score` checks a fixed matrix: every task metric and every judge's verdicts for both models, all items, and first-token logprobs for all 200 harmless prompts | Scoring with a judge that has no results exits 1 and names the gap; the full scoring passes |
| 1 | Verdict reworded: observed point estimates, with the intervals' worst case (−3.1 MMLU-Pro, −3.5 IFEval loose); not an equivalence claim | EVAL.md |
| 2 | Code runs under its own unused uid (65533); after each program every process of that uid is killed (`pkill -9 -u`), whatever its session; `score` refuses to start if the uid is in use | Re-scored: HumanEval unchanged; no uid-65533 processes afterwards |
| 4 | `compare_pod.sh` always restarts vLLM through `serve.sh`, so a rerun cannot reuse a server with other settings | `bash -n` |
