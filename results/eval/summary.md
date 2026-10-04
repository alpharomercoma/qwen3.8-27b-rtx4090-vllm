| Benchmark (metric) | qwen3.8-27b | qwen3.8-27b-heretic | Difference (qwen3.8-27b-heretic − qwen3.8-27b), 95% CI | McNemar p | n |
|---|---|---|---|---|---|
| MMLU-Pro (accuracy) | 78.7% | 77.3% | -1.4 pts [-3.1, +0.1] | 0.1 | 1400 |
| MMLU-Pro (accuracy, "answer is (X)" / "Answer: X" only) | 76.9% | 76.3% | -0.6 pts [-2.1, +1.0] | 0.543 | 1400 |
| GSM8K (accuracy) | 96.1% | 95.1% | -0.9 pts [-1.7, -0.2] | 0.029 | 1319 |
| IFEval (prompt-level strict) | 81.5% | 82.1% | +0.6 pts [-2.2, +3.3] | 0.795 | 541 |
| IFEval (prompt-level loose) | 85.8% | 84.8% | -0.9 pts [-3.5, +1.7] | 0.59 | 541 |
| HumanEval (pass@1) | 93.9% | 93.9% | +0.0 pts [-2.4, +2.4] | 1 | 164 |
| JBB harmful: refused (judge qwen3.8-27b) | 96.0% | 23.0% | -73.0 pts [-82.0, -64.0] | 2.12e-22 | 100 |
| JBB harmful: refused (judge qwen3.8-27b-heretic) | 95.0% | 7.0% | -88.0 pts [-94.0, -81.0] | 6.46e-27 | 100 |
| JBB harmful: refusal words (Heretic's markers) | 95.0% | 65.0% | -30.0 pts [-39.0, -21.0] | 1.86e-09 | 100 |
| JBB benign: refused (judge qwen3.8-27b) | 24.0% | 1.0% | -23.0 pts [-32.0, -15.0] | 2.38e-07 | 100 |
| JBB benign: refused (judge qwen3.8-27b-heretic) | 21.0% | 0.0% | -21.0 pts [-29.0, -14.0] | 9.54e-07 | 100 |
| JBB benign: refusal words (Heretic's markers) | 41.0% | 14.0% | -27.0 pts [-36.0, -18.0] | 4.63e-07 | 100 |

| Answer length and limits | qwen3.8-27b | qwen3.8-27b-heretic |
|---|---|---|
| mmlu_pro: mean output tokens / hit the cap / errors | 1334.4 / 112 / 0 | 1221.8 / 95 / 0 |
| gsm8k: mean output tokens / hit the cap / errors | 377.8 / 27 / 0 | 376.5 / 29 / 0 |
| ifeval: mean output tokens / hit the cap / errors | 330.1 / 8 / 0 | 324.1 / 9 / 0 |
| humaneval: mean output tokens / hit the cap / errors | 268.2 / 5 / 0 | 257.0 / 4 / 0 |
| jbb_harmful: mean output tokens / hit the cap / errors | 206.4 / 52 / 0 | 256.0 / 100 / 0 |
| jbb_benign: mean output tokens / hit the cap / errors | 243.5 / 88 / 0 | 254.3 / 97 / 0 |

| Speed (16 requests at a time) | qwen3.8-27b: wall s / output tok/s / latency p50 / p95 s | qwen3.8-27b-heretic: wall s / output tok/s / latency p50 / p95 s |
|---|---|---|
| gsm8k (1319 prompts) | 817.8 / 609.3 / 9.117 / 17.095 | 810.8 / 612.5 / 8.991 / 16.589 |
| mmlu_pro (1400 prompts) | 2919.9 / 639.8 / 21.423 / 101.064 | 2706.5 / 632.0 / 20.316 / 101.052 |
| ifeval (541 prompts) | 307.7 / 580.3 / 5.387 / 28.848 | 308.4 / 568.6 / 5.203 / 27.46 |
| humaneval (164 prompts) | 89.0 / 494.2 / 5.973 / 16.341 | 86.7 / 486.1 / 5.89 / 16.896 |
| jbb_harmful (100 prompts) | 37.0 / 557.9 / 6.366 / 7.361 | 41.5 / 616.9 / 5.993 / 6.056 |
| jbb_benign (100 prompts) | 37.9 / 642.5 / 6.193 / 6.409 | 42.0 / 605.5 / 6.108 / 6.214 |
| harmless (200 prompts) | 4.0 / 50.0 / 0.278 / 0.926 | 3.2 / 62.5 / 0.227 / 0.325 |

Agreement between the two judges: jbb_harmful qwen3.8-27b 99.0%; jbb_harmful qwen3.8-27b-heretic 84.0%; jbb_benign qwen3.8-27b 97.0%; jbb_benign qwen3.8-27b-heretic 99.0%.

| MMLU-Pro category | qwen3.8-27b | qwen3.8-27b-heretic |
|---|---|---|
| biology | 90.0% | 90.0% |
| business | 92.0% | 91.0% |
| chemistry | 87.0% | 87.0% |
| computer science | 84.0% | 80.0% |
| economics | 91.0% | 89.0% |
| engineering | 65.0% | 62.0% |
| health | 78.0% | 77.0% |
| history | 62.0% | 60.0% |
| law | 57.0% | 55.0% |
| math | 90.0% | 86.0% |
| other | 72.0% | 70.0% |
| philosophy | 66.0% | 70.0% |
| physics | 83.0% | 84.0% |
| psychology | 85.0% | 81.0% |

First-token KL(qwen3.8-27b || qwen3.8-27b-heretic) on 200 harmless prompts (top-20 proxy): mean 0.091, median 0.030; same most likely first token 93.0%.
