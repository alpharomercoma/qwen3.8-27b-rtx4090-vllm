import "server-only";
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { getVercelOidcToken } from "@vercel/oidc";
import { API_BASE_URL } from "./config";

// How this server proves itself to the GPU pod's gateway:
// - on Vercel: a short-lived OIDC token that Vercel signs for this project and environment (no stored secret);
// - locally: INFERENCE_API_KEY, a normal team key.
async function bearerToken(): Promise<string> {
  return process.env.INFERENCE_API_KEY || (await getVercelOidcToken());
}

export const inferenceBaseUrl = () => process.env.INFERENCE_BASE_URL || API_BASE_URL;

export async function inferenceProvider() {
  return createOpenAICompatible({
    name: "heretic",
    baseURL: inferenceBaseUrl(),
    apiKey: await bearerToken(),
    includeUsage: true,
  });
}

// The pod serves one model at a time (pod/models.sh: heretic or original), so the app asks it which one instead of
// being configured separately. INFERENCE_MODEL pins a model id instead (then only that id counts as online).
let lastSeen: { id: string; at: number } | undefined;

/** GET /v1/models through the gateway. `ids` is empty when the server answered with an error status. */
export async function fetchModels(timeoutMs = 6000): Promise<{ status: number; ids: string[] }> {
  const res = await fetch(`${inferenceBaseUrl()}/models`, {
    headers: { Authorization: `Bearer ${await bearerToken()}` },
    signal: AbortSignal.timeout(timeoutMs),
    cache: "no-store",
  });
  if (!res.ok) return { status: res.status, ids: [] };
  const body = (await res.json()) as { data?: { id: string }[] };
  const ids = body.data?.map((m) => m.id) ?? [];
  if (ids[0]) lastSeen = { id: ids[0], at: Date.now() };
  return { status: res.status, ids };
}

/** After a 404 for a model id: the pod switched models, so ask again next time. */
export function forgetServedModel() {
  lastSeen = undefined;
}

/** The model id to send chat requests to: pinned, or what the pod served within the last minute, or asked now. */
export async function servedModelId(): Promise<string | undefined> {
  if (process.env.INFERENCE_MODEL) return process.env.INFERENCE_MODEL;
  if (lastSeen && Date.now() - lastSeen.at < 60_000) return lastSeen.id;
  return (await fetchModels()).ids[0];
}
