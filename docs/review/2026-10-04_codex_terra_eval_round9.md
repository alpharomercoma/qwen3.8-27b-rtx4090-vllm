# Codex QA, held-out eval round 9: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Recomputed artifacts reconcile: 3,824 rows/model, token totals, timing, refusal counts, judge A/B/headline results, canaries, and KL all match. Accuracy can only be checked against `summary.json` because gold labels are intentionally absent. No harmful JBB response fields, credentials, routable IPs, pod IDs, or personal home-directory paths found. R1-2’s patterns match the upstream evaluator’s three ordered patterns ([source](https://raw.githubusercontent.com/TIGER-AI-Lab/MMLU-Pro/main/evaluate_from_apiX.py)).

| Finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | UID sandbox, capability drop, isolated Python/env, limits, and documented network limitation present. |
| R1-2 | FIXED | Three ordered official extraction patterns plus explicit-only metric. |
| R1-3 | FIXED | Manifest cap is 4096, enforced without overwrite; timing limitation disclosed. |
| R1-4 | FIXED | Invalid judge replies are redacted, excluded, counted, and completeness-gated. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Evaluation uses `fetch_model.sh` and `serve.sh`, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | CUDA checks align. |
| R2-1 | FIXED | Score fails closed without root, `setpriv`, and `pkill`. |
| R2-2 | FIXED | Private directories are created with mode 0700. |
| R2-3 | FIXED | UID-wide repeated cleanup handles detached descendants. |
| R2-4 | FIXED | Invalid rows retain only safe error/length metadata. |
| R2-5 | FIXED | Historical timing-row omission accurately disclosed. |
| R2-6 | FIXED | Quantizer confound is not called a bound. |
| R2-7 | FIXED | Judge range is not called a true-rate bound. |
| R2-8 | FIXED | Length claim is properly scoped. |
| R3-1 | FIXED | `no_new_privs` and all capability-set drops present. |
| R3-2 | FIXED | Six-comparison Holm correction is correctly stated. |
| R3-3 | FIXED | Installer failure propagates. |
| R3-4 | FIXED | No harmful-answer quotation found. |
| R3-5 | FIXED | Claim is scoped to harmful requests. |
| R4-1 | FIXED | `N/A` filtering present; zero-shot limitation disclosed. |
| R4-2 | FIXED | Both distributions use the same renormalized support; labeled proxy. |
| R4-3 | FIXED | Required metric/judge matrix catches absent files and IDs. |
| R4-4 | FIXED | Pull is pipefail-protected, staged, validated, then swapped. |
| R5-1 | FIXED | Verdict distinguishes observed estimates from equivalence. |
| R5-2 | FIXED | Repeated UID-wide cleanup replaces process-group-only cleanup. |
| R5-3 | FIXED | Completeness requirement is enforced. |
| R5-4 | FIXED | `compare_pod.sh` always restarts via `serve.sh`. |
| R6-1 | FIXED | Cleanup repeats until no live sandbox-UID process remains. |
| R6-2 | PARTLY | Accepted, accurately documented injection-sensitive judge limitation; canaries fail closed. |
| R7-1 | FIXED | vLLM key is not passed in argv; scorer checks key files and process command lines. |
| R7-2 | FIXED | Failed canaries stop judging; score requires passing records. |
| R7-3 | PARTLY | Accepted, accurately documented untrusted-text limitation. |
| R8-1 | FIXED | Harmful JSONL validation is recursive. |
| R8-2 | FIXED | Bootstrap installs and verifies `procps`/`util-linux`. |
| R8-3 | FIXED | Text-keyed top-logprob behavior and counts are disclosed. |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `scripts/pull_eval.sh:8` | `mktemp -d` initially protects the staging tree, but the script changes it to mode 755 before extracting and validating the remote archive. A future harmful-response regression would be readable by other local users during that window, even though validation later prevents committing it. | Keep staging mode 0700 through validation; only change mode after the harmful-content check succeeds, immediately before the swap. |
| 2 | Medium | `docs/EVAL.md:3` | The report makes specific fresh-pod, hardware, vLLM-version, server-setting, and checkpoint claims, but `manifest.json`/`summary.json` record only dataset metadata and computed results. The archived data cannot independently bind these results to the claimed execution configuration. | Emit a run metadata file with evaluator/repo revision, model-manifest hashes, exact server command/config, vLLM/torch versions, GPU details, and timestamps. |
| 3 | Low | `docs/EVAL.md:22` | “Same model otherwise” generalizes from a 200-prompt first-token probe and the listed benchmarks. Those measurements support similarity on those probes, not behavior “otherwise.” | Say “Similar on this first-token probe and the capability benchmarks” instead. |

NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| 1 | `pull_eval.sh` keeps the staging directory at mode 700 until the checks pass, then opens it to 755 just before the swap | Pull passes |
| 2 | New `evalsuite.py metadata` (run by `compare_pod.sh`): `results/eval/run_metadata.json` with GPU, driver, vLLM/torch and scoring versions, both checkpoints at their commits, model-manifest and `evalsuite.py` hashes, and every vLLM start of the run with its exact command and time | Generated on the pod: 8 vLLM starts, no key in the file |
| 3 | "Same model otherwise" → "Similar on ordinary requests, as far as measured" | EVAL.md |
