## 1. Round-8 items

| Item | Status | Current line | Check |
|---|---|---|---|
| Cache eviction wording (round-8 item 4) | **NOT FIXED** | REPORT.md:204–205 (`REPORT.md:204`) | Still says the table shows when eviction happened and that an evicted context was fully reread. |
| SGLang concurrency wording | **NOT FIXED** | REPORT.md:14, 344 (`REPORT.md:14`) | The headline says “only up to 4 agents”; the report also describes an 8-running configuration with a smaller pool. |
| Host reproduction tolerance | **FIXED** | FINDINGS.md:166–168 (`FINDINGS.md:166`) | Separates the 2% prefill/per-user decode claim from the 5% total-throughput difference. |
| Ollama truncation numbers | **FIXED** | REPORT.md:97, 288 (`REPORT.md:97`) | Raw rows show Qwen Ollama/VLLM inputs of 30,375/30,435; 16,386/35,212; 32,454/32,494, and gpt-oss inputs of 30,817/30,824; 16,386/34,133; 32,493/32,501. One prompt in each set was truncated. |

## 2. Remaining problems

| Current line | Problem |
|---|---|
| REPORT.md:14, 344 (`REPORT.md:14`) | “Only up to 4 agents” conflicts with the described 8-running SGLang configuration; qualify four as the balanced configuration. |
| REPORT.md:204–205 (`REPORT.md:204`) | The sampled cache results do not establish the eviction timing or justify generalizing full rereads to evictions beyond these probes. |
| REPORT.md:337 (`REPORT.md:337`) | 45.9 s is labeled a first-token wait; it is a tok/s figure. The report records a 53.0 s p90 wait at 12 agents, and the raw team run’s maximum is 60.4 s. |

**VERDICT: NEEDS FIXES**
