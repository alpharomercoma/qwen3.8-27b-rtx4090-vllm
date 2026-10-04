# Codex QA, held-out eval round 4: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

| Prior finding | Status | Note |
|---|---|---|
| R1-1 | FIXED | Fails closed without root + `setpriv`; drops privileges/capabilities, sets `no_new_privs`, isolates Python/env, limits resources, and kills the process group. Network limit is disclosed. |
| R1-2 | FIXED | Three-tier extraction and explicit-only variant are present. |
| R1-3 | FIXED | Manifest cap is 4,096; scorer enforces it and no longer rewrites the manifest. Historical timing limitation is disclosed. |
| R1-4 | FIXED | Only exact judge labels count; invalid results are redacted, excluded, and counted. |
| R1-5 | FIXED | Error rows are retried on rerun. |
| R1-6 | FIXED | Evaluation uses fetch/serve directly, without gateway startup. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | CUDA prerequisite checks align. |
| R2-1 | FIXED | Sandbox requires root and `setpriv`. |
| R2-2 | FIXED | Private directories are created and chmodded `0700`. |
| R2-3 | FIXED | Timeout teardown kills and reaps the child session’s process group. |
| R2-4 | FIXED | Invalid replies retain only an error class or length metadata. |
| R2-5 | FIXED | Missing historical timing caps are accurately disclosed; manifest retains caps. |
| R2-6 | FIXED | Quantizer confounding is no longer called an upper bound. |
| R2-7 | FIXED | Judge variation is no longer called a bound. |
| R2-8 | FIXED | Length claim is scoped to capability benchmarks. |
| R3-1 | FIXED | `no_new_privs` and capability-set drops are present. |
| R3-2 | FIXED | Holm correction uses six comparisons and 0.17. |
| R3-3 | FIXED | Reproduction installer command no longer masks failure. |
| R3-4 | FIXED | Harmful-reply references are paraphrased. |
| R3-5 | FIXED | Claim is scoped to harmful requests. |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `bench/evals/evalsuite.py:57` | MMLU-Pro prompt construction retains padded `N/A` options, while the upstream evaluator removes them before lettering choices. The result is a custom prompt setup, not directly comparable to upstream MMLU-Pro runs. [Upstream evaluator](https://github.com/TIGER-AI-Lab/MMLU-Pro/blob/main/evaluate_from_apiX.py) | Filter `N/A` options before formatting, then rerun MMLU-Pro; otherwise disclose this prompt deviation and avoid official-comparability wording. |
| 2 | Medium | `bench/evals/evalsuite.py:354` | The published “KL” is not a KL divergence between two normalized distributions: `p` is normalized over its top-20 tokens, but `q` is not normalized over the corresponding support. Recomputing a consistently conditioned variant changes the mean from 0.09744 to 0.09071. | Either report top-1 agreement only, or explicitly normalize both distributions over a defined shared support and label it as a conditional top-k proxy. |
| 3 | Medium | `bench/evals/evalsuite.py:378` | Permanent generation failures and invalid judge rows still permit `score` to emit partial per-model rates and paired results over only the surviving intersection. The documented reproduction invokes each run once, so retry support does not ensure complete denominators. | Fail scoring on missing/error/invalid IDs by default; require an explicit partial-results override that prominently records excluded IDs. |
| 4 | Medium | `scripts/pull_eval.sh:6` | Result pulling has neither `pipefail` nor staging/validation. A remote archive failure can leave a stale or partial `results/eval/` tree while the final `ls` succeeds. | Use `set -euo pipefail`, extract to a fresh staging directory, validate manifest and expected files, then replace the destination atomically. |

Raw JSONL aggregates reconcile with `summary.json`/`summary.md`: 3,824 prompts each; 2,634,181 vs 2,475,943 output tokens; 4,213.3 vs 3,999.1 seconds. No harmful-answer response fields, credentials, routable pod IPs/IDs, or personal home-directory paths were found.

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | Not applicable to this run: at the pinned commit none of the 12,032 MMLU-Pro test questions has an `N/A` option (checked on the full split and on the 1,400 prompts). The upstream filter was added anyway; EVAL.md Limits now says the setup is zero-shot and not comparable to leaderboard numbers | Count on the pod: 0 of 12,032 |
| 2 | KL proxy: both distributions restricted to the original's top-20 tokens and renormalised; labelled a proxy | Mean 0.0907, median 0.0300 (was 0.0974 / 0.0326); EVAL.md updated |
| 3 | `score` fails if any item is unanswered, errored or has an invalid verdict, unless `--allow-partial` (which lists the gaps in `summary.json`) | Full scoring passes with no gaps |
| 4 | `pull_eval.sh`: `set -euo pipefail`, unpack to a staging directory, check the manifest, summaries and that no `jbb_harmful.jsonl` holds answer text, then swap; the local README is kept | Pulled twice; README preserved |
