"use client";

import { ArrowUp, Brain, SlidersHorizontal, Square } from "lucide-react";
import { useEffect, useRef, useState } from "react";

type Props = {
  onSend: (text: string) => void;
  onStop: () => void;
  busy: boolean;
  thinking: boolean;
  onThinkingChange: (on: boolean) => void;
  system: string;
  onSystemChange: (text: string) => void;
  placeholder: string;
};

export function Composer({ onSend, onStop, busy, thinking, onThinkingChange, system, onSystemChange, placeholder }: Props) {
  const [text, setText] = useState("");
  const [instructionsOpen, setInstructionsOpen] = useState(false);
  const ref = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    // Desktop: type right away. Phones: do not pop the keyboard up uninvited.
    if (matchMedia("(pointer: fine)").matches) ref.current?.focus();
  }, []);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, window.innerHeight * 0.4)}px`;
  }, [text]);

  const canSend = text.trim().length > 0 && !busy;
  const submit = () => {
    if (!canSend) return;
    onSend(text.trim());
    setText("");
  };

  return (
    <div className="relative">
      {instructionsOpen && (
        <div className="absolute inset-x-0 bottom-full mb-2 rounded-2xl border border-line bg-surface p-3 shadow-lg">
          <label htmlFor="instructions" className="text-sm font-medium">
            Instructions for every answer
          </label>
          <p className="text-xs text-muted">Sent as the system prompt. Saved in this browser for all chats.</p>
          <textarea
            id="instructions"
            value={system}
            onChange={(e) => onSystemChange(e.target.value)}
            rows={4}
            maxLength={8000}
            placeholder="For example: Answer in Tagalog. Keep answers short."
            className="mt-2 w-full resize-y rounded-lg border border-line bg-paper p-2 text-sm outline-none focus:border-accent"
          />
          <div className="mt-2 flex justify-end gap-2">
            {system && (
              <button type="button" onClick={() => onSystemChange("")} className="rounded-lg px-3 py-1.5 text-sm text-muted hover:bg-sunken">
                Clear
              </button>
            )}
            <button
              type="button"
              onClick={() => setInstructionsOpen(false)}
              className="rounded-lg bg-accent px-3 py-1.5 text-sm font-medium text-accent-ink"
            >
              Done
            </button>
          </div>
        </div>
      )}
      <form
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
        className="rounded-2xl border border-line bg-surface shadow-[0_1px_2px_rgba(22,27,34,0.06)] focus-within:border-accent/60 focus-within:ring-2 focus-within:ring-accent/15"
      >
        <textarea
          ref={ref}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
              e.preventDefault();
              submit();
            }
          }}
          rows={1}
          placeholder={placeholder}
          aria-label="Message"
          className="block max-h-[40vh] w-full resize-none bg-transparent px-4 pt-3.5 pb-1 text-base outline-none focus-visible:outline-none placeholder:text-muted/80"
        />
        <div className="flex items-center gap-1.5 px-2.5 pb-2.5 pt-1">
          <button
            type="button"
            onClick={() => onThinkingChange(!thinking)}
            aria-pressed={thinking}
            title={thinking ? "The model reasons before answering. Slower, better on hard questions." : "Answers directly, faster."}
            className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-sm ${
              thinking ? "border-accent/40 bg-accent-soft text-accent" : "border-line text-muted hover:text-ink"
            }`}
          >
            <Brain size={15} />
            Think
          </button>
          <button
            type="button"
            onClick={() => setInstructionsOpen((o) => !o)}
            aria-expanded={instructionsOpen}
            className={`relative inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-sm ${
              system ? "border-accent/40 text-accent" : "border-line text-muted hover:text-ink"
            }`}
          >
            <SlidersHorizontal size={15} />
            Instructions
            {system && <span className="size-1.5 rounded-full bg-accent" aria-label="(set)" />}
          </button>
          <span className="ml-auto hidden text-xs text-muted sm:inline">Shift + Enter for a new line</span>
          {busy ? (
            <button
              type="button"
              onClick={onStop}
              className="ml-2 grid size-9 place-items-center rounded-full bg-ink text-surface"
              aria-label="Stop generating"
              title="Stop"
            >
              <Square size={14} fill="currentColor" />
            </button>
          ) : (
            <button
              type="submit"
              disabled={!canSend}
              className="ml-2 grid size-9 place-items-center rounded-full bg-accent text-accent-ink disabled:bg-sunken disabled:text-muted"
              aria-label="Send"
              title="Send"
            >
              <ArrowUp size={18} />
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
