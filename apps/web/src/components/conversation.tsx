"use client";

import { useChat } from "@ai-sdk/react";
import { DefaultChatTransport } from "ai";
import { ArrowDown, CircleAlert } from "lucide-react";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { BASE_PATH, MODEL_NAME } from "@/lib/config";
import type { ChatMessage, ChatRequestOptions } from "@/lib/types";
import { Composer } from "./composer";
import { Mark } from "./mark";
import { AssistantMessage, UserMessage } from "./message";

// Stateless, so one instance serves every chat. Settings travel with each request (see `options`).
const transport = new DefaultChatTransport<ChatMessage>({ api: `${BASE_PATH}/api/chat` });

type Props = {
  chatId: string;
  initialMessages: ChatMessage[];
  settings: ChatRequestOptions;
  onSettingsChange: (s: ChatRequestOptions) => void;
  onSave: (chatId: string, messages: ChatMessage[]) => void;
};

export function Conversation({ chatId, initialMessages, settings, onSettingsChange, onSave }: Props) {
  const { messages, sendMessage, status, stop, regenerate, error } = useChat<ChatMessage>({
    id: chatId,
    messages: initialMessages,
    transport,
    throttle: 40,
  });

  const busy = status === "submitted" || status === "streaming";
  const options = { body: { thinking: settings.thinking, system: settings.system } satisfies ChatRequestOptions };

  // Save when the conversation changed and settled, and once more if the chat is left mid-answer. Opening a chat
  // is not a change, so it keeps its place in the list.
  const savedSig = useRef(signature(initialMessages));
  useEffect(() => {
    const sig = signature(messages);
    if (status !== "streaming" && sig !== savedSig.current) {
      savedSig.current = sig;
      onSave(chatId, messages);
    }
  }, [chatId, messages, status, onSave]);
  const latest = useRef({ messages, stop, onSave });
  useEffect(() => {
    latest.current = { messages, stop, onSave };
  });
  useEffect(
    () => () => {
      const { messages: last, stop: stopNow, onSave: save } = latest.current;
      void stopNow();
      if (signature(last) !== savedSig.current) save(chatId, last);
    },
    [chatId],
  );

  // Follow the answer while the reader is at the bottom; offer a jump back otherwise.
  const scrollRef = useRef<HTMLDivElement>(null);
  const [atBottom, setAtBottom] = useState(true);
  const atBottomRef = useRef(true);
  const scrollToBottom = (smooth = false) => {
    const el = scrollRef.current;
    if (el) el.scrollTo({ top: el.scrollHeight, behavior: smooth ? "smooth" : "auto" });
  };
  useLayoutEffect(() => {
    if (atBottomRef.current) scrollToBottom();
  }, [messages, status]);

  const send = (text: string) => {
    atBottomRef.current = true;
    setAtBottom(true);
    void sendMessage({ text }, options);
    requestAnimationFrame(() => scrollToBottom(true));
  };

  const last = messages.at(-1);
  const lastUserIndex = messages.findLastIndex((m) => m.role === "user");
  const waiting = busy && (last?.role === "user" || (last?.role === "assistant" && last.parts.every((p) => p.type === "step-start")));

  const composer = (
    <Composer
      onSend={send}
      onStop={() => void stop()}
      busy={busy}
      thinking={settings.thinking}
      onThinkingChange={(thinking) => onSettingsChange({ ...settings, thinking })}
      system={settings.system}
      onSystemChange={(system) => onSettingsChange({ ...settings, system })}
    />
  );

  if (messages.length === 0) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center overflow-y-auto px-4 pb-[12vh]">
        <div className="w-full max-w-[46rem]">
          <div className="mb-8 flex flex-col items-center text-center">
            <Mark size={44} />
            <h2 className="mt-4 text-2xl font-semibold tracking-tight">{MODEL_NAME}</h2>
            <p className="mt-2 max-w-md text-[15px] text-muted">
              An uncensored Qwen3.8-27B running on the team&apos;s own RTX 4090. Chats are saved in this browser only.
            </p>
          </div>
          {composer}
        </div>
      </div>
    );
  }

  return (
    <>
      <div
        ref={scrollRef}
        onScroll={(e) => {
          const el = e.currentTarget;
          const bottom = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
          atBottomRef.current = bottom;
          setAtBottom(bottom);
        }}
        className="relative flex-1 overflow-y-auto"
      >
        <div className="mx-auto flex w-full max-w-[46rem] flex-col gap-7 px-4 pb-10 pt-4 md:px-6">
          {messages.map((m, i) =>
            m.role === "user" ? (
              <UserMessage
                key={m.id}
                message={m}
                editable={!busy}
                onEdit={(text) => void sendMessage({ text, messageId: m.id }, options)}
              />
            ) : (
              <AssistantMessage
                key={m.id}
                message={m}
                streaming={busy && i === messages.length - 1}
                canRegenerate={!busy && i === messages.length - 1 && i > lastUserIndex}
                onRegenerate={() => void regenerate(options)}
              />
            ),
          )}
          {waiting && <Waiting />}
          {error && !busy && (
            <div role="alert" className="flex items-start gap-3 rounded-xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm">
              <CircleAlert size={18} className="mt-0.5 shrink-0 text-danger" />
              <div>
                <p className="text-ink">{friendlyError(error)}</p>
                <button type="button" onClick={() => void regenerate(options)} className="mt-2 font-medium text-accent hover:underline">
                  Try again
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
      <div className="relative mx-auto w-full max-w-[46rem] px-3 pb-3 md:px-6 md:pb-5">
        {!atBottom && (
          <button
            type="button"
            onClick={() => scrollToBottom(true)}
            className="absolute -top-12 left-1/2 grid size-9 -translate-x-1/2 place-items-center rounded-full border border-line bg-surface text-muted shadow-md hover:text-ink"
            aria-label="Jump to the latest message"
          >
            <ArrowDown size={16} />
          </button>
        )}
        {composer}
      </div>
    </>
  );
}

/** Shown until the first token arrives: queueing behind other requests and reading a long prompt both happen here. */
function Waiting() {
  const [seconds, setSeconds] = useState(0);
  useEffect(() => {
    const started = Date.now();
    const timer = setInterval(() => setSeconds(Math.floor((Date.now() - started) / 1000)), 500);
    return () => clearInterval(timer);
  }, []);
  return (
    <div className="flex items-center gap-2 text-sm text-muted" role="status">
      <span className="flex gap-1" aria-hidden="true">
        {[0, 1, 2].map((i) => (
          <span key={i} className="size-1.5 animate-pulse rounded-full bg-accent" style={{ animationDelay: `${i * 150}ms` }} />
        ))}
      </span>
      {seconds < 5
        ? "Sending to the GPU"
        : `Waiting for the first token, ${seconds} s. Other people's requests and long chats take longer.`}
    </div>
  );
}

function signature(messages: ChatMessage[]): string {
  const last = messages.at(-1);
  return last ? `${messages.length}:${last.id}:${JSON.stringify(last.parts).length}:${JSON.stringify(last.metadata ?? null).length}` : "0";
}

function friendlyError(error: Error): string {
  const text = error.message || "";
  try {
    const parsed = JSON.parse(text) as { error?: string };
    if (parsed.error === "Enter the password first.") return "Your session ended. Reload the page and enter the password again.";
    if (parsed.error) return parsed.error;
  } catch {}
  if (/failed to fetch|network/i.test(text)) return "The connection dropped. Check your network and try again.";
  return text || "Something went wrong.";
}
