## Part 1

| Round 3 item | Status | Current line(s) | Review |
|---|---|---:|---|
| B5 — SGLang recommendation and wait metric | FIXED | REPORT.md 14, 213 | The recommendation is scoped to four users, and line 14 identifies the comparison as p50. |
| Task B1 — SGLang team verdict | FIXED | REPORT.md 14, 213 | The threshold and wait metric are now stated. |
| Task B2 — Muse Glimmer sequence estimates | FIXED | REPORT.md 250; FINDINGS.md 224 | REPORT.md no longer gives full-context sequence counts. FINDINGS.md labels its estimates and states the overhead assumptions. |
| Task B3 — Batched benchmark attribution | FIXED | REPORT.md 62, 64–68 | Line 62 explicitly attributes the last column to `llama-batched-bench`. |

## Part 2: Remaining problems

| REPORT.md line(s) | Problem | Evidence |
|---|---|---|
| 59; compare FINDINGS.md 63–65 | The files contradict each other on IQ4_XS quality. REPORT.md says no published IQ4_XS vs Q4_K_XL comparison was found; FINDINGS.md says IQ4_XS is measurably less faithful. | `external_sources.txt` lists Q4_K_XL KLD and an IQ3-class retrieval claim, but no IQ4_XS comparison. |
| 62, 64–68; compare FINDINGS.md 55–61 | REPORT.md labels the 16-sequence column as batched benchmark data, but FINDINGS.md presents that column under its llama-bench quant ladder without distinguishing the batched source. | The batched values are in `*_batched.jsonl`; `bench/summarize.py` separates llama-bench and llama-batched-bench. |

**VERDICT: NEEDS FIXES**  
Claims checked: **132** line-level targets (number-bearing lines and Verdict bullets).
