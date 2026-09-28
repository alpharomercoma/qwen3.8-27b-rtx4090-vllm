import type { UIMessage } from "ai";

/** Timings measured on the server (Vercel function) for one answer. */
export type AnswerMetadata = {
  createdAt?: number;
  /** Request start to first token (queueing on the GPU included). */
  ttftMs?: number;
  /** First to last reasoning token. */
  reasoningMs?: number;
  /** Output tokens per second after the first token. */
  tokensPerSecond?: number;
  inputTokens?: number;
  cachedInputTokens?: number;
  outputTokens?: number;
  finishReason?: string;
};

export type ChatMessage = UIMessage<AnswerMetadata>;

/** Per-request options the browser sends next to the messages. */
export type ChatRequestOptions = {
  thinking: boolean;
  system: string;
};
