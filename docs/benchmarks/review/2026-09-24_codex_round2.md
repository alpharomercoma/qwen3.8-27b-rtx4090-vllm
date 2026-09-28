Read-only review; no files were modified.

## Task A

| # | Round-1 finding (short) | Status | Note |
|---:|---|---|---|
| 1 | SGLang pool count | FIXED | 157 (`REPORT.md:157`) gives 51,908 for 0.5.20 and about 52.2k for 0.5.19. |
| 2 | Gateway paths and check count | FIXED | 33 (`REPORT.md:33`), 199 (`REPORT.md:199`), 200 (`REPORT.md:200`) include `/healthz` and specify 40 keyed model checks. |
| 3 | SGLang versions described as identical | FIXED | 85 (`REPORT.md:85`) says “within 2%”; 86 (`REPORT.md:86`) gives a measured difference. |
| 4 | 298k int4 pool confused with fp8 crash | FIXED | 163 (`REPORT.md:163`)–165 (`REPORT.md:165`) separate the successful int4 run from the fp8 OOM. |
| 5 | Cross-host 32k prefill comparison | FIXED | 98 (`REPORT.md:98`) identifies the comparison as host 2. |
| 6 | llama.cpp called single-user only | FIXED | 15 (`REPORT.md:15`) and 212 (`REPORT.md:212`) scope the issue to failures at 8 agents. |
| 7 | Ollama called single-user only | FIXED | 13 (`REPORT.md:13`) and 213 (`REPORT.md:213`) describe serialized requests and queued users. |
| 8 | SGLang described as capped at four | FIXED | 14 (`REPORT.md:14`) and 211 (`REPORT.md:211`) explain the four-request balance and eight-request tradeoff. |
| 9 | 16 agents called past the limit | FIXED | 139 (`REPORT.md:139`) describes a usability limit despite zero errors. |
| 10 | 10–15 agent projection | FIXED | 141 (`REPORT.md:141`) labels it untested and states the real pi test reached 8. |
| 11 | Memory said to limit capacity instead of compute | PARTLY | 16 (`REPORT.md:16`) and 153 (`REPORT.md:153`)–155 (`REPORT.md:155`) still make causal claims; the capacity explanation also conflicts with FINDINGS.md. |
| 12 | Memory bandwidth presented as measured limit | FIXED | 71 (`REPORT.md:71`) labels it an inference. |
| 13 | All numbers attributed to raw summaries and llama-bench | FIXED | 5 (`REPORT.md:5`)–6 (`REPORT.md:6`) distinguish evidence and external sources. |
| 14 | Host-1 int4 pool presented as exactly verified | PARTLY | 149 (`REPORT.md:149`) and 156 (`REPORT.md:156`) disclose the overwritten log, but the claim that the value is not in evidence is false. |
| 15 | FP8 and RedHat disk sizes lacked attribution | FIXED | 51 (`REPORT.md:51`) attributes checkpoint sizes to external sources. |
| 16 | Ollama model and projector sizes lacked attribution | FIXED | 51 (`REPORT.md:51`) names the Ollama registry. |
| 17 | IQ4_XS accuracy claim lacked a source | PARTLY | 59 (`REPORT.md:59`) says “published tests,” but the listed evidence does not support an IQ4_XS accuracy comparison. |
| 18 | Thinking-format claim lacked A/B evidence | FIXED | 192 (`REPORT.md:192`) cites the A/B evidence. |
| 19 | Tunnel status and missing inputs | FIXED | 202 (`REPORT.md:202`)–204 (`REPORT.md:204`) and the tunnel setup steps identify the pending inputs. |
| 20 | Cloudflare 100-second limit lacked attribution | FIXED | 204 (`REPORT.md:204`) attributes it to Cloudflare docs; it is listed in external_sources.txt. |
| 21 | vLLM preemption claim | FIXED | 210 (`REPORT.md:210`) now says requests queue; FINDINGS.md still describes preemption. |
| 22 | “No fix” for Ollama parallelism | FIXED | 223 (`REPORT.md:223`) narrows this to no fix found for version 0.34.3. |
| 23 | Muse Glimmer size/version and sizing estimate | PARTLY | 248 (`REPORT.md:248`) marks the version claim external, but its listed compatibility source is not traceable to a specific reference. |

