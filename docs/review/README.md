# QA record: Codex (gpt-5.6-terra, reasoning xhigh), 2026-09-28 and 09-29

Adversarial, read-only review of the whole repository before its first push: credentials in the commit set, the pi
and opencode configuration, whether the step-by-step docs work as written, bugs in the scripts and the web app, and
whether the numbers in the docs match the raw results. Each round checked the previous rounds' fixes, then reviewed
everything again. `gpt-6-terra` is not available on this Codex account, so `gpt-5.6-terra` was used.

| Round | New findings | Most important | Verdict |
|---|---|---|---|
| [1](2026-09-28_codex_terra_round1.md) | 9 (2 high) | Root command injection through the pod's tunnel key in `scripts/edge.sh`; pod host key trusted on first use | Needs fixes |
| [2](2026-09-28_codex_terra_round2.md) | 5 | A literal password in DEPLOY.md; `start.sh` continued after a gateway failure | Needs fixes |
| [3](2026-09-29_codex_terra_round3.md) | 5 | The web dialog's config would replace, not merge, existing pi/opencode configs | Needs fixes |
| [4](2026-09-29_codex_terra_round4.md) | 3 | Unverified downloads (uv, vLLM wheel, Caddy) | Needs fixes |
| [5](2026-09-29_codex_terra_round5.md) | 2 | 8,192-token answers could outlast Vercel's 300 s limit | Needs fixes |
| [6](2026-09-29_codex_terra_round6.md) | 2 | Model downloaded from a mutable branch | Needs fixes |
| [7](2026-09-29_codex_terra_round7.md) | 1 | Undocumented 15-minute edge timeout | Needs fixes |
| [8](2026-09-29_codex_terra_round8.md) | 2 | sshd `Match` block not explicitly closed; 600 s SSH timeout vs a first start | Needs fixes |
| [9](2026-09-29_codex_terra_round9.md) | 1 | A home path inside a review record | Needs fixes |
| [10](2026-09-29_codex_terra_round10.md) | 3 | Forged tokens could make `authz.py` refetch Vercel's keys without limit | Needs fixes |
| [11](2026-09-29_codex_terra_round11.md) | 0 | | **PASS** |

