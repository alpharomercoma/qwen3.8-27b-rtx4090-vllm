# apps/web: the chat UI

Next.js 16 (App Router) + AI SDK 7, deployed to Vercel as project `heretic-inference` (team `alpharomercoma-projects`,
functions in `sin1`). Served to users at https://alphaexperiments.com/heretic-inference: the domain's Caddy forwards
that path to `heretic-inference.vercel.app`, and the app is built with `basePath: "/heretic-inference"`.

| File | Job |
|---|---|
| `src/app/page.tsx` | Password page or chat, decided on the server from the session cookie |
| `src/app/actions.ts` | `unlock` / `lock` server actions |
| `src/app/api/chat/route.ts` | `streamText` to vLLM through `@ai-sdk/openai-compatible`; streams reasoning and per-answer timings |
| `src/app/api/status/route.ts` | Round trip to the GPU server for the status pill |
| `src/lib/inference.ts` | Auth to the GPU gateway: Vercel OIDC token on Vercel, `INFERENCE_API_KEY` locally |
| `src/lib/session.ts` | HMAC-signed session cookie |
| `src/lib/chat-store.ts` | Chats and settings in `localStorage` (nothing stored server-side) |
| `src/components/` | Sidebar, conversation, messages (Streamdown markdown, code, math), composer, terminal dialog |
| `e2e/` | Playwright checks against the live app |

## Environment

| Variable | Where | Value |
|---|---|---|
| `APP_PASSWORD` | Vercel (production) | the shared password |
| `SESSION_SECRET` | Vercel (production, sensitive) | 32+ random characters; changing it signs everyone out |
| `INFERENCE_API_KEY` | local only | a team key; on Vercel the OIDC token is used instead |
| `INFERENCE_BASE_URL` | optional | defaults to `https://alphaexperiments.com/heretic-inference/v1` |

## Run locally

```bash
npm install
# against the public API with a team key:
INFERENCE_API_KEY=$HERETIC_API_KEY APP_PASSWORD=changeme SESSION_SECRET=$(openssl rand -hex 24) npm run dev
# open http://localhost:3000/heretic-inference
```

## Deploy and check

```bash
vercel deploy --prod --scope alpharomercoma-projects
E2E_PASSWORD=... npm run e2e                  # Playwright against production (drives your installed Google Chrome)
E2E_PASSWORD=changeme E2E_BASE_URL=http://localhost:3000/heretic-inference npm run e2e   # against a local server
```
