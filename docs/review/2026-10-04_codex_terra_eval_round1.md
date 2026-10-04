# Codex QA, held-out eval round 1: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Recomputed raw aggregates match the reported tables (including 3,824 prompts, 2,634,181 vs 2,475,943 output tokens, and 4,213.3 vs 3,999.1 s). No harmful-response text, credentials, RFC1918 pod addresses/hostnames, or personal home-directory paths were found in the changed/new files.

| # | Severity | File:line | Finding | Suggested fix |
|---|---|---|---|---|
| 1 | high | `bench/evals/evalsuite.py:262` | HumanEval executes model-generated Python directly as the pod user. `cwd` is not a sandbox; code can read `/workspace/.api_key` (and inherits `VLLM_KEY` in `compare_pod.sh`) or access the network. | Run evaluations in an isolated unprivileged container/VM with no workspace mount, credentials, or network; enforce CPU/memory/PID/time limits. |
| 2 | medium | `bench/evals/evalsuite.py:242-248`, `docs/EVAL.md:181` | The claimed “official” MMLU-Pro extraction is not the current official API evaluator: it omits its third `\b[A-J]\b` fallback. On these raw answers, that fallback finds an additional 92 original and 87 Heretic predictions, so the reported MMLU-Pro score is not directly comparable to that evaluator. | Pin and use one stated official evaluator revision, including all extraction patterns, or label this as a custom two-pattern scorer. [Official evaluator](https://github.com/TIGER-AI-Lab/MMLU-Pro/blob/main/evaluate_from_apiX.py) |
| 3 | medium | `results/eval/manifest.json:18`, `bench/evals/evalsuite.py:327-328` | The committed manifest says MMLU-Pro used a 2,048-token cap, while EVAL, `summary.json`, the current harness, and raw rows show 4,096. `score` silently overwrites the copied manifest, masking the provenance conflict. | Correct/regenerate the manifest and record generation settings with each run; do not overwrite recorded settings during scoring. |
| 4 | medium | `bench/evals/evalsuite.py:209-211` | Any malformed or failed judge reply is silently counted as `COMPLIED`; any string beginning `REFUS` is accepted as a refusal. This can bias refusal rates without an error count. The committed judge rows happen to be valid. | Require exactly `REFUSED`/`COMPLIED`, retry or mark invalid results, and fail scoring when the judge denominator is incomplete. |
| 5 | medium | `docs/EVAL.md:220`, `bench/evals/evalsuite.py:139` | “`run` resumes where it stopped” is false after a terminal request error: an error row’s ID is added to `done`, so it is never retried and scoring silently drops it from accuracy denominators. | Exclude error rows from `done`, or add an explicit `--rerun-errors` mode and require complete IDs before reporting. |
| 6 | medium | `docs/EVAL.md:210`, `docs/EVAL.md:212`, `pod/start.sh:45-53` | The reproduction commands are not standalone: `start.sh` brings up the gateway/tunnel and fails unless the external edge returns 401. A fresh evaluation pod can have vLLM working yet the documented command returns failure. | Add a local/eval-only start mode that skips gateway/tunnel/public checks, or document the deployed-edge prerequisite. |
| 7 | low | `bench/evals/evalsuite.py:422` | For 200 KL values, the reported “median” is the upper middle order statistic, not the conventional median. Raw data gives 0.032607; the report’s 0.034006 is element 101. | Use `statistics.median` or average elements 100 and 101; regenerate the KL sentence. |
| 8 | low | `pod/start.sh:21`, `pod/bootstrap.sh:13-15` | Bootstrap now checks CUDA headers, but `start.sh` only checks for `nvcc` before deciding bootstrap may be skipped. A reused workspace with `nvcc` but missing headers bypasses the new install path and can still fail FlashInfer/vLLM setup. | Make `start.sh` test the same header prerequisites as `bootstrap.sh`. |

Verdict: NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| 1 | HumanEval code runs as `nobody` (`setpriv`), `python -I`, empty environment, rlimits; no network namespace available in the container (disclosed in EVAL.md Limits) | `nobody` denied reading the API key, team keys, tunnel key, private answers; re-scored: 154/164 for both, same 2/2 split |
| 2 | MMLU-Pro uses the official evaluator's three patterns (headline) plus the explicit-only variant | Both rows in EVAL.md; they agree on every uncut answer |
| 3 | Manifest MMLU-Pro cap corrected to 4,096 with a note; `score` no longer rewrites it and fails if an answer exceeds the cap; `run` writes `max_tokens` to timing rows | `score` passes; longest MMLU-Pro answer 4,096 tokens |
| 4 | Judge verdicts must be exactly `REFUSED` / `COMPLIED`; others stored as invalid, excluded and counted | 0 invalid in this run |
| 5 | `run` retries error rows | Code review |
| 6 | `compare_pod.sh` runs the whole comparison with `fetch_model.sh` + `serve.sh`, no gateway; Reproduce rewritten | `bash -n` |
| 7 | `statistics.median` | KL median 0.0326 |
| 8 | `start.sh` checks the same CUDA headers as `bootstrap.sh` | `bash -n` |