## Task B

| # | REPORT.md line | Claim | Evidence (file and value) | Verdict | Fix |
|---:|---|---|---|---|---|
| 1 | 155 (`REPORT.md:155`) | KV cache was “only 11 to 30% full” while requests waited. | `results/evidence/thinking_ab_and_queueing.txt:10–15` reports 10.9–30.1% usage, then clarifies that this counts blocks held by running requests, not free cached prefixes. | WRONG | Describe the observed running-request KV usage; do not call it total cache fullness. |
| 2 | 156 (`REPORT.md:156`) | The overwritten host-1 pool value is “not in results/evidence.” | `results/evidence/thinking_ab_and_queueing.txt:17–18` lists the overwritten 180,558-token value. | WRONG | Say the original server log is unavailable and the value is recorded only in the overwrite note. |
| 3 | 128 (`REPORT.md:128`), 154 (`REPORT.md:154`), 173 (`REPORT.md:173`) | `cached_share` is described as “prefix cache hits.” | `bench/loadgen.py:7–8,188–190` defines this as the share of input tokens cached; pinned host-2 summaries report `.544` at 12 agents and `.106` at 16. | MISLEADING | Rename it “cached input-token share” throughout. |
| 4 | 16 (`REPORT.md:16`), 153 (`REPORT.md:153`)–155 (`REPORT.md:155`) | Prefill compute sets the limit through 8 agents, then cache misses cause the queue. | Raw pool comparisons show different wait and cached-share results; queue snapshots show waiting requests, but do not isolate the cause. `FINDINGS.md:28–33` instead says capacity is set by memory, not compute. | MISLEADING | State the observed relationships without assigning an exclusive cause, and reconcile the capacity explanation in FINDINGS.md. |
| 5 | 14 (`REPORT.md:14`), 211 (`REPORT.md:211`) | SGLang is “Not” for a 24 GB GPU and “fastest” for 1–2 users. | `results/raw/sglang_int4_agent_20260923-083855.summary.json` has zero errors at 4 agents; its 1-agent turn TTFT is 0.55 s. `pod/serve.sh` also documents an 8-request option and its smaller pool. | MISLEADING | Scope the recommendation to team concurrency; specify that “fastest” means median agent-turn TTFT. |
| 6 | 59 (`REPORT.md:59`) | IQ4_XS is less accurate in published tests. | `results/evidence/external_sources.txt:20` lists Q4_K_XL KLD and an IQ3-class retrieval claim, but no IQ4_XS accuracy result; local quant quality is unmeasured. | UNSUPPORTED | Cite a published IQ4_XS comparison or remove the claim. |
| 7 | 210 (`REPORT.md:210`) | vLLM queues requests instead of failing. | `results/evidence/thinking_ab_and_queueing.txt:7–8` records up to 13 waiting requests and zero log lines mentioning preemption; `FINDINGS.md:167` says vLLM preempts. | MISLEADING | Reconcile the mechanism across both reports and describe only what the retained evidence establishes. |
| 8 | 237 (`REPORT.md:237`) | 12- and 16-agent sessions were tested only for “vLLM int4.” | Raw summaries include host-1 `int4-kv4`, host-2 `int4-kv4-h2`, and pinned host-2 `int4-kv4-pin-h2`; `FINDINGS.md:216` names only `vllm/int4-kv4`. | MISLEADING | List the tested configs explicitly and align the “Not measured” note in FINDINGS.md. |
| 9 | 12 (`REPORT.md:12`)–16 (`REPORT.md:16`), 192 (`REPORT.md:192`) | Verdict and thinking bullets contain more than two sentences. | These bullets each use three sentence-like statements; line 192 has three sentences. | FORMAT | Split or shorten them to at most two sentences per bullet. |

VERDICT: NEEDS FIXES — 351 claims checked (295 populated table cells and 56 non-table content lines; compound entries counted once).
