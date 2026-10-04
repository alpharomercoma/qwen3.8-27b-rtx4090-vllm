# Codex QA, held-out eval round 8: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Read-only review complete; no files were edited. JSONL recomputation matches `summary.json`, `summary.md`, docs, and README; harmful JBB files contain no response text. Accuracy can only be checked against `summary.json` because gold labels are intentionally absent.

| Round | Status |
|---|---|
| R1 | R1-1–R1-8: **FIXED** |
| R2 | R2-1–R2-8: **FIXED** |
| R3 | R3-1–R3-5: **FIXED** |
| R4 | R4-1–R4-4: **FIXED** |
| R5 | R5-1–R5-4: **FIXED** |
| R6 | R6-1: **FIXED**. R6-2: **PARTLY** — canaries, tag neutralization, and disclosure are present, but the judge remains injection-sensitive by design. |
| R7 | R7-1–R7-2: **FIXED**. R7-3: **PARTLY** — accurately disclosed and checked, but not a security boundary. |

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | Medium | `scripts/pull_eval.sh:17` | The harmful-response validation is non-recursive. It checks only `<stage>/<model>/jbb_harmful.jsonl`, while the script also copies `judge_prompts/A|B/<model>/jbb_harmful_*.jsonl`. A future leaked response in those nested artifacts would reach the public repo unchecked. Current nested files are clean. | Use `rglob("jbb_harmful*.jsonl")` and reject any harmful JSONL record containing `response`. |
| 2 | Medium | `pod/bootstrap.sh:10,31-34` | The documented fresh-pod reproduction eventually requires `setpriv` and `pkill` for HumanEval scoring, but bootstrap neither installs nor verifies them. A base image without `procps`/`pkill` fails late at scoring. | Install `procps` and `util-linux` explicitly, then verify `setpriv` and `pkill` with the other required commands. |
| 3 | Low | `bench/evals/evalsuite.py:129` | `top_logprobs` is keyed by decoded token text, so duplicate strings overwrite one another. Two of 200 rows per model retain fewer than 20 entries (as few as 14), despite the reported “top-20” proxy. | Preserve token bytes/IDs or aggregate duplicate decoded strings with log-sum-exp; otherwise document it as up-to-20 unique token strings. |

NEEDS FIXES


## Resolution

| # | Change | Test |
|---|---|---|
| R6-2, R7-3 | Accepted and documented (EVAL.md Limits): the judge reads untrusted text; tag neutralising and two fail-closed injection checks are evidence, not a boundary | — |
| 1 | `pull_eval.sh` checks every `jbb_harmful*.jsonl` at any depth, including `judge_prompts/` | Pull passes |
| 2 | `bootstrap.sh` installs `procps` and `util-linux` and checks `setpriv` and `pkill` | `bash -n` |
| 3 | Documented: tokens keyed by decoded text; 2 of 200 prompts per model keep fewer than 20 (min 14 / 15) | Counted from `harmless.jsonl` |
