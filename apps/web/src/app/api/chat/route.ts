import {
  APICallError,
  convertToModelMessages,
  createUIMessageStreamResponse,
  streamText,
  toUIMessageStream,
} from "ai";
import { MAX_OUTPUT_TOKENS } from "@/lib/config";
import { forgetServedModel, inferenceProvider, servedModelId } from "@/lib/inference";
import { isUnlocked } from "@/lib/session";
import type { AnswerMetadata, ChatMessage, ChatRequestOptions } from "@/lib/types";

// Vercel Hobby stops a function at 300 s. Answers end cleanly a little earlier (the UI then says "Stopped before the
// end"); MAX_OUTPUT_TOKENS is the other limit, whichever comes first. The variable exists for tests.
export const maxDuration = 300;
const ANSWER_TIME_LIMIT_MS = Number(process.env.ANSWER_TIME_LIMIT_MS) || 280_000;

type Body = Partial<ChatRequestOptions> & { messages?: ChatMessage[] };

export async function POST(req: Request) {
  if (!(await isUnlocked())) {
    return Response.json({ error: "Enter the password first." }, { status: 401 });
  }
  const body = (await req.json().catch(() => null)) as Body | null;
  const messages = body?.messages;
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > 400) {
    return Response.json({ error: "Invalid conversation." }, { status: 400 });
  }
  const system = typeof body?.system === "string" ? body.system.trim().slice(0, 8000) : "";
  const thinking = body?.thinking !== false;

  const modelId = await servedModelId().catch(() => undefined);
  if (!modelId) {
    return Response.json({ error: "The model server is not reachable right now. It may be restarting." }, { status: 503 });
  }
  const provider = await inferenceProvider();
  const started = performance.now();
  let firstTokenAt: number | undefined;
  let lastTokenAt: number | undefined;
  let reasoningStartAt: number | undefined;
  let reasoningEndAt: number | undefined;

  const result = streamText({
    model: provider.chatModel(modelId),
    system: system || undefined,
    // Earlier turns' reasoning is dropped by Qwen's chat template anyway; not sending it saves upload and tokens.
    messages: await convertToModelMessages(
      messages.map((m) => ({ ...m, parts: m.parts.filter((p) => p.type !== "reasoning") })),
    ),
    maxOutputTokens: MAX_OUTPUT_TOKENS,
    // vLLM reads chat_template_kwargs from the request body; Qwen's template switches thinking with it.
    providerOptions: { heretic: { chat_template_kwargs: { enable_thinking: thinking } } },
    abortSignal: AbortSignal.any([req.signal, AbortSignal.timeout(ANSWER_TIME_LIMIT_MS)]),
  });

  return createUIMessageStreamResponse({
    stream: toUIMessageStream({
      stream: result.stream,
      originalMessages: messages,
      sendReasoning: true,
      messageMetadata: ({ part }): AnswerMetadata | undefined => {
        const now = performance.now();
        if (part.type === "start") return { createdAt: Date.now() };
        if (part.type === "reasoning-delta" || part.type === "text-delta") {
          firstTokenAt ??= now;
          lastTokenAt = now;
          if (part.type === "reasoning-delta") reasoningStartAt ??= now;
          else if (reasoningStartAt !== undefined) reasoningEndAt ??= now;
          return undefined;
        }
        if (part.type === "finish") {
          const usage = part.totalUsage;
          const decodeS = firstTokenAt !== undefined && lastTokenAt !== undefined ? (lastTokenAt - firstTokenAt) / 1000 : 0;
          const out = usage.outputTokens;
          return {
            ttftMs: firstTokenAt !== undefined ? Math.round(firstTokenAt - started) : undefined,
            reasoningMs:
              reasoningStartAt !== undefined ? Math.round((reasoningEndAt ?? lastTokenAt ?? now) - reasoningStartAt) : undefined,
            tokensPerSecond: out && decodeS > 0.2 ? Math.round((out - 1) / decodeS) : undefined,
            inputTokens: usage.inputTokens,
            cachedInputTokens: usage.inputTokenDetails?.cacheReadTokens,
            outputTokens: out,
            finishReason: part.finishReason,
          };
        }
        return undefined;
      },
      onError: describeError,
    }),
  });
}

function describeError(error: unknown): string {
  if (APICallError.isInstance(error)) {
    const status = error.statusCode;
    if (status === 401 || status === 403) return "The model server rejected this app's credentials.";
    if (status === 502 || status === 503 || status === 504) return "The model server is not reachable right now. It may be restarting.";
    if (status === 400) return `The model server refused the request: ${shortMessage(error.responseBody)}`;
    if (status === 404) {
      forgetServedModel();
      return "The GPU server has just switched models. Send the message again.";
    }
    if (status) return `The model server answered with HTTP ${status}.`;
  }
  const message = error instanceof Error ? error.message : String(error);
  if (/fetch failed|ECONNREFUSED|ENOTFOUND|ETIMEDOUT|socket/i.test(message)) {
    return "The model server is not reachable right now. It may be restarting.";
  }
  console.error("chat error", error);
  return "Something went wrong while generating the answer.";
}

function shortMessage(body: string | undefined): string {
  if (!body) return "no details";
  try {
    const parsed = JSON.parse(body) as { error?: { message?: string } | string; message?: string };
    const msg = typeof parsed.error === "string" ? parsed.error : parsed.error?.message ?? parsed.message;
    return (msg ?? body).slice(0, 300);
  } catch {
    return body.slice(0, 300);
  }
}
