import { MODEL_ID } from "@/lib/config";
import { inferenceBaseUrl, inferenceHeaders } from "@/lib/inference";
import { isUnlocked } from "@/lib/session";

export const dynamic = "force-dynamic";

export type ServerStatus = { state: "online" | "offline" | "unauthorized"; latencyMs?: number };

/** Round trip to the GPU pod through the same path chat requests take. */
export async function GET() {
  if (!(await isUnlocked())) return Response.json({ error: "Enter the password first." }, { status: 401 });
  const started = performance.now();
  let status: ServerStatus;
  try {
    const res = await fetch(`${inferenceBaseUrl()}/models`, {
      headers: await inferenceHeaders(),
      signal: AbortSignal.timeout(6000),
      cache: "no-store",
    });
    const latencyMs = Math.round(performance.now() - started);
    if (res.status === 401 || res.status === 403) status = { state: "unauthorized", latencyMs };
    else if (!res.ok) status = { state: "offline", latencyMs };
    else {
      const models = (await res.json()) as { data?: { id: string }[] };
      status = { state: models.data?.some((m) => m.id === MODEL_ID) ? "online" : "offline", latencyMs };
    }
  } catch {
    status = { state: "offline" };
  }
  return Response.json(status, { headers: { "Cache-Control": "no-store" } });
}
