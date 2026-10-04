# Codex QA, held-out eval round 16: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Read-only audit complete. Frozen non-gold artifacts reconcile; capability accuracy matches `summary.json` but cannot be independently recomputed without gold data. No harmful-response fields, credential-shaped values, routable IPs, or personal home-directory paths were found.

| Round | Statuses |
|---|---|
| 1 | R1-1 **FIXED**; R1-2 **FIXED** — three ordered extraction patterns match [upstream](https://raw.githubusercontent.com/TIGER-AI-Lab/MMLU-Pro/main/evaluate_from_apiX.py); R1-3 **FIXED**; R1-4 **FIXED**; R1-5 **FIXED**; R1-6 **FIXED**; R1-7 **FIXED**; R1-8 **FIXED**. |
| 2 | R2-1 **FIXED**; R2-2 **FIXED**; R2-3 **FIXED**; R2-4 **FIXED**; R2-5 **FIXED**; R2-6 **FIXED**; R2-7 **FIXED**; R2-8 **FIXED**. |
| 3 | R3-1 **FIXED**; R3-2 **FIXED**; R3-3 **FIXED**; R3-4 **FIXED**; R3-5 **FIXED**. |
| 4 | R4-1 **FIXED**; R4-2 **FIXED**; R4-3 **FIXED**; R4-4 **FIXED**. QA records contain no harmful answer text, credentials, personal paths, IDs, or routable IPs. |
| 5 | R5-1 **FIXED**; R5-2 **FIXED**; R5-3 **FIXED**; R5-4 **FIXED**. |
| 6 | R6-1 **FIXED**; R6-2 **FIXED / accepted limit** — the template matches [JailbreakBench’s refusal judge](https://raw.githubusercontent.com/JailbreakBench/jailbreakbench/main/src/jailbreakbench/classifier.py), canaries pass, and the documented injection limitation remains appropriately scoped. |
| 7 | R7-1 **FIXED**; R7-2 **FIXED**; R7-3 **FIXED / accepted limit**. |
| 8 | R8-1 **FIXED**; R8-2 **FIXED**; R8-3 **FIXED**. |
| 9 | R9-1 **FIXED**; R9-2 **FIXED**; R9-3 **FIXED**. |
| 10 | R10-1 **FIXED**; R10-2 **PARTLY** — parsing is broader, but the pull-side matrix still trusts the remote manifest’s task set and item counts. |
| 11 | R11-1 **FIXED**; R11-2 **PARTLY** — models/judges and A/B are fixed, but task presence/counts remain remote-controlled; R11-3 **FIXED**; R11-4 **FIXED**. |
| 12 | R12-1 **FIXED**; R12-2 **PARTLY** — answer-row binding is fixed, but resumed-run provenance relies on manually retaining `EVAL_SINCE`; R12-3 **FIXED**; R12-4 **FIXED**. |
| 13 | R13-1 **FIXED**; R13-2 **FIXED**; R13-3 **FIXED**; R13-4 **FIXED**. |
| 14 | R14-1 **FIXED**; R14-2 **FIXED**; R14-3 **FIXED**; R14-4 **NOT APPLICABLE** — only intentionally retained generic `/workspace` paths appear. |
| 15 | R15-1 **FIXED**; R15-2 **PARTLY** — normal foreign/duplicate verdicts fail, but a foreign invalid verdict row can still bypass `score`. |

| # | Severity | File:line | Finding | Suggested fix |
|---|---|---|---|---|
| 1 | Medium | `evalsuite.py:581`, `631` | `score` accepts a unique foreign verdict row when it lacks `refused` (for example an `invalid` row). It is excluded from metric maps, so no extra-ID gap is produced. This leaves R15-2 incomplete. | Before calculating any metric, require each judge file’s IDs to exactly equal the expected JBB IDs and validate `judge`, `raw`, `refused`, and invalid-row schema. |
| 2 | Medium | `pull_eval.sh:21`, `48` | The “full matrix” is defined by the remote `manifest.json`. A remote bundle can reduce task counts or omit non-JBB tasks while keeping its summary and hashes internally consistent. | Pin an expected task/count manifest locally and require exact equality before accepting the archive. |
| 3 | Medium | `pull_eval.sh:16`, `84` | The pull copies every remote result file and rejects only a harmful JSONL field literally named `response`. A leaked answer under another field name, or in an unexpected file, reaches the repository. | Pull only an explicit allowlist of expected artifacts and enforce strict per-file schemas, especially an allowlist for harmful-answer rows. |
| 4 | Medium | `compare_pod.sh:13`, `39` | On a resumed run without manually supplied `EVAL_SINCE`, metadata begins at the resume time and omits the initial model-serving history. | Persist the first-run timestamp in the evaluation output directory and reuse it on resumes, or fail closed unless `EVAL_SINCE` is supplied. |
| 5 | Low | `EVAL.md:155` | “Only because it wrote 6% fewer tokens” makes a causal claim from one unreplicated timing run. | Say the shorter wall time is consistent with fewer output tokens; retain the observed per-token rates. |

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | `score` requires each verdict file's ids to equal the dataset's exactly and every row to be a well-formed verdict or invalid marker for that judge | Re-scored; passes |
| 2 | `pull_eval.sh` pins the expected tasks and item counts locally and requires the manifest to match | Pull passes |
| 3 | `pull_eval.sh` accepts only an explicit list of files and only known fields in harmful-answer rows | A copy with an extra file, or a harmful row with an extra `text` field, is refused; the real one passes |
| 4 | `compare_pod.sh` keeps the run's start in `/workspace/eval/.run_since`, so a resumed run keeps it | Metadata regenerated from it |
| 5 | Speed wording: "consistent with" fewer tokens, one run each | EVAL.md |
