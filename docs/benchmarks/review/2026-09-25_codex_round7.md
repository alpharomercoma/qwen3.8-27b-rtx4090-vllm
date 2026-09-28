## 1. Round 6 findings

| # | Status | Current line(s) | Assessment |
|---:|---|---|---|
| 1 | Rejection correct | REPORT.md:209–215 (`REPORT.md:209`) | The finding misread the columns. At 2 and 4 minutes, Quiet server is “not run”; both 4-agent and 8-agent cells are 0%. The retention summaries confirm this. |
| 2 | PARTLY | REPORT.md:321 (`REPORT.md:321`) | The report now frames pinning as a recommendation after the fp8 OOM, not a requirement. The recommendation for untested other full-attention models still generalizes beyond the measured cases. |
| 3 | FIXED | REPORT.md:297–306 (`REPORT.md:297`) | The configs and external source are now present. Running `bench/fit.py --shape-only` with bf16 KV and fp16 state reproduces the table, including Qwen3.8’s 74.81 MiB, rounded to 75 MiB. |
| 4 | PARTLY | REPORT.md:204–226, 308 (`REPORT.md:204`) | The larger-pool claim is now labeled expected, not measured. The general claims about eviction and how architecture determines cache survival remain broader than the one-pool, up-to-15-minute tests support. |
| 5 | NOT FIXED | REPORT.md:18, 272–275, 324 (`REPORT.md:18`) | The wait comparison is tied to the tested configs, but line 324 still calls active parameters the “likely main reason” despite differing output lengths and cache-hit shares. |
| 6 | FIXED | REPORT.md:185–186 (`REPORT.md:185`) | New-context waits are separated from the reused light user’s 1.0-second first turn. |
| 7 | FIXED | REPORT.md:274 (`REPORT.md:274`) | It now says forcing continuation with `ignore_eos` produced parser errors, consistent with the invalid-run README. |
| 8 | FIXED | REPORT.md:309 (`REPORT.md:309`) | The claim is scoped to Qwen3.8 and names vLLM’s block alignment and SGLang’s state slots separately. |
| 9 | PARTLY | REPORT.md:291–292 (`REPORT.md:291`) | The logged kernel names are corrected and the lack of isolation is disclosed, but “likely reason” still presents the kernel difference as a stronger cause than measured. |
| 10 | FIXED | FINDINGS.md:146 (`FINDINGS.md:146`) | The shorter token counts are now scoped to `ollama/p4`, with gpt-oss counts reported separately. |
| 11 | PARTLY | REPORT.md:288 (`REPORT.md:288`) | “Configured” replaces “by default,” but the gpt-oss Ollama runner log reports `-c 131072` despite the launcher setting `OLLAMA_CONTEXT_LENGTH=32768`. The requested and effective context settings need to be distinguished. |

## 2. Remaining problems

| Current line(s) | Problem and evidence |
|---|---|
| REPORT.md:14 (`REPORT.md:14`) | “Only up to 4 users” misstates the SGLang cap: the report describes a config limited to 4 concurrent requests. The limit is about active requests/agents, not users. |
| REPORT.md:204–205, 308 (`REPORT.md:204`) | The tests support specific cache-survival observations, but do not establish that eviction only follows newer traffic or that per-token KV cost alone determines survival time. Scope these statements to the tested gaps and load. |
| REPORT.md:292, 319–321, 324 (`REPORT.md:292`) | Some architecture claims still exceed the evidence: the kernel is called the “likely reason”; token-level reuse is asserted for untested full-attention models; pinning is recommended for untested models; and active parameters remain the “likely main reason” for the speed gap. |
| REPORT.md:288 (`REPORT.md:288`) | The report says the gpt-oss Ollama test configured a 32k context, while server_log_excerpts.txt:63 (`results/evidence/server_log_excerpts.txt:63`) records the runner at 131072. `pod/serve.sh` sets the 32768 environment value at line 120, so clarify that it was requested and report the runner’s effective value. |
| REPORT.md:367 (`REPORT.md:367`) | “Real sessions” is ambiguous: the report also shows synthetic multi-agent contexts averaging 12.8k–13.2k tokens. Specify whether this means real pi sessions. |
| REPORT.md:370 (`REPORT.md:370`) | This says 12- and 16-agent sessions were not run outside three Qwen vLLM configs, but gpt-oss vLLM has 12- and 16-agent results; line 372 and FINDINGS.md:233 (`FINDINGS.md:233`) make the model scope clearer. Limit this bullet to Qwen3.8. |

No bullet in the named sections exceeds two sentences.

**VERDICT: NEEDS FIXES**
