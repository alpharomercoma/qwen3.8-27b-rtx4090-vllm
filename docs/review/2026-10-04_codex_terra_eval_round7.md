# Codex QA, held-out eval round 7: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Recomputed artifacts reconcile: 3,824 rows/model; 2,634,181 vs 2,475,943 output tokens; refusal counts, A/B/headline judge files, canaries, KL, timings, `summary.json`, `summary.md`, EVAL tables, and README headline all match. Accuracy can only be checked against `summary.json` because gold labels are absent. No harmful-answer fields, credential values, pod IDs, routable IPs, or personal home-directory paths found; only intentional loopback and generic `/workspace` paths. Shell/Python syntax and all JSON passed static checks; reproduction was not run on a pod.

| Finding | Status | Note |
|---|---|---|
| R1-1 | PARTLY | UID/capability isolation is good, but a root server key remains exposed through process arguments; see new high finding. |
| R1-2 | FIXED | Three ordered patterns match the [upstream evaluator](https://raw.githubusercontent.com/TIGER-AI-Lab/MMLU-Pro/main/evaluate_from_apiX.py). |
| R1-3 | FIXED | Manifest says 4096, over-cap answers fail scoring, and historical timing omission is disclosed. |
| R1-4 | FIXED | Invalid labels are redacted, excluded, counted, and completeness-gated. |
| R1-5 | FIXED | Error rows are retried. |
| R1-6 | FIXED | Evaluation uses `fetch_model.sh` and `serve.sh`, not `start.sh`. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | CUDA prerequisite checks align. |
| R2-1 | FIXED | Scoring fails closed without root, `setpriv`, and `pkill`. |
| R2-2 | FIXED | Private directories are created and chmodded 0700. |
| R2-3 | FIXED | UID-wide repeated cleanup covers descendants that escape sessions. |
| R2-4 | FIXED | Invalid verdicts retain only safe metadata. |
| R2-5 | FIXED | Historical timing limitation is accurately disclosed. |
| R2-6 | FIXED | Quantizer confounding is not called a bound. |
| R2-7 | FIXED | Judge spread is not called a true-rate bound. |
| R2-8 | FIXED | Length claim is appropriately scoped. |
| R3-1 | FIXED | `no_new_privs` and capability drops are present. |
| R3-2 | FIXED | Six-comparison Holm correction is correctly stated. |
| R3-3 | FIXED | Installer failure propagates. |
| R3-4 | FIXED | No harmful-answer quotations found. |
| R3-5 | FIXED | Claim is scoped to harmful requests. |
| R4-1 | FIXED | `N/A` options are filtered; non-leaderboard setup is disclosed. |
| R4-2 | FIXED | Both distributions use the same renormalized support; called a proxy. |
| R4-3 | FIXED | Required metric/judge matrix rejects missing files and IDs. |
| R4-4 | FIXED | Pull is pipefail-protected, staged, validated, then swapped. |
| R5-1 | FIXED | Verdict distinguishes observed estimates from equivalence. |
| R5-2 | FIXED | UID-wide repeated scan/kill supersedes process-group-only cleanup. |
| R5-3 | FIXED | Completeness matrix is enforced. |
| R5-4 | FIXED | `compare_pod.sh` always restarts through `serve.sh`. |
| R6-1 | FIXED | Cleanup repeats until `/proc` has no live sandbox-UID process, else aborts. |
| R6-2 | PARTLY | Tag neutralization and recorded canaries are present, but untrusted text remains in the judge instruction message and failed canaries do not block scoring. |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | High | `pod/serve.sh:23` | The root vLLM process is launched with the literal API key in `--api-key`; the tmux command line also retains it. HumanEval has no PID/proc isolation or `hidepid` assertion. On standard `hidepid=0` procfs, UID 65533 can read root process `cmdline`, recover the key, then use the documented unrestricted network. This invalidates the claim that model code cannot reach pod keys. [Kernel procfs docs](https://www.kernel.org/doc/html/latest/filesystems/proc.html) | Keep secrets out of argv; isolate evaluation in a separate PID/mount/network boundary, or fail closed after proving sandbox UID cannot read a root-process sentinel from `/proc`. |
| 2 | Medium | `evalsuite.py:265` | A failed injection canary only prints `FAILED`; `cmd_judge` still writes verdicts and `score` accepts their complete denominators. A future failed judge run can therefore publish headline rates. | Return nonzero before judging on a canary failure; stage verdicts and require an explicit passed-canary record in `score`. |
| 3 | Medium | `evalsuite.py:207` | Request and reply remain untrusted instructions embedded in the same user message that asks for the verdict. Removing XML-like tags handles only one injection shape; two passing canaries are useful evidence, not an untrusted-data boundary. | Treat the headline judge as injection-sensitive, expand adversarial regression coverage, and use an independent validated judge for publication-grade refusal claims. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | `pod/serve.sh` gives vLLM its key through `VLLM_API_KEY`, read inside the tmux session, instead of `--api-key` (production and eval). `score` refuses to run HumanEval if the sandbox uid can read a key file or any process's command line holds a key. SECURITY.md says how to clear an old tmux server | Before: the key was in vLLM's and tmux's command lines. After `tmux kill-server` + `serve.sh heretic`: no command line holds a key; vLLM still answers 401 without the key; scoring passes the new check |
| 2 | A failed injection check stops `judge` before any verdict is written; `score` counts a judge's verdicts only with a passed `judge_canaries_<judge>.json` | Both judges' checks passed; scoring passes |
| 3 | EVAL.md Limits: the judge reads untrusted text; two checks are evidence, not a boundary; none of the 400 answers addresses a judge (regex check on all answers: one hit, the word "refused" inside a story) | — |
