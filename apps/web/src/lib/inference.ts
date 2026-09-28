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

export async function inferenceHeaders(): Promise<HeadersInit> {
  return { Authorization: `Bearer ${await bearerToken()}` };
}
