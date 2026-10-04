# Heretic vs original: raw benchmark results

Written by [`bench/evals/evalsuite.py`](../../bench/evals/evalsuite.py) on 2026-10-04; the write-up is
[docs/EVAL.md](../../docs/EVAL.md). Copied from the pod with `scripts/pull_eval.sh`.

| File | What |
|---|---|
| `manifest.json` | Each dataset's Hugging Face repo, split, commit, item count and output cap |
| `summary.json` | Every score, interval, paired test, length, latency and timing (`evalsuite.py score`) |
| `summary.md` | The same as tables (`evalsuite.py report`) |
| `run_metadata.json` | GPU, driver, vLLM/torch and scoring package versions, model checkpoints and file-manifest hashes, and every vLLM start of the run with its exact command (`evalsuite.py metadata`); `rescored`: the later scoring on a second pod, with the hashes of the code and the summaries it produced |
| `<model>/<task>.jsonl` | One line per prompt: `id`, `latency_s`, `prompt_tokens`, `completion_tokens`, `finish_reason`, `response` (the answer); `harmless` also has `top_logprobs` of the first token |
| `<model>/jbb_harmful.jsonl` | The same, **without the answer text**: only its `response_sha256`, `response_chars` and `refusal_markers`. The answers stay on the pod in `/workspace/eval/private/` |
| `<model>/jbb_*_judge_<judge>.jsonl` | The judge's verdict per answer: `refused`, and its reply as a canonical label (`raw`: `Yes` = refused, `No` = not; the reply had to be exactly that, in any case, with at most a full stop); any other reply is stored as `invalid` without its text (none in this run) |
| `judge_canaries_<judge>.json` | The two injection checks of the last judge pass: expected and given label |
| `judge_prompts/A/`, `judge_prompts/B/` | The same answers judged with the two earlier judge prompts (docs/EVAL.md → "The judge's prompt matters"); the headline verdicts in `<model>/` use JailbreakBench's prompt |
| `<model>/timing.jsonl` | Wall time per task run (a `0 items` line is a resumed run with nothing left to do). This run's rows predate the `max_tokens` field; the caps are in `manifest.json`. Answer rows written from now on also carry `prompt_sha256` and `max_tokens`, so a resumed run cannot mix answers to other prompts or caps; this run's rows predate them and were scored with `--legacy-rows` |

`<model>` is `qwen3.8-27b` (the original) or `qwen3.8-27b-heretic`. Prompts are rebuilt from the datasets by
`evalsuite.py prepare`; item ids match across both models.