Each round's file ends with a Resolution table: what was changed and how it was tested. Two items are accepted and
documented in [../SECURITY.md](../SECURITY.md): Python dependencies from PyPI / PyTorch's index are TLS-only (direct
downloads are checksum-verified), and there is no password-attempt limiter (all web traffic reaches Vercel from the
edge's single IP, so a limiter would be global and could lock the team out).

The review never touched production. Things only a running pod can prove (a fresh-pod install, the GPU-dependent
Playwright tests) were verified earlier in the session or are marked as not yet run in the Resolution tables.

## Second change: two models, no dependency on the other project (2026-09-29)

Adds the original model (`RedHatAI/Qwen3.8-27B-INT4`) next to Heretic, one served at a time; the web app discovers
which; the edge installer no longer relies on the other project's Caddyfile template.

| Round | New findings | Most important | Verdict |
|---|---|---|---|
| [1](2026-09-29_codex_terra_switch_round1.md) | 5 (1 high) | Import-line check matched any site block, not the `alphaexperiments.com` one | Needs fixes |
| [2](2026-09-29_codex_terra_switch_round2.md) | 1 (high) | `du` on a missing directory aborted the first model download under `set -e` | Needs fixes |
| [3](2026-09-29_codex_terra_switch_round3.md) | 2 | The terminal dialog showed the last-known model during a restart | Needs fixes |
| [4](2026-09-29_codex_terra_switch_round4.md) | 2 (low) | Two doc precision points | Needs fixes |
| [5](2026-09-29_codex_terra_switch_round5.md) | 0 | | **PASS** |

## Third change: held-out benchmark comparison, Heretic vs original (2026-10-04)

Adds `bench/evals/` (benchmark harness and pod pipeline), `scripts/pull_eval.sh`, [docs/EVAL.md](../EVAL.md) and
`results/eval/`, plus fixes for a fresh pod (`bootstrap.sh`, `install_vllm.sh`, `pod_connect.sh`) and vLLM's key moved
off its command line (`serve.sh`). Same reviewer and settings.

| Round | New findings | Most important | Verdict |
|---|---|---|---|
| [1](2026-10-04_codex_terra_eval_round1.md) | 8 (1 high) | HumanEval ran model-written code as root | Needs fixes |
| [2](2026-10-04_codex_terra_eval_round2.md) | 8 (1 high) | The sandbox fell back to root without `setpriv` | Needs fixes |
| [3](2026-10-04_codex_terra_eval_round3.md) | 5 (1 high) | Sandbox without `no_new_privs` and capability drop | Needs fixes |
| [4](2026-10-04_codex_terra_eval_round4.md) | 4 | KL proxy normalised inconsistently; partial results could be scored | Needs fixes |
| [5](2026-10-04_codex_terra_eval_round5.md) | 4 | Processes that start a new session could outlive the timeout | Needs fixes |
| [6](2026-10-04_codex_terra_eval_round6.md) | 2 | Judge prompt open to injection; led to JailbreakBench's own judge prompt and a prompt-sensitivity table | Needs fixes |
| [7](2026-10-04_codex_terra_eval_round7.md) | 3 (1 high) | vLLM's key on its command line, readable by any local user | Needs fixes |
| [8](2026-10-04_codex_terra_eval_round8.md) | 3 | Harmful-text check in `pull_eval.sh` not recursive | Needs fixes |
| [9](2026-10-04_codex_terra_eval_round9.md) | 3 | No record of what the run ran on (now `run_metadata.json`) | Needs fixes |
| [10](2026-10-04_codex_terra_eval_round10.md) | 2 | HumanEval tests readable from the program file | Needs fixes |
| [11](2026-10-04_codex_terra_eval_round11.md) | 4 | Judge reply parser too lenient | Needs fixes |
| [12](2026-10-04_codex_terra_eval_round12.md) | 4 | HumanEval tests readable by path from the data directory | Needs fixes |
| [13](2026-10-04_codex_terra_eval_round13.md) | 4 | Rows without a prompt hash were accepted silently | Needs fixes |
| [14](2026-10-04_codex_terra_eval_round14.md) | 4 | Retried rows appended rather than replaced; metadata hash not the committed scorer | Needs fixes |
| [15](2026-10-04_codex_terra_eval_round15.md) | 2 | The summary was not bound to the published raw files | Needs fixes |
| [16](2026-10-04_codex_terra_eval_round16.md) | 5 | Pull accepted any file; expected counts came from the pod | Needs fixes |
| [17](2026-10-04_codex_terra_eval_round17.md) | 2 | A clean reproduction would not produce the prompt-A/B files the pull requires | Needs fixes |
| [18](2026-10-04_codex_terra_eval_round18.md) | 3 | The re-scoring did not prove it matched the run | Needs fixes |
| [19](2026-10-04_codex_terra_eval_round19.md) | 1 | Judge parser and pull check disagreed on accepted replies | Needs fixes |
| [20](2026-10-04_codex_terra_eval_round20.md) | 3 | The re-scoring claim was broader than what was checked by code | Needs fixes |
| [21](2026-10-04_codex_terra_eval_round21.md) | 2 | `summary.md` does not hold every table value, so the re-scoring claim was still too broad | Needs fixes |
| [22](2026-10-04_codex_terra_eval_round22.md) | 2 | A suspected quoting bug in Reproduce (not one: tested verbatim); `score` did not check `raw` against `refused` | Needs fixes |
| [23](2026-10-04_codex_terra_eval_round23.md) | 1 | Published metadata had the previous scorer's hash after a failed push | Needs fixes |
| [24](2026-10-04_codex_terra_eval_round24.md) | 0 | | **PASS** |

After the push, an automated security review of the commit flagged sandbox secret exposure in `evalsuite.py`
(three findings, no details given). Checked on the pod: no file readable by the sandbox uid held any of the pod's
seven secret values (vLLM key, team keys, tunnel key lines). `score` now runs that search itself, as the sandbox uid
with the values on stdin, over `/workspace` (except model weights), `/tmp`, `/var/tmp`, `/dev/shm`, `/var/log`,
`/etc`, `/root`, `/home` and `/opt`, and refuses to run model code on a match. Tested: a planted readable copy of
the vLLM key and of a tunnel-key line each stop scoring; the clean run passes and re-scores identically.
