# Codex QA, round 7: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1–#9 | FIXED | Key transfer validation/encoding, SSH pinning, health gate, pi wording, commands, ignores, neutral path, evidence, and review link all verify. |
| round-2 #1–#5 | FIXED | zsh password prompt, startup failure gates, atomic key writes, verifier usage error, and performance scoping verify. |
| round-3 #1–#5 | FIXED | Dialog merge commands, download marker, public 401 gate, and copyable operations commands verify. |
| round-4 #1 | PARTLY | Direct downloads are hash-verified; PyPI/PyTorch dependencies remain TLS-only as documented/accepted. |
| round-4 #2 | NOT FIXED | No password-attempt limiter; accepted and documented, so out of scope. |
| round-4 #3 | FIXED | RSA, Ed25519, ECDSA, and DSA private-key filename patterns are ignored. |
| round-5 #1–#2 and test locator | FIXED | Bootstrap gate checks prerequisites; chat has the 280 s abort/incomplete state; composer selector is exact. |
| round-6 #1–#2 | FIXED | Model is commit-pinned and manifest-checked; committed network evidence backs the network-path figures. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | LOW | `edge/heretic-inference.caddy:13-16`; `docs/ARCHITECTURE.md:102-103` | Documentation says there is no proxy timeout, and the Caddy comment says queued requests are never cut off, but the edge has a 15-minute upstream response-header timeout. | `response_header_timeout 15m` applies while waiting for the pod gateway’s response headers. It does not affect the recorded 85.2 s maximum, but it is a real limit. | Document the 15-minute limit and state that recorded waits were below it. |

Checked and fine:

- Exact pending commit set: 290 non-ignored files. Protected env paths are not commit candidates; `.vercel` contents, `.env`, `.pod_env`, app `.env.local`, `.secrets`, `keys/`, PEM/key files, and SSH private-key names are ignored.
- Redacted scans found no private-key block, GitHub/Hugging Face token, JWT, actual API key, web password, or actual personal home path. `sk-heretic` matches are explicit paste placeholders.
- `authz.env` was checked only for required public OIDC-field presence and format; no values were printed.
- Installed pi 0.87.1 supports the documented model/provider fields and interpolation; installed OpenCode 1.18.23 supports the documented model/run configuration. Vercel CLI 58.0.0 supports the deployment flags.
- Shell syntax, ShellCheck, Python AST parsing, web TypeScript no-emit, and ESLint all passed.
- `bench/service_tables.py` exactly reproduces the Heretic architecture tables; raw/evidence support the documented maxima, KV figures, client-verifier results, stress result, and network measurements.
- Benchmark docs explicitly mark Cloudflare Tunnel superseded and direct readers to reverse SSH.
- No production request, E2E run, or client-verifier run was performed. No files were modified.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| #1 (15-minute header timeout undocumented) | Fixed | The Caddy comment, `docs/ARCHITECTURE.md`, `docs/SECURITY.md` and `docs/benchmarks/REPORT.md` now state the edge waits up to 15 minutes for the first response bytes (longest measured wait: 85 s) and has no limit once streaming starts |
