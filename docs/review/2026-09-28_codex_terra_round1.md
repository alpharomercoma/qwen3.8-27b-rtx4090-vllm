# Codex QA, round 1: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-28)

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | HIGH | `scripts/edge.sh:14` | Remote-root command injection through `POD_PUBKEY`. | The key, including its hostname-derived comment, is interpolated inside single quotes into a remote shell command. `edge/install.sh` validation happens after shell parsing. | Pass a base64-encoded value or otherwise shell-escape it before invoking SSH; strictly validate the optional comment locally. |
| 2 | HIGH | `scripts/pod.sh:6` | First connection silently trusts any new pod host key. | `StrictHostKeyChecking=accept-new` records an unverified key for the direct TCP address; the deployment flow uses a new public IP/port. | Require a verified fingerprint and use a dedicated pinned `UserKnownHostsFile` with `StrictHostKeyChecking=yes`. |
| 3 | MED | `pod/start.sh:5` | Startup can announce readiness with vLLM still unhealthy. | No `errexit`; after all 180 health probes fail while tmux remains alive, execution falls through to “vLLM ready,” gateway, and tunnel. | Enable `set -euo pipefail` and make a final health check mandatory before continuing. |
| 4 | MED | `docs/CLIENTS.md:78` | pi docs incorrectly imply low/medium/high vary reasoning depth. | Installed pi’s `qwen-chat-template` implementation sends only boolean `enable_thinking`; the supplied config also sets `supportsReasoningEffort: false`. | State that `off` disables thinking and every non-off level enables the same server-side behavior. |
| 5 | MED | `docs/OPERATIONS.md:30` | New-pod key command fails as written. | The runbook says commands run from the Mac repo root, but `keys.sh add <name>` is not present there. | Use the full `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh add <name>'` command. |
| 6 | LOW | `.gitignore:8` | Secret-ignore coverage is incomplete. | `.secrets/` contents and `*.pem` are ignored, but probes found no rule for a bare `.secrets`, `keys/`, `*.key`, or `id_ed25519`. | Add explicit ignore rules for those names/patterns. |
| 7 | LOW | `bench/pi_opening_request.json:6` | A captured prompt embeds an absolute home-directory path. | The exact commit candidate contains a generic working-directory path working-directory reference. | Replace it with a neutral placeholder. |
| 8 | LOW | `docs/CLIENTS.md:168` | Claimed 13 s / 22 s client-harness results are not backed by committed evidence. | No matching pi/opencode timing transcript exists under `results/raw/` or `results/evidence/`. | Commit a redacted verifier transcript or label these results as unarchived. |
| 9 | LOW | `README.md:54` | Review link targets `docs/review/`, which is not in the commit set. | The committed review files are under `docs/benchmarks/review/`; `docs/review/` is an empty untracked directory. | Point the link to `docs/benchmarks/review/`. |

Checked and fine:

- Exact commit set contains 277 non-ignored files; requested secret markers found only placeholders/generated patterns, not credentials or private-key blocks.
- `.env`, `.pod_env`, `.vercel`, and `apps/web/.env.local` are ignored; no protected environment file is in the commit set.
- Shell syntax, `authz.py` compilation, web TypeScript `--noEmit`, and ESLint passed.
- Pi fields and CLI flags are valid for installed pi 0.84.2; opencode 1.18.23 exposes the documented run/model flags.
- Generated `bench/service_tables.py` output exactly matches the Heretic tables in `docs/ARCHITECTURE.md`.
- Current benchmark docs explicitly mark the Cloudflare plan superseded and direct users to the reverse-SSH route.
- I did not run the client verifier or Playwright suite because both contact production.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| # | Verdict | What changed |
|---|---|---|
| 1 | Fixed | `scripts/edge.sh` validates the key against `^ssh-ed25519 <base64> [plain comment]$` on the Mac and sends it base64-encoded; `edge/install.sh` enforces the same pattern (it used to allow `.*`, so a newline). Rerun on the edge: `authorized_keys` byte-identical, PengePassportPH still 200 |
| 2 | Fixed | New `scripts/pod_connect.sh` reads the pod's address and SSH host keys through RunPod's authenticated proxy into `.pod_known_hosts`; `scripts/lib.sh` makes `pod.sh`, `push.sh`, `pull.sh`, `tunnel.sh` use it with `StrictHostKeyChecking=yes` |
| 3 | Fixed | `pod/start.sh` checks vLLM's health once more after the wait loop and stops before the gateway and tunnel if it is not healthy |
| 4 | Fixed | Confirmed in pi's source: `qwen-chat-template` sends `enable_thinking: !!reasoningEffort, preserve_thinking: true`. `docs/CLIENTS.md` now says off vs on, and that low/medium/high behave the same |
| 5 | Fixed | `docs/OPERATIONS.md` gives the full `scripts/pod.sh <<<'... keys.sh add <name>'` command |
| 6 | Fixed | `.gitignore` adds `.secrets`, `*.key`, `id_ed25519*`, `id_rsa*`, `.team_api_keys`, `.api_key`, `.env.*`, `.pod_known_hosts` |
| 7 | Fixed | `bench/pi_opening_request.json`: the captured working directory (a generic dev path) → `/path/to/project` |
| 8 | Fixed | `results/evidence/verify_clients_2026-09-28.txt`: the script's output at the time plus a re-check of both repos (tests pass, test file untouched, the diff each agent made); linked from `docs/CLIENTS.md` |
| 9 | Not a problem now | `docs/review/` holds this file; the link resolves |
