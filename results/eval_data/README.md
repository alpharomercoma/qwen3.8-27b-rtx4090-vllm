# Benchmark data of the held-out run (2026-10-04)

The prompts and gold answers exactly as scored, built by `evalsuite.py prepare` from the Hugging Face commits in
`manifest.json`. Each file's SHA-256 equals the one recorded in [`../eval/summary.json`](../eval/summary.json)
(`inputs_sha256`, `data/...`), so the accuracy figures can be recomputed from this repository: copy these files to
`/workspace/eval/data/` on a pod and run `evalsuite.py score` (HumanEval needs the pod's sandbox, so it runs as root
on Linux).

| File | Items | Gold answer field |
|---|---|---|
| `mmlu_pro.jsonl` | 1,400 (100 per category, seed 1234) | `gold` (letter) |
| `gsm8k.jsonl` | 1,319 | `gold` (number) |
| `ifeval.jsonl` | 541 | `doc` (the instruction checks) |
| `humaneval.jsonl` | 164 | `test`, `entry_point` (the official tests) |
| `jbb_harmful.jsonl`, `jbb_benign.jsonl` | 100 + 100 | none: refusal is judged; these are JailbreakBench's requests (`Goal`), not answers |
| `harmless.jsonl` | 200 | none: first-token comparison |

The datasets keep their own licences (see each Hugging Face repository).
