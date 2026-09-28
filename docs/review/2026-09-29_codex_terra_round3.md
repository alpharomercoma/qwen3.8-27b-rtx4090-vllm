# Codex QA, round 3: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1 | FIXED | Pod public key is validated locally/remotely and base64-transferred. |
| round-1 #2 | FIXED | RunPod proxy and direct pod SSH now use pinned known-host files with strict checking. |
| round-1 #3 | FIXED | `start.sh` requires final vLLM health before gateway startup. |
| round-1 #4 | FIXED | Pi docs correctly describe thinking as off versus enabled. |
| round-1 #5 | FIXED | Operations uses the full pod-wrapper command. |
| round-1 #6 | FIXED | Ignore coverage now includes key directories/names and secret patterns. |
| round-1 #7 | FIXED | Captured prompt uses a neutral path. |
| round-1 #8 | FIXED | Committed verifier evidence supports 13 s / 22 s claims. |
| round-1 #9 | FIXED | `docs/review/` is committed and linked correctly. |
| round-2 #1 | PARTLY | The public literal password is gone, but its replacement fails in the documented macOS zsh workflow. |
| round-2 #2 | FIXED | Gateway startup failure stops `start.sh` before tunnel startup. |
| round-2 #3 | FIXED | Key-file temporary files are created beside the target and atomically renamed. |
| round-2 #4 | FIXED | Unknown verifier selectors now exit 2. |
| round-2 #5 | FIXED | Heretic’s 85.2 s public maximum and 68.5 s pod maximum are stated accurately. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | MED | `docs/DEPLOY.md:91` | The fresh-deploy password command fails in default macOS zsh. | `read -rs -p` means “read from coprocess” in zsh; a local no-secret test returned `zsh:read: -p: no coprocess`, exit 1. | Use a shell-portable prompt: `printf 'Web password: ' >&2; IFS= read -rs PW; printf '\n' >&2`, then pipe `PW` to Vercel. |
| 2 | LOW | `apps/web/src/components/api-access.tsx:7-52` | The dialog copies complete Pi/OpenCode config roots, not merge commands. Pasting into an existing config replaces other providers. | Both snippets start with top-level `providers` / `provider`; unlike `CLIENTS.md`, the dialog gives no merge instruction. | Show the documented `jq` merge command or clearly label the JSON as a provider block to merge manually. |
| 3 | LOW | `pod/start.sh:20-21` | An interrupted model download may not recover on restart. | The sole completion test is existence of `model.safetensors.index.json`; no shard/completion validation occurs before skipping `fetch_model.sh`. | Write and check a completion marker only after successful download, or verify required snapshot files before skipping. |
| 4 | LOW | `pod/start.sh:33-34`; `pod/gateway/edge_tunnel.sh:18-24` | `start.sh` reports the public URL “up” when only the retry loop exists. | In documented order, the edge trusts the tunnel key only in step 4; `edge_tunnel.sh` returns success after starting its loop, regardless of SSH authentication/forward success. | Say that local services are started and step 4 is still required, or verify an established reverse forward before printing “up.” |
| 5 | LOW | `docs/OPERATIONS.md:39-41` | Key-management commands are not copyable as written. | Literal `... keys.sh …` is neither a shell command nor the documented wrapper. | Replace each with the full `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh …'` command. |

Checked and fine:

- No actual credentials, private keys, web password, or personal home paths were found in committed content. The key-like hit is an intentional paste placeholder; path hits are generic historical-review/scrubber references.
- Ignore rules cover `.env`, `.pod_env`, `.vercel`, `apps/web/.env.local`, `.secrets`, `keys/`, `*.key`, `*.pem`, SSH private-key names, and generated pod known-host state.
- Pi 0.87.1 recognizes the documented provider schema and Qwen compatibility behavior; installed OpenCode 1.18.23 supports the documented run/model flags. The verifier config and evidence agree.
- Shell parsing, Python AST parsing, web ESLint, and TypeScript checks passed without creating review artifacts.
- `bench/service_tables.py` output exactly matches the Heretic tables in `ARCHITECTURE.md`; raw summaries and evidence support the stated performance numbers.
- User-facing benchmark docs mark Cloudflare Tunnel superseded and direct users to reverse SSH.
- I did not run Playwright, client verification, curl, or any production request.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| Round-2 #1 / new #1 (zsh `read -p`) | Fixed | `docs/DEPLOY.md`: `printf 'Web password: ' >&2; IFS= read -rs PW; ...`. Tested in zsh and bash: the value arrives intact, including spaces |
| New #2 (dialog replaces configs) | Fixed | The web app's "Use from the terminal" dialog now shows the same single-line merge commands as `docs/CLIENTS.md`, generated from one provider object. `e2e/chat.spec.ts` asserts the dialog contains the documented `jq` lines verbatim; passes on a local build and on production (redeployed) |
| New #3 (half-downloaded model) | Fixed | `fetch_model.sh` removes and then writes `.download-complete` only after `hf download` succeeds; `start.sh` skips the download only when the marker exists (`hf download` resumes and verifies otherwise) |
| New #4 ("up" without a tunnel) | Fixed | `start.sh` calls the public `/v1/models` without a key and prints `up` only on the gateway's `401`; otherwise it stops with a message pointing at DEPLOY step 4. `docs/DEPLOY.md` says this is expected on a brand-new pod |
| New #5 (`... keys.sh`) | Fixed | `docs/OPERATIONS.md` spells out every key command in full |
