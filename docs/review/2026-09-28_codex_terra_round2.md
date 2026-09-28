# Codex QA, round 2: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Round-1 # | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| 1 | FIXED | `POD_PUBKEY` is locally validated and base64-transferred; edge revalidates it. |
| 2 | PARTLY | Direct pod SSH now pins keys strictly, but the first RunPod proxy connection still uses `StrictHostKeyChecking=accept-new`. |
| 3 | FIXED | A mandatory final vLLM health check prevents gateway/tunnel startup when vLLM never becomes healthy. |
| 4 | FIXED | Pi explanation correctly describes off versus enabled thinking. |
| 5 | FIXED | The operations command now uses `scripts/pod.sh` with the full pod path. |
| 6 | PARTLY | New secret/key patterns are ignored, but `keys/` itself is still not ignored. |
| 7 | FIXED | Captured prompt uses `/path/to/project`. |
| 8 | FIXED | Committed verifier evidence supports the 13 s / 22 s claims. |
| 9 | FIXED | `docs/review/` is in the commit set and the README link resolves. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | MED | `docs/DEPLOY.md:91` | The fresh-production deployment command sets the web credential to the publicly documented literal `the-password` if pasted. | `APP_PASSWORD` gates access in `session.ts`; every repo reader knows this exact value. | Prompt securely for a chosen password, or use an explicit non-copyable placeholder and require replacement. |
| 2 | MED | `pod/start.sh:5,26-28` | Gateway failure can still lead to tunnel startup and a misleading “up” message. | The script has no `errexit`; `gateway/run.sh` can return nonzero when authz/Caddy fails its listener checks. | Use `set -euo pipefail` or explicitly stop on gateway/tunnel failure. |
| 3 | LOW | `pod/gateway/keys.sh:14,19` | Claimed atomic key updates are not guaranteed. | `mktemp` defaults to `/tmp`, while `/workspace` is the mounted volume; cross-device `mv` falls back to copy/delete, allowing transient missing/partial key files. | Create temporary files in `/workspace`, e.g. `mktemp "${F}.tmp.XXXXXX"`. |
| 4 | LOW | `scripts/verify_clients.sh:87-91` | An unknown harness argument exits zero without running any check. | `case` has no default branch; `scripts/verify_clients.sh typo` prints a log path and succeeds. | Add `*) echo usage >&2; exit 2 ;;`. |
| 5 | MED | `docs/ARCHITECTURE.md:99-105`; `docs/benchmarks/REPORT.md:340` | Performance prose understates the recorded worst public first-token wait. | The report says 60.4 s, but `vllm_heretic-public_team_20260928-150410.summary.json` records `ttft_max_s` 85.157 s for the 3+3+3+3 run. | State the 85.2 s observed maximum, or clearly scope 60.4 s to the older non-Heretic run. |

Checked and fine:

- No committed file matched the long-form secret, JWT, GitHub/Hugging Face token, or private-key patterns; the only credential-like strings are placeholders, generators, or redacted evidence.
- No actual personal home path remains; the round-one review merely describes the removed generic working-directory path.
- `.env`, `.pod_env`, `.vercel`, `apps/web/.env.local`, `.secrets`, `*.key`, PEM files, and SSH private-key names are ignored. `keys/` is the exception above.
- `authz.env` has all required nonempty OIDC settings and matches the documented issuer/audience/project/environment shape without exposing its values.
- Pi configuration fields are valid in installed Pi 0.87.1; opencode 1.18.23 supports the documented model/run flags and config pattern.
- Shell syntax, ShellCheck, Python AST parsing, web TypeScript, and ESLint passed.
- Generated service tables match the architecture tables; the KV-pool and partial-stress numbers match committed evidence.
- Benchmark docs mark Cloudflare Tunnel as superseded and direct users to reverse SSH.
- No production requests, client verifier, or Playwright tests were run.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| Round-1 #2 (proxy first use) | Fixed | RunPod's proxy host key is pinned in `scripts/runpod_known_hosts` (RSA 4096, `SHA256:eYprmeBVqJ5hik4sEtaEbsrBsY0LBcNCGgJzj2v1KVI`; the key recorded on this Mac before 2026-09-17 matched the live key on 2026-09-29). `pod_connect.sh` uses it with `StrictHostKeyChecking=yes` |
| Round-1 #6 (`keys/`) | Fixed | `keys/` added to `.gitignore` |
| New #1 (literal password) | Fixed | `docs/DEPLOY.md` reads the password with `read -rs` and pipes it to `vercel env add`; nothing to copy |
| New #2 (`start.sh` continues) | Fixed | Every step stops the script on failure (`fail`), including `gateway/run.sh` and `edge_tunnel.sh`; "up" prints only at the end |
| New #3 (non-atomic key writes) | Fixed | `keys.sh` creates its temp file next to the key file (`mktemp "$F.tmp.XXXXXX"`), sets mode 600 before the rename |
| New #4 (unknown argument) | Fixed | `verify_clients.sh` prints usage and exits 2 |
| New #5 (worst wait) | Fixed | `docs/ARCHITECTURE.md` states p90 40-60 s and the 85.2 s maximum (68.5 s on the pod); `REPORT.md` scopes 60.4 s to the RedHat run and points to the Heretic numbers |
| pi 0.87.1 | Checked | pi auto-updated during the session; the documented commands were re-run against 0.87.1 (fresh and existing config): both list `heretic/qwen3.8-27b-heretic` |
