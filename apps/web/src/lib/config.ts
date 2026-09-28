// Shared by next.config.ts, server code and the browser bundle.
export const BASE_PATH = "/heretic-inference";
export const PUBLIC_HOST = "alphaexperiments.com";
export const PUBLIC_ORIGIN = `https://${PUBLIC_HOST}`;
/** The OpenAI-compatible API that pi, opencode and this app's server call. */
export const API_BASE_URL = `${PUBLIC_ORIGIN}${BASE_PATH}/v1`;
export const MODEL_ID = "qwen3.8-27b-heretic";
export const MODEL_NAME = "Qwen3.8-27B Heretic";
/** vLLM's --max-model-len on the pod. */
export const CONTEXT_TOKENS = 65536;
/** Longest answer in tokens. The chat route also ends an answer at 280 s (Vercel Hobby stops functions at 300 s). */
export const MAX_OUTPUT_TOKENS = 8192;
