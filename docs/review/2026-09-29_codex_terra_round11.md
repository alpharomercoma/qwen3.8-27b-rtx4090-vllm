# Codex QA, round 11: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

No new verified defects. The current commit set is ready to push.

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1–#9 | FIXED | Key transfer validation, SSH pinning, health gate, Pi wording, commands, ignores, evidence, and review link verify. |
| round-2 #1–#5 | FIXED | zsh-safe password prompt, failure gates, atomic key writes, verifier handling, and performance scope verify. |
| round-3 #1–#5 | FIXED | Merge commands, download marker, public-401 readiness check, and Operations commands verify. |
| round-4 #1 | PARTLY | Direct artifacts are hash-verified; TLS-only Python dependency resolution remains the documented accepted limitation. |
| round-4 #2 | NOT FIXED | Password-attempt limiting is absent, but explicitly Accepted and documented. |
| round-4 #3 | FIXED | RSA, Ed25519, ECDSA, and DSA private-key-name ignores work. |
| round-5 #1–#2 and locator | FIXED | Bootstrap gate/directories, 280-second chat cutoff, incomplete-answer UI, and E2E locator verify. |
| round-6 #1–#2 | FIXED | Immutable model revision/manifest and committed network evidence verify. |
| round-7 #1 | FIXED | The 15-minute first-byte limit is configured and documented. |
| round-8 #1–#2 | FIXED | SSH `Match all`, fresh-start timeout, and workspace directory handling verify. |
| round-9 #1 | FIXED | Review-path scrubbing removed actual personal home paths. |
| round-10 #1–#3 | FIXED | JWT/JWKS work is bounded and cached; `.envrc` is ignored; bootstrap is strict. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| — | — | — | No new verified findings. | Static review and local checks completed without production requests. | — |

Checked and fine:

- Exact commit boundary: 294 non-ignored untracked files; protected `.env`, `.pod_env`, app `.env.local`, `.vercel`, `.secrets`, `keys/`, `.envrc`, PEM/key files, and standard SSH private-key names are ignored.
- No concrete credential, JWT, private-key block, or actual personal-home-path pattern was found. `authz.env` has four expected nonempty public-identity assignments; values were not displayed.
- Pi 0.87.1 accepts every documented provider/compatibility field; its CLI and source support the documented model/thinking behavior. OpenCode 1.18.23 exposes the documented `models` and `run -m` forms.
- Deploy, Operations, root, pod, and edge instructions agree with code paths, flags, ordering, and service names.
- Shell syntax, gateway Python parsing, JSON parsing, web `tsc --noEmit`, and ESLint pass.
- `bench/service_tables.py` output exactly matches Architecture’s Heretic tables. Raw summaries confirm 68.462 s pod and 85.157 s public maxima; evidence supports KV, client-verifier, and network figures.
- Benchmark docs explicitly supersede Cloudflare Tunnel and direct readers to reverse SSH.
- No production request, Playwright run, or client verifier was run.

VERDICT: PASS

