import { describeModel, type ServedModel } from "@/lib/config";
import { fetchModels } from "@/lib/inference";
import { isUnlocked } from "@/lib/session";

export const dynamic = "force-dynamic";

export type ServerStatus = {
  state: "online" | "offline" | "unauthorized";
  latencyMs?: number;
  /** The model the pod serves right now. */
  model?: ServedModel;
};

/** Round trip to the GPU pod through the same path chat requests take, and which model it serves. */
export async function GET() {
  if (!(await isUnlocked())) return Response.json({ error: "Enter the password first." }, { status: 401 });
  const started = performance.now();
  let status: ServerStatus;
  try {
    const { status: code, ids } = await fetchModels();
    const latencyMs = Math.round(performance.now() - started);
    const pinned = process.env.INFERENCE_MODEL;
    const id = pinned ? ids.find((m) => m === pinned) : ids[0];
    if (code === 401 || code === 403) status = { state: "unauthorized", latencyMs };
    else if (!id) status = { state: "offline", latencyMs };
    else status = { state: "online", latencyMs, model: describeModel(id) };
  } catch {
    status = { state: "offline" };
  }
  return Response.json(status, { headers: { "Cache-Control": "no-store" } });
}
