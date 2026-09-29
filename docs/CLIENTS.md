# Using the model from pi, opencode, curl or code

The model server speaks the OpenAI chat-completions API. Anything that lets you set a base URL and an API key works.

The GPU serves one of two models at a time, chosen on the pod ([OPERATIONS.md → Switch model](OPERATIONS.md#switch-model)):

| Model id | What it is |
|---|---|
| `qwen3.8-27b-heretic` | The official Heretic abliteration of Qwen3.8-27B: answers requests the original refuses. The default |
| `qwen3.8-27b` | Qwen3.8-27B as Qwen released it (Red Hat's 4-bit build) |

The configs below list both, so they keep working after a switch; only the model being served answers (the other
returns 404). `curl .../v1/models` (step 1) or the web app's status pill shows which one is live.

| Setting | Value |
|---|---|
| Base URL | `https://alphaexperiments.com/heretic-inference/v1` |
| Model id | the one being served (see above) |
| API key | a team key (see step 1). Sent as `Authorization: Bearer <key>` |
| Context | 65,536 tokens per request (prompt + answer) |
| Thinking | on by default. Off: send `"chat_template_kwargs": {"enable_thinking": false}` |
| Reasoning text | returned separately, in the `reasoning` field (streaming: `delta.reasoning`) |
| Tools | OpenAI-style tool calling works |

Every command below is a single line, so pasting it into a terminal cannot break it. The setup commands (with both
models) were tested on 2026-09-29 with pi 0.87.1 and opencode 1.18.23, with and without an existing config file: both
tools then list both models. The end-to-end coding test under [Verified](#verified) ran on 2026-09-28 with that day's
single-model config.

## 1. Get an API key

Whoever runs the GPU pod creates one per person (so one can be revoked without locking everyone out):

```bash
cd ~/4090 && scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh add alice'
```

It prints `sk-heretic-...` once. Send it privately. `keys.sh list` shows labels, `keys.sh revoke alice` removes one.

Put your key in your shell profile (zsh on macOS; use `~/.bashrc` for bash). Never put it in a repo or a config file.

```bash
echo 'export HERETIC_API_KEY=sk-heretic-PASTE-YOUR-KEY-HERE' >> ~/.zshrc && source ~/.zshrc
```

Check it (prints a JSON list with the model being served, e.g. `qwen3.8-27b-heretic`):

```bash
curl -s https://alphaexperiments.com/heretic-inference/v1/models -H "Authorization: Bearer $HERETIC_API_KEY"
```

## 2. pi

pi keeps custom providers in `~/.pi/agent/models.json`. These steps add a provider called `heretic` (the service) with
both models, and leave any providers you already have alone. They need `jq` (built into macOS 15+; `apt install jq` on Linux).

**2a.** Make sure the config file exists:

```bash
mkdir -p ~/.pi/agent && [ -f ~/.pi/agent/models.json ] || echo '{"providers":{}}' > ~/.pi/agent/models.json
```

**2b.** Back it up:

```bash
cp ~/.pi/agent/models.json ~/.pi/agent/models.json.bak
```

**2c.** Add the provider:

```bash
jq '.providers.heretic = {"baseUrl":"https://alphaexperiments.com/heretic-inference/v1","api":"openai-completions","apiKey":"$HERETIC_API_KEY","compat":{"supportsDeveloperRole":false,"supportsReasoningEffort":false,"thinkingFormat":"qwen-chat-template","maxTokensField":"max_tokens"},"models":[{"id":"qwen3.8-27b-heretic","name":"Qwen3.8-27B Heretic","reasoning":true,"input":["text"],"contextWindow":65536,"maxTokens":16384,"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0}},{"id":"qwen3.8-27b","name":"Qwen3.8-27B","reasoning":true,"input":["text"],"contextWindow":65536,"maxTokens":16384,"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0}}]}' ~/.pi/agent/models.json > ~/.pi/agent/models.json.tmp && mv ~/.pi/agent/models.json.tmp ~/.pi/agent/models.json
```

**2d.** Check that pi sees it:

```bash
pi --list-models | grep heretic
```

Expected, one line per model:

```
heretic  qwen3.8-27b          65.5K  16.4K  yes  no
heretic  qwen3.8-27b-heretic  65.5K  16.4K  yes  no
```

**2e.** Use the model being served:

```bash
pi --model heretic/qwen3.8-27b-heretic
```

- If the pod serves the original, use `heretic/qwen3.8-27b` instead. Inside pi, `/model` switches between them.
- `--thinking off` answers directly (fastest). Any other level (`low`, `medium`, `high`) turns thinking on, and they all
  behave the same: this setup sends only `enable_thinking: true/false`, because the model has no effort levels.
- One-shot: `pi -p --model heretic/qwen3.8-27b-heretic "explain this repo"`.
- Asked the model that is not being served, pi shows a 404 (`The model ... does not exist`): switch with `/model`.
- Make it the default: add `"defaultProvider": "heretic", "defaultModel": "qwen3.8-27b-heretic"` to `~/.pi/agent/settings.json`.
- Undo: `mv ~/.pi/agent/models.json.bak ~/.pi/agent/models.json`.

What each field does:

| Field | Value | Why |
|---|---|---|
| `baseUrl` | `https://alphaexperiments.com/heretic-inference/v1` | The public API |
| `api` | `openai-completions` | The OpenAI chat-completions wire format vLLM serves |
| `apiKey` | `$HERETIC_API_KEY` | Literally this text: pi reads the key from your environment, so the key never sits in the file |
| `compat.thinkingFormat` | `qwen-chat-template` | **Required.** pi then sends `chat_template_kwargs: {enable_thinking, preserve_thinking}`, the switch Qwen's template reads (`off` → false, any other level → true). vLLM ignores a top-level `enable_thinking`, so without this `--thinking off` does nothing |
| `compat.supportsDeveloperRole` | `false` | Qwen's chat template has no `developer` role; pi sends the system prompt as `system` |
| `compat.supportsReasoningEffort` | `false` | vLLM does not take `reasoning_effort` for this model |
| `compat.maxTokensField` | `max_tokens` | The field vLLM reads for the answer length |
| `models[].id` | `qwen3.8-27b-heretic`, `qwen3.8-27b` | The names vLLM serves each model under (`pod/models.sh`) |
| `reasoning` | `true` | Lets pi show thinking and offer thinking levels |
| `contextWindow` | `65536` | The server's per-request limit; pi compacts the session before reaching it |
| `maxTokens` | `16384` | Longest answer pi asks for |
| `cost` | all `0` | Self-hosted: nothing to bill |

## 3. opencode

opencode reads `~/.config/opencode/opencode.json`. Same pattern: create if missing, back up, add the provider.
If your file is `opencode.jsonc` or has comments, add the `provider.heretic` block by hand instead (jq cannot read comments).

```bash
mkdir -p ~/.config/opencode && [ -f ~/.config/opencode/opencode.json ] || echo '{"$schema":"https://opencode.ai/config.json"}' > ~/.config/opencode/opencode.json
```

```bash
cp ~/.config/opencode/opencode.json ~/.config/opencode/opencode.json.bak
```

```bash
jq '.provider.heretic = {"npm":"@ai-sdk/openai-compatible","name":"Heretic (team RTX 4090)","options":{"baseURL":"https://alphaexperiments.com/heretic-inference/v1","apiKey":"{env:HERETIC_API_KEY}"},"models":{"qwen3.8-27b-heretic":{"name":"Qwen3.8-27B Heretic","limit":{"context":65536,"output":16384}},"qwen3.8-27b":{"name":"Qwen3.8-27B","limit":{"context":65536,"output":16384}}}}' ~/.config/opencode/opencode.json > ~/.config/opencode/opencode.json.tmp && mv ~/.config/opencode/opencode.json.tmp ~/.config/opencode/opencode.json
```

Check: `opencode models heretic` prints `heretic/qwen3.8-27b-heretic` and `heretic/qwen3.8-27b`. Pick the one being
served with `/models` in the TUI, or `opencode run -m heretic/qwen3.8-27b-heretic "..."`. `{env:HERETIC_API_KEY}` is opencode's syntax for reading the key
from your environment.

## 4. curl

```bash
curl https://alphaexperiments.com/heretic-inference/v1/chat/completions -H "Authorization: Bearer $HERETIC_API_KEY" -H "Content-Type: application/json" -d '{"model": "qwen3.8-27b-heretic", "messages": [{"role": "user", "content": "Hello"}]}'
```

Use `"model": "qwen3.8-27b"` when the original is served. Streaming: add `"stream": true`. No thinking: add
`"chat_template_kwargs": {"enable_thinking": false}`.

## 5. Python (OpenAI SDK)

```python
import os
from openai import OpenAI

client = OpenAI(base_url="https://alphaexperiments.com/heretic-inference/v1", api_key=os.environ["HERETIC_API_KEY"])
reply = client.chat.completions.create(
    model="qwen3.8-27b-heretic",  # or "qwen3.8-27b" when the original is served
    messages=[{"role": "user", "content": "Hello"}],
    extra_body={"chat_template_kwargs": {"enable_thinking": False}},  # omit to let it think
)
print(reply.choices[0].message.content)
```

## 6. TypeScript (AI SDK)

```ts
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { generateText } from "ai";

const heretic = createOpenAICompatible({
  name: "heretic",
  baseURL: "https://alphaexperiments.com/heretic-inference/v1",
  apiKey: process.env.HERETIC_API_KEY,
});
// or "qwen3.8-27b" when the original is served
const { text } = await generateText({ model: heretic.chatModel("qwen3.8-27b-heretic"), prompt: "Hello" });
```

Reasoning arrives as reasoning parts; `providerOptions: { heretic: { chat_template_kwargs: { enable_thinking: false } } }`
turns it off (this is what the web app does).

## Verified

`scripts/verify_clients.sh` gives pi and opencode an isolated copy of the configs above and a small bug-fix task
(two bugs, a unit test they must not edit), through the public URL, on whichever model is being served. Evidence, including the code change each agent
made: `results/evidence/verify_clients_2026-09-28.txt`.

| Harness | Version | Result (2026-09-28, Heretic model, single-model config of that day) |
|---|---|---|
| pi | 0.84.2 | pass in 13 s, 5 tool calls |
| opencode | 1.18.23 | pass in 22 s, 5 tool uses |

## Errors

| You see | Meaning | Fix |
|---|---|---|
| 401 `Missing API key` | No `Authorization` header | `echo $HERETIC_API_KEY` is empty: redo step 1, open a new terminal |
| 401 `Invalid API key` | Wrong or revoked key | Ask for a new one |
| 404 `The model ... does not exist` | That model is not the one being served | Use the other id (`curl .../v1/models` shows the live one) |
| 404 `not found` | Path outside `/v1/*` | Check the base URL ends in `/v1` |
| 502 | GPU pod or its tunnel is down | Whoever runs the pod: [OPERATIONS.md → Start](OPERATIONS.md#start-stop-restart) |
| 400 `maximum context length` | Prompt + answer over 65,536 tokens | Start a new session or let the harness compact |
| pi: `Model ... not found` | Provider not in `models.json` | Redo 2c, then 2d |
| Slow first token | Other requests ahead in the GPU queue (16 run at once), or a long uncached prompt | Normal under load; see [ARCHITECTURE.md](ARCHITECTURE.md#performance) |
