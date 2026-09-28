# Codex QA, round 8: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1–#9 | FIXED | Key transfer validation, SSH pinning, health gate, Pi wording, operations commands, ignores, neutral path, evidence, and review link verify. |
| round-2 #1–#5 | FIXED | zsh prompt, failure gates, atomic key writes, verifier usage error, and performance scoping verify. |
| round-3 #1–#5 | FIXED | Config merge commands, model marker, public-401 readiness gate, and copyable key commands verify. |
| round-4 #1 | PARTLY | Direct uv/vLLM/Caddy downloads are verified; PyPI/PyTorch dependencies remain TLS-only, as accepted and documented. |
| round-4 #2 | NOT FIXED | Password limiter remains absent; accepted and documented, therefore out of scope. |
| round-4 #3 | FIXED | RSA, Ed25519, ECDSA, and DSA private-key-name ignores work. |
| round-5 #1 | PARTLY | The gate checks tools, CUDA, and API key, but not `/workspace/bin`; a partially retained workspace can skip bootstrap then Caddy extraction fails because that directory is absent. |
| round-5 #2 and locator | FIXED | 280-second abort/incomplete-answer state and exact composer locator are present. |
| round-6 #1–#2 | FIXED | Model is commit-pinned, 22-file manifest is structurally valid, and network evidence is committed. |
| round-7 #1 | FIXED | The 15-minute first-byte limit is correctly documented. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | MED | `edge/sshd-heretic-tunnel.conf:3` | The `Match User` block never terminates. In an included `sshd_config.d` file, later main-config/drop-in directives remain conditional or can make `sshd -t` fail. | Local `sshd_config` manual: a Match block applies until another Match or end of the configuration; this file ends at line 15. | Append `Match all` after the tunnel settings, then validate against the target server’s full sshd config. |
| 2 | MED | `docs/DEPLOY.md:35`; `scripts/pod.sh:8` | Fresh deployment is documented as ~15 minutes, but the wrapper kills its SSH session after 600 seconds. README and Operations repeat the same wrapper. | `POD_TIMEOUT` defaults to 600; benchmark notes also record 8–13 minute vLLM readiness. | Use an explicit sufficiently long timeout for fresh startup (for example `POD_TIMEOUT=1800`) and correct the timing guidance. |

Checked and fine:

- Exact pending commit set: 291 files. No actual API key, JWT, private-key block, GitHub/Hugging Face token, web password, or personal home path found; matches are placeholders, evidence, or review text.
- Required ignore coverage works for env files, Vercel directories, secrets, key directories, PEM/key extensions, and common SSH private-key names. `authz.env` was format-checked only; no values were displayed.
- Pi 0.87.1’s installed docs support the documented provider schema and thinking compatibility; OpenCode 1.18.23 exposes the documented model/run flags, and committed verifier evidence supports the config.
- `api-access.tsx` uses merge commands matching `CLIENTS.md`; docs’ generated Heretic performance tables exactly match `service_tables.py` and raw summaries, including the 85.157 s public maximum.
- Benchmark docs mark Cloudflare Tunnel as superseded and direct users to reverse SSH.
- All shell scripts parse; Python parsing, TypeScript no-emit, and ESLint pass. No production request, E2E run, or client-verifier run was made. No files were modified.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| #1 (Match block not terminated) | Fixed (was not leaking in practice) | On the live edge (OpenSSH 10.0), `sshd -T` showed root's settings unaffected (`permitrootlogin without-password`, `passwordauthentication no`, `x11forwarding no`) and `UsePAM` from the main config accepted, so the block ended with the included file. `edge/sshd-heretic-tunnel.conf` now ends with an explicit `Match all` anyway; reinstalled, `sshd -t` passes, root and tunnel settings as before |
| #2 (600 s SSH timeout vs first start) | Fixed | Every documented `start.sh` call uses `POD_TIMEOUT=1800`; `docs/DEPLOY.md` explains the default and that rerunning resumes; first-run estimate is now 15-25 min |
| Round-5 #1 partly (`/workspace/bin`) | Fixed | `start.sh` creates `/workspace/logs`, `/workspace/bin` and `/workspace/models`; `gateway/run.sh` creates `/workspace/bin` before extracting Caddy |
