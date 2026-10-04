# Codex QA, held-out eval round 3: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Read-only audit complete. JSONL-derived counts, timings, refusal rates, and KL match `summary.json`/`summary.md`; no credentials, public IPs, pod IDs, or personal home-directory paths found. Harmful JSONL records omit response fields.

| Finding | Status | Note |
|---|---|---|
| R1-1 | PARTLY | UID drop, isolated Python, empty env, limits, and process-group timeout are present, but privilege gain is not prevented. |
| R1-2 | FIXED | Three official-style MMLU-Pro extraction patterns are used; strict variant excludes fallback. |
| R1-3 | FIXED | Manifest cap is 4096; scorer rejects over-cap answers; new timing writes include `max_tokens`. |
| R1-4 | FIXED | Only valid judge labels count; invalid output is redacted and excluded. |
| R1-5 | FIXED | Error rows are not considered complete and are retried. |
| R1-6 | FIXED | `compare_pod.sh` uses fetch/serve directly; reproduction no longer needs gateway startup. |
| R1-7 | FIXED | Uses `statistics.median`. |
| R1-8 | FIXED | Bootstrap/start CUDA checks align. |
| R2-1 | FIXED | HumanEval scoring exits unless root and `setpriv` are available. |
| R2-2 | FIXED | Private directories are chmod 0700. |
| R2-3 | FIXED | Tests run in a new session and teardown kills the process group. |
| R2-4 | FIXED | Invalid judge output stores only `ERROR` or length metadata. |
| R2-5 | FIXED | Historical timing-row limitation is disclosed; caps are retained in manifest. |
| R2-6 | FIXED | Quantizer limitation is no longer called an upper bound. |
| R2-7 | FIXED | Judge spread is no longer called a bound. |
| R2-8 | FIXED | Length claim is scoped to capability benchmarks. |

| # | Severity | File:line | Finding | Suggested fix |
|---|---|---|---|---|
| 1 | High | `bench/evals/evalsuite.py:278` | `setpriv` drops UID/GID but does not set `no_new_privs` or clear capability sets/bounding set. Model code can still attempt setuid/file-capability escalation, so the documentation’s guarantee that it cannot read root-owned keys is not robust. | Add `--no-new-privs --bounding-set=-all --inh-caps=-all --ambient-caps=-all`; fail closed if unsupported, then re-score HumanEval. |
| 2 | Medium | `docs/EVAL.md:13` | The stated Holm correction uses five tests (`0.15`), but the capability table reports six paired p-values. Correcting all six makes the smallest adjusted p ≈ `0.174`, not `0.15`. | Declare a pre-specified primary family or correct the count/value; align README wording. |
| 3 | Medium | `docs/EVAL.md:232` | The `install_vllm.sh \| tail -1` pipeline masks installer failure because the remote shell does not enable `pipefail`. | Log installer output, then `tail` the log only after successful installation, or enable `set -o pipefail`. |
| 4 | Medium | `docs/EVAL.md:91,96` | The document includes quoted opening fragments from harmful-prompt model replies, despite the stated requirement that no JailbreakBench harmful answer text enter the commit. | Replace quoted fragments with non-verbatim paraphrase. |
| 5 | Low | `docs/EVAL.md:89` | “No request” is unqualified but false across both JBB sets: benign refusal-marker results contain two Heretic-only cases. | Scope it to harmful requests, where all three measures do show zero Heretic-only refusals. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | `setpriv --no-new-privs --bounding-set=-all --inh-caps=-all --ambient-caps=-all` | On the pod: uid 65534, NoNewPrivs 1, CapPrm/CapEff/CapBnd all 0; re-scored, HumanEval unchanged |
| 2 | Holm over the six capability comparisons: 0.17 | EVAL.md Verdict |
| 3 | Installer output to a log, `&& echo INSTALLED` | EVAL.md Reproduce |
| 4 | Quoted reply openings replaced with paraphrase | `grep` finds no quoted reply text |
| 5 | Scoped to harmful requests; the 2 benign marker-only cases are explained | Both judges call those 2 answers compliance |
