"use client";

import { code } from "@streamdown/code";
import { math } from "@streamdown/math";
import { Check, ChevronRight, Copy, Pencil, RotateCcw } from "lucide-react";
import { memo, useEffect, useRef, useState } from "react";
import { Streamdown } from "streamdown";
import type { ChatMessage } from "@/lib/types";

const plugins = { code, math };

const textOf = (message: ChatMessage) =>
  message.parts
    .map((p) => (p.type === "text" ? p.text : ""))
    .join("")
    .trim();

export function UserMessage({
  message,
  onEdit,
  editable,
}: {
  message: ChatMessage;
  onEdit: (text: string) => void;
  editable: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const text = textOf(message);

  if (editing) {
    return (
      <EditBox
        initial={text}
        onCancel={() => setEditing(false)}
        onSave={(t) => {
          setEditing(false);
          onEdit(t);
        }}
      />
    );
  }
  return (
    <div className="group flex flex-col items-end">
      <div className="max-w-[85%] whitespace-pre-wrap break-words rounded-2xl rounded-br-md bg-sunken px-4 py-2.5">{text}</div>
      <div className="mt-1 flex gap-0.5 opacity-0 transition-opacity focus-within:opacity-100 group-hover:opacity-100">
        <CopyButton text={text} />
        {editable && (
          <IconButton label="Edit message" onClick={() => setEditing(true)}>
            <Pencil size={15} />
          </IconButton>
        )}
      </div>
    </div>
  );
}

function EditBox({ initial, onCancel, onSave }: { initial: string; onCancel: () => void; onSave: (t: string) => void }) {
  const [value, setValue] = useState(initial);
  const ref = useRef<HTMLTextAreaElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.focus();
    el.setSelectionRange(el.value.length, el.value.length);
  }, []);
  return (
    <div className="ml-auto w-full max-w-[85%] rounded-2xl border border-accent/60 bg-surface p-2">
      <textarea
        ref={ref}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Escape") onCancel();
          if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing && value.trim()) {
            e.preventDefault();
            onSave(value.trim());
          }
        }}
        rows={Math.min(10, Math.max(2, value.split("\n").length))}
        aria-label="Edit message"
        className="w-full resize-none bg-transparent p-2 outline-none focus-visible:outline-none"
      />
      <div className="flex justify-end gap-2">
        <button type="button" onClick={onCancel} className="rounded-lg px-3 py-1.5 text-sm text-muted hover:bg-sunken">
          Cancel
        </button>
        <button
          type="button"
          disabled={!value.trim()}
          onClick={() => onSave(value.trim())}
          className="rounded-lg bg-accent px-3 py-1.5 text-sm font-medium text-accent-ink disabled:opacity-50"
        >
          Send
        </button>
      </div>
    </div>
  );
}

export const AssistantMessage = memo(function AssistantMessage({
  message,
  streaming,
  canRegenerate,
  onRegenerate,
}: {
  message: ChatMessage;
  streaming: boolean;
  canRegenerate: boolean;
  onRegenerate: () => void;
}) {
  const reasoning = message.parts
    .map((p) => (p.type === "reasoning" ? p.text : ""))
    .join("")
    .trim();
  const text = textOf(message);
  const meta = message.metadata;
  const stillThinking = streaming && !text;

  return (
    <div className="group">
      {reasoning && <Reasoning text={reasoning} active={stillThinking} durationMs={meta?.reasoningMs} />}
      {text && (
        <Streamdown className="answer" plugins={plugins} isAnimating={streaming} caret={streaming ? "block" : undefined}>
          {text}
        </Streamdown>
      )}
      {!streaming && !text && meta?.finishReason === "length" && (
        <p className="text-sm text-muted">The answer hit the length limit while still thinking. Ask again with Think off, or ask for less.</p>
      )}
      {!streaming && text && meta?.finishReason === "length" && (
        <p className="mt-2 text-sm text-muted">Stopped at the length limit.</p>
      )}
      {!streaming && (text || reasoning) && !meta?.finishReason && (
        <p className="mt-2 text-sm text-muted">Stopped before the end. Ask it to continue.</p>
      )}
      {!streaming && (text || reasoning) && (
        <div className="mt-2 flex flex-wrap items-center gap-x-1 gap-y-1">
          <CopyButton text={text} />
          {canRegenerate && (
            <IconButton label="Regenerate answer" onClick={onRegenerate}>
              <RotateCcw size={15} />
            </IconButton>
          )}
          <Telemetry meta={meta} />
        </div>
      )}
    </div>
  );
});

function Reasoning({ text, active, durationMs }: { text: string; active: boolean; durationMs?: number }) {
  const [open, setOpen] = useState(false);
  const shown = active || open;
  const label = active
    ? "Thinking"
    : durationMs !== undefined
      ? `Thought for ${durationMs < 10_000 ? (durationMs / 1000).toFixed(1) : Math.round(durationMs / 1000)} s`
      : "Thoughts";
  const scrollRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (active && scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [text, active]);

  return (
    <div className="mb-3">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={shown}
        className="inline-flex items-center gap-1 rounded-md py-0.5 text-sm text-muted hover:text-ink"
      >
        <ChevronRight size={15} className={`transition-transform ${shown ? "rotate-90" : ""}`} />
        <span className={active ? "animate-pulse" : ""}>{label}</span>
      </button>
      {shown && (
        <div
          ref={scrollRef}
          className="mt-1.5 max-h-64 overflow-y-auto whitespace-pre-wrap border-l-2 border-line pl-3 text-sm leading-relaxed text-muted"
        >
          {text}
        </div>
      )}
    </div>
  );
}

function Telemetry({ meta }: { meta: ChatMessage["metadata"] }) {
  if (!meta) return null;
  const items: { value: string; unit: string; title: string }[] = [];
  if (meta.ttftMs !== undefined)
    items.push({
      value: (meta.ttftMs / 1000).toFixed(1),
      unit: "s to first token",
      title: "From the request reaching our server to the first token, including any wait in the GPU queue",
    });
  if (meta.tokensPerSecond !== undefined)
    items.push({ value: `${meta.tokensPerSecond}`, unit: "tok/s", title: "Output speed after the first token" });
  if (meta.outputTokens !== undefined)
    items.push({
      value: meta.outputTokens.toLocaleString("en-US"),
      unit: "tokens",
      title:
        meta.inputTokens !== undefined
          ? `Prompt ${meta.inputTokens.toLocaleString("en-US")} tokens${
              meta.cachedInputTokens ? `, ${meta.cachedInputTokens.toLocaleString("en-US")} of them from cache` : ""
            }`
          : "Output tokens",
    });
  if (items.length === 0) return null;
  return (
    <ul className="ml-1 flex flex-wrap items-center gap-x-3 text-xs text-muted" aria-label="Answer statistics">
      {items.map((item) => (
        <li key={item.unit} title={item.title}>
          <span className="tabular-nums text-ink/80">{item.value}</span> {item.unit}
        </li>
      ))}
    </ul>
  );
}

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <IconButton
      label={copied ? "Copied" : "Copy"}
      onClick={async () => {
        await navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 1500);
      }}
    >
      {copied ? <Check size={15} /> : <Copy size={15} />}
    </IconButton>
  );
}

function IconButton({ label, onClick, children }: { label: string; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      title={label}
      className="rounded-md p-1.5 text-muted hover:bg-sunken hover:text-ink"
    >
      {children}
    </button>
  );
}
