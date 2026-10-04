# Codex QA, held-out eval round 21: gpt-5.6-terra, reasoning xhigh, read-only (2026-10-04)

Prior-round verification

| Round | Status | Note |
|---|---|---|
| R1 | FIXED (R1-1–R1-8) | Fail-closed HumanEval controls, extraction patterns, caps, strict judge parsing, retrying, reproduction path, median, and bootstrap checks are present. |
| R2 | FIXED (R2-1–R2-8) | Private permissions, UID/process cleanup, redacted invalid rows, historic timing disclosure, and wording corrections hold. |
| R3 | FIXED (R3-1–R3-5) | `setpriv` drops privileges/capabilities; six-comparison Holm wording and installer handling are correct. |
| R4 | FIXED (R4-1–R4-4) | N/A filtering, KL normalization, completeness gating, and staged pulling are implemented. |
| R5 | FIXED (R5-1–R5-4) | Required metric matrix, conservative wording, UID cleanup, and forced server restart are present. |
| R6 | FIXED (R6-1); FIXED as accepted limit (R6-2) | Repeated UID cleanup is implemented; injection sensitivity remains accurately disclosed as directed. |
| R7 | FIXED (R7-1–R7-3) | vLLM key is removed from its launch argv; canaries gate headline scoring; judge-text limitation is documented. |
| R8 | FIXED (R8-1–R8-3) | Recursive harmful-artifact scan, required tools, and token-key collision disclosure are present. |
| R9 | FIXED (R9-1–R9-3) | Staging permissions, metadata, and wording are corrected. |
| R10 | FIXED (R10-1–R10-2) | Tests arrive on stdin; pull validation has the complete matrix. |
| R11 | FIXED (R11-1–R11-4) | Exact valid labels, artifact checks, existing-key permissions, and wording are correct. |
| R12 | FIXED (R12-1–R12-4) | Data/HF cache access controls, row identity fields, parsed pull checks, and full-match parsing are present. |
| R13 | FIXED (R13-1–R13-4) | Legacy rows are explicit, canaries/verdicts are validated, and wording is corrected. |
| R14 | FIXED (R14-1–R14-3); NOT APPLICABLE (R14-4) | Canonical rows, metadata hashing, and secret scanning hold. |
| R15 | FIXED (R15-1–R15-2) | Raw input hashes bind the summary; extra/foreign verdict rows are rejected. |
| R16 | FIXED (R16-1–R16-5) | Schema/id, pinned counts, allowlist, run start, and wording checks hold. |
| R17 | FIXED (R17-1–R17-2) | A/B is generated, validated, and included in `inputs_sha256`. |
| R18 | FIXED (R18-1–R18-3) | The recorded rescore attests to an identical `summary.md`; partial/error outputs are rejected. |
| R19 | FIXED (R19-1) | Headline `raw` is canonical `Yes`/`No`. |
| R20 | PARTLY (R20-1); FIXED (R20-2); NOT FIXED (R20-3) | The rescore claim is narrower, but still overstates what `summary.md` attests; round 20 itself reintroduces literal `home-directory ` text. |

I recomputed JSONL-derived timing/token aggregates, headline and A/B refusal totals, canaries, caps, KL, and 44 published artifact hashes. They match `summary.json`, `summary.md`, `docs/EVAL.md`, and the root README’s summary sentence. Gold-dependent accuracy cannot be independently recomputed without the pinned data items, but matches `summary.json`. The official MMLU-Pro extraction ordering and JailbreakBench prompt also match the cited upstream implementations. [MMLU-Pro evaluator](https://raw.githubusercontent.com/TIGER-AI-Lab/MMLU-Pro/main/evaluate_from_apiX.py), [JailbreakBench classifier](https://raw.githubusercontent.com/JailbreakBench/jailbreakbench/main/src/jailbreakbench/classifier.py)

| # | Severity | File:line | Finding | Suggested fix |
|---:|---|---|---|---|
| 1 | medium | `docs/EVAL.md:4-7`; `results/eval/README.md:10`; `bench/evals/evalsuite.py:813-835` | The rescore only records/verifies byte identity of `summary.md`. That file does not contain every published table value: it omits capability counts and discordant pairs, Wilson intervals, cutoff-subset accuracy, and all A/B sensitivity values. `--original-summary` performs the broader future check only when supplied. Thus the statement that `summary.md` “holds every number in the tables below” is false. | Say only that the generated report was byte-identical. For a full-rescore claim, require `--original-summary` with `--rescore-of` and attest to a canonical projection covering every published metric. |
| 2 | low | `docs/review/2026-10-04_codex_terra_eval_round20.md:39,48` | R20-3 is not fixed literally: the QA record itself contains `home-directory ` twice while claiming a grep finds none. Neither occurrence is a personal path. | Replace those literals with “personal home-directory path” and avoid embedding the scan needle in its own test record. |

No harmful JBB response text, credentials, non-loopback IPs, pod IDs, or actual `home-directory /...` personal paths were found in the checked-in evaluation artifacts or QA records.

NEEDS FIXES
## Resolution

| # | Change | Test |
|---|---|---|
| 1 | EVAL.md says exactly what was compared: the generated report `summary.md` byte-identical by hash; datasets by hand; counts, intervals and prompts A/B not compared by code. `metadata --rescore-of` now needs `--original-summary` (every metric and the datasets compared) or an explicit `--report-only`, which is recorded | Without either it stops; with `--report-only` the entry records `identical: ["summary.md"]`; pull passes |
| 2 | Round-20 record reworded without the literal path prefix | Search finds none |
