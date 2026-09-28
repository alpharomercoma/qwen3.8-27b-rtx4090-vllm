"use client";

import { Check, Copy, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { API_BASE_URL, CONTEXT_TOKENS, MODEL_ID, MODEL_NAME } from "@/lib/config";

// The same single-line commands as docs/CLIENTS.md: they add one provider and keep any others in the config file.
const PI_PROVIDER = {
  baseUrl: API_BASE_URL,
  api: "openai-completions",
  apiKey: "$HERETIC_API_KEY", // literal: pi reads the key from the environment
  compat: {
    supportsDeveloperRole: false,
    supportsReasoningEffort: false,
    thinkingFormat: "qwen-chat-template",
    maxTokensField: "max_tokens",
  },
  models: [
    {
      id: MODEL_ID,
      name: MODEL_NAME,
      reasoning: true,
      input: ["text"],
      contextWindow: CONTEXT_TOKENS,
      maxTokens: 16384,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    },
  ],
};

const OPENCODE_PROVIDER = {
  npm: "@ai-sdk/openai-compatible",
  name: "Heretic (team RTX 4090)",
  options: { baseURL: API_BASE_URL, apiKey: "{env:HERETIC_API_KEY}" },
  models: { [MODEL_ID]: { name: MODEL_NAME, limit: { context: CONTEXT_TOKENS, output: 16384 } } },
};

const PI_FILE = "~/.pi/agent/models.json";
const OC_FILE = "~/.config/opencode/opencode.json";

const KEY_STEP = "echo 'export HERETIC_API_KEY=sk-heretic-PASTE-YOUR-KEY-HERE' >> ~/.zshrc && source ~/.zshrc";

const PI_STEPS = [
  `mkdir -p ~/.pi/agent && [ -f ${PI_FILE} ] || echo '{"providers":{}}' > ${PI_FILE}`,
  `cp ${PI_FILE} ${PI_FILE}.bak`,
  `jq '.providers.heretic = ${JSON.stringify(PI_PROVIDER)}' ${PI_FILE} > ${PI_FILE}.tmp && mv ${PI_FILE}.tmp ${PI_FILE}`,
  `pi --model heretic/${MODEL_ID}`,
].join("\n");

const OPENCODE_STEPS = [
  `mkdir -p ~/.config/opencode && [ -f ${OC_FILE} ] || echo '{"$schema":"https://opencode.ai/config.json"}' > ${OC_FILE}`,
  `cp ${OC_FILE} ${OC_FILE}.bak`,
  `jq '.provider.heretic = ${JSON.stringify(OPENCODE_PROVIDER)}' ${OC_FILE} > ${OC_FILE}.tmp && mv ${OC_FILE}.tmp ${OC_FILE}`,
  `opencode run -m heretic/${MODEL_ID} "hello"`,
].join("\n");

const CURL = `curl ${API_BASE_URL}/chat/completions -H "Authorization: Bearer $HERETIC_API_KEY" -H "Content-Type: application/json" -d '{"model": "${MODEL_ID}", "messages": [{"role": "user", "content": "Hello"}]}'`;

export function ApiAccessDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(e) => e.target === ref.current && onClose()}
      className="m-auto w-[min(44rem,calc(100vw-2rem))] rounded-2xl border border-line bg-surface p-0 text-ink shadow-2xl backdrop:bg-black/40"
      aria-labelledby="api-title"
    >
      <div className="max-h-[85dvh] overflow-y-auto p-5 sm:p-6">
        <div className="flex items-start gap-3">
          <div>
            <h2 id="api-title" className="text-lg font-semibold">
              Use the model from the terminal
            </h2>
            <p className="mt-1 text-sm text-muted">
              Any OpenAI-compatible client works. Ask the team for an API key. Each line below is one command; the
              config steps add this model and keep your other providers.
            </p>
          </div>
          <button type="button" onClick={onClose} className="ml-auto rounded-lg p-1.5 text-muted hover:bg-sunken hover:text-ink" aria-label="Close">
            <X size={18} />
          </button>
        </div>
        <dl className="mt-5 grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
          <dt className="text-muted">Base URL</dt>
          <dd className="break-all font-mono">{API_BASE_URL}</dd>
          <dt className="text-muted">Model</dt>
          <dd className="font-mono">{MODEL_ID}</dd>
          <dt className="text-muted">Context</dt>
          <dd>{CONTEXT_TOKENS.toLocaleString("en-US")} tokens per request</dd>
        </dl>
        <Snippet title="1. Your key" code={KEY_STEP} hint="Replace the placeholder with your key. Use ~/.bashrc if your shell is bash." />
        <Snippet title="2. pi" code={PI_STEPS} hint="Creates the config if missing, backs it up, adds the provider, starts pi. Needs jq." />
        <Snippet title="2. opencode" code={OPENCODE_STEPS} hint="Same steps for opencode. In the TUI, pick the model with /models." />
        <Snippet title="Or plain curl" code={CURL} />
      </div>
    </dialog>
  );
}

function Snippet({ title, code, hint }: { title: string; code: string; hint?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <section className="mt-6">
      <div className="flex items-baseline gap-2">
        <h3 className="text-sm font-semibold">{title}</h3>
        <button
          type="button"
          onClick={async () => {
            await navigator.clipboard.writeText(code);
            setCopied(true);
            setTimeout(() => setCopied(false), 1500);
          }}
          className="ml-auto inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs text-muted hover:bg-sunken hover:text-ink"
        >
          {copied ? <Check size={13} /> : <Copy size={13} />}
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
      <pre className="mt-2 max-h-72 overflow-auto whitespace-pre-wrap break-all rounded-lg bg-sunken p-3 font-mono text-xs leading-relaxed">
        {code}
      </pre>
      {hint && <p className="mt-1.5 text-xs text-muted">{hint}</p>}
    </section>
  );
}
