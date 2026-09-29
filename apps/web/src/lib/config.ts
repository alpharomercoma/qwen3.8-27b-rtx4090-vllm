// Shared by next.config.ts, server code and the browser bundle.
export const BASE_PATH = "/heretic-inference";
export const PUBLIC_HOST = "alphaexperiments.com";
export const PUBLIC_ORIGIN = `https://${PUBLIC_HOST}`;
/** The OpenAI-compatible API that pi, opencode and this app's server call. */
export const API_BASE_URL = `${PUBLIC_ORIGIN}${BASE_PATH}/v1`;

/** What the UI says about each model the pod can serve (pod/models.sh). The app asks the pod which one is live. */
export const MODELS: Record<string, { name: string; description: string }> = {
  "qwen3.8-27b-heretic": {
    name: "Qwen3.8-27B Heretic",
    description: "The official Heretic abliteration of Qwen3.8-27B: it answers requests the original refuses.",
  },
  "qwen3.8-27b": {
    name: "Qwen3.8-27B",
    description: "Qwen3.8-27B as Qwen released it, in Red Hat's 4-bit build.",
  },
};
/** Name and description for a served model id; an id not listed above is shown as-is. */
export const describeModel = (id: string) => ({ id, ...(MODELS[id] ?? { name: id, description: "" }) });
export type ServedModel = ReturnType<typeof describeModel>;
/** vLLM's --max-model-len on the pod. */
export const CONTEXT_TOKENS = 65536;
/** Longest answer in tokens. The chat route also ends an answer at 280 s (Vercel Hobby stops functions at 300 s). */
export const MAX_OUTPUT_TOKENS = 8192;
