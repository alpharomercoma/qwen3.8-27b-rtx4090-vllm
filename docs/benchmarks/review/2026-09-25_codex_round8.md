## 1. Round-7 items

| Item | Status | Current line | Check |
|---:|---|---|---|
| 2 | FIXED | REPORT.md:321 (`REPORT.md:321`) | Other full-attention models are marked “Not tested”; pinning is not recommended for them. |
| 4 | NOT FIXED | REPORT.md:204–205, 308 (`REPORT.md:204`) | The claims about eviction, rereading the whole context, and cache survival still generalize beyond the tested gaps and load. |
| 5 | FIXED | REPORT.md:324 (`REPORT.md:324`) | Active parameters are called a probable contributor; the report says the comparison was not isolated. |
| 9 | FIXED | REPORT.md:292 (`REPORT.md:292`) | The kernel difference is a possible reason, and the report says it was not isolated. |
| 11 | FIXED | REPORT.md:288 (`REPORT.md:288`) | It distinguishes 32k per slot from 131,072 tokens across four runner slots. |

## 2. Remaining problems

| Current line(s) | Problem |
|---|---|
| REPORT.md:204–205, 308 (`REPORT.md:204`) | The one-pool Qwen tests do not establish that eviction only follows newer requests, that any eviction forces a full-context reread, or that cache survival follows from KV cost per token alone. |
| REPORT.md:344 (`REPORT.md:344`) | “Up to 4 users only” misstates SGLang’s cap: it is four running requests, so more users can queue. |
| REPORT.md:166 (`REPORT.md:166`) | “Within 1 to 2% on every … decode cell” conflicts with the two-request result: total throughput is 82.5 vs 86.5 tok/s and TTFT is 0.695 vs 0.626 s (FINDINGS.md:116 (`FINDINGS.md:116`), FINDINGS.md:118 (`FINDINGS.md:118`); matching raw summaries). |
| REPORT.md:97, 288 (`REPORT.md:97`) | 26,405 and 26,565 are mean input-token counts, not fixed truncation lengths. The raw 32k probes include inputs of 30,375, 16,386, and 32,454 tokens for Qwen, and 30,817, 16,386, and 32,493 for gpt-oss (Qwen summary (`results/raw/ollama_p4_prefill_20260923-084911.summary.json`), gpt-oss summary (`results/raw/ollama_gptoss-h2_prefill_20260924-185405.summary.json`)). |

**VERDICT: NEEDS FIXES**
