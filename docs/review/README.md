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
