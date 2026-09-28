No files were modified. The referenced round-2 review contains **four** Task A rows marked PARTLY (items 11, 14, 17, and 23), not six; I reviewed all four, plus its nine Task B findings.

## Task A

| # | Item | Status | Note |
|---|---|---|---|
| B1 | Running-request KV usage described as cache fullness | FIXED | 140 (`REPORT.md:140`) attributes the 11–30% to blocks held by running requests. |
| B2 | Host-1 pool value provenance | FIXED | 157 (`REPORT.md:157`) says the log was overwritten and points to the evidence note containing the value. |
| B3 | `cached_share` wording | FIXED | 128 (`REPORT.md:128`), 154 (`REPORT.md:154`), and 174 (`REPORT.md:174`) describe cached input tokens. |
| B4 | Pool size and queue cause | FIXED | 16 (`REPORT.md:16`) and 153–156 (`REPORT.md:153`) report the comparisons; the cause at 156 is explicitly unisolated, consistent with FINDINGS.md. |
| B5 | SGLang team recommendation and wait metric | PARTLY | 14 (`REPORT.md:14`) gives its four-request balance, but the blanket “Not SGLang for a team” verdict still lacks a concurrency threshold. |
| B6 | IQ4_XS accuracy support | FIXED | 59 (`REPORT.md:59`) says quality was not measured and no published comparison was found. |
| B7 | vLLM queue/preemption wording | FIXED | 12 (`REPORT.md:12`) and 212 (`REPORT.md:212`) say requests queue; FINDINGS.md now agrees. |
| B8 | Configs tested at 12 and 16 agents | FIXED | 239 (`REPORT.md:239`) identifies all three tested int4-KV configs. |
| B9 | Bullets longer than two sentences | FIXED | Bullets at 12–16 (`REPORT.md:12`) and 192–194 (`REPORT.md:192`) are now at most two sentences each. |
| A11 | Capacity explanation versus compute | FIXED | 16 (`REPORT.md:16`) and 153–156 (`REPORT.md:153`) state observed relationships and label the proposed cause as unisolated. |
| A14 | Host-1 pool verification | FIXED | 149 (`REPORT.md:149`) and 157 (`REPORT.md:157`) distinguish the overwritten log from the retained note. |
| A17 | IQ4_XS accuracy claim | FIXED | 59 (`REPORT.md:59`) removes the unsupported comparison. |
| A23 | Muse Glimmer compatibility source | FIXED | 250 (`REPORT.md:250`) is backed by the specific repository path and version tags now listed in `external_sources.txt`. |

## Task B

| # | REPORT.md line | Claim | Evidence | Verdict | Fix |
|---:|---|---|---|---|---|
| 1 | 14 (`REPORT.md:14`), 211 (`REPORT.md:211`) | “Not SGLang for a team” is broader than the measured concurrency results support. | At 4 agents, SGLang had 0 errors and 1.7 s p50 turn TTFT; pinned vLLM had 2.3 s p50. At 8, SGLang’s p50 was 18.7 s versus 4.9 s for pinned vLLM. (`results/raw/sglang_int4_agent_20260923-083855.summary.json`; pinned summary; REPORT lines 120–121.) | MISLEADING | State the concurrency cutoff for the recommendation and specify whether the comparison is p50 or p90. |
| 2 | 250 (`REPORT.md:250`) | Muse/Qwen full-context sequence counts omit the memory-overhead assumption. | `bench/fit.py:60–61` defaults overhead to 2.5 GiB and gives a typical range of 1.5–3.5 GiB; with the weights and KV size matching the report, its 32k result changes from 30/5 at 1.5 GiB to 26/4 at 2.5 GiB. | UNLABELLED ASSUMPTION | State the overhead used and identify the counts as estimates. |
| 3 | 62 (`REPORT.md:62`), 64–68 (`REPORT.md:64`) | The 16-sequence throughput column is grouped under “llama-bench” without identifying the batched benchmark. | The values come from `*_batched.jsonl`; `bench/summarize.py:37–56` distinguishes `llama-bench` from `llama-batched-bench`. | MISATTRIBUTED | Label the 16-sequence column as `llama-batched-bench` or separate it from the llama-bench results. |

**353 claims checked** using the round-2 counting granularity: 295 non-header table cells and 58 prose lines.

**VERDICT: NEEDS FIXES**
