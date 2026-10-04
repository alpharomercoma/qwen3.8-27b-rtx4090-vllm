# Pod logs of the held-out benchmark run (2026-10-04)

Copied from the pod before it was deleted. The numbers are in [`../eval/`](../eval/README.md) and
[docs/EVAL.md](../../docs/EVAL.md); these logs show how the run went.

| File | What |
|---|---|
| `eval_heretic.log` | The Heretic suite run (07:26–08:35 UTC) |
| `eval_compare.log` | `compare_pod.sh`: the original's suite, the first judge passes, scoring (08:35–09:55) |
| `eval_rejudge.log`, `eval_rejudge3.log`, `eval_rejudge4.log` | Judge-only re-runs: prompt B (with its failed injection check), JailbreakBench's prompt, and the strict parser |
| `serve_history.log` | Every vLLM start of the day with its exact command (key redacted, or not on the command line at all) |
| `serve_heretic.log`, `serve_original.log` | vLLM's own logs, **last start only**: `serve.sh` truncates them at each start, so they hold the final judging restarts, not the benchmark load. Speed numbers come from the client side instead (`../eval/<model>/*.jsonl` latency and tokens per request, `timing.jsonl` per task) |
| `start.log`, `start_console.log` | `start.sh` runs; each ends at the public-URL check, which failed because the edge did not trust this pod's tunnel key (expected: the eval talks to vLLM directly) |
| `fetch_original.log` | Download and SHA-256 check of the original model |
| `bootstrap.log`, `bootstrap_apt.log` | Pod setup |
| `run_metadata_before_rescore.json` | `run_metadata.json` as the run wrote it, before the answers were scored again on a second pod (its content is also kept inside today's `run_metadata.json`) |

Left out: the gateway and tunnel logs (not part of the evaluation), and the answers to JailbreakBench's harmful
requests, which by design never left the pod and were deleted with it.
