"use client";

import { useServerStatus, type Status } from "./server-status";

const LABEL: Record<Status["state"], string> = {
  checking: "Checking",
  online: "Online",
  offline: "Offline",
  unauthorized: "Rejected",
};

const HINT: Record<Status["state"], string> = {
  checking: "Checking the GPU server",
  online: "The GPU server answers",
  offline: "The GPU server does not answer; it may be stopped or restarting",
  unauthorized: "The GPU server rejected this app's credentials",
};

/** GPU server reachability and round trip, from the shared status poll. */
export function StatusPill() {
  const status = useServerStatus();
  const latencyMs = "latencyMs" in status ? status.latencyMs : undefined;
  const model = "model" in status ? status.model : undefined;
  const color =
    status.state === "online" ? "bg-ok" : status.state === "checking" ? "bg-muted animate-pulse" : "bg-danger";
  const hint = [HINT[status.state], model ? `serving ${model.id}` : "", latencyMs !== undefined ? `round trip ${latencyMs} ms` : ""]
    .filter(Boolean)
    .join(", ");

  return (
    <span
      className="inline-flex shrink-0 items-center gap-2 whitespace-nowrap rounded-full border border-line px-2.5 py-1 text-xs text-muted"
      title={hint}
      role="status"
      aria-label={hint}
    >
      <span className={`size-2 rounded-full ${color}`} />
      <span className="hidden sm:inline">RTX 4090</span>
      <span className="text-ink">{LABEL[status.state]}</span>
      {status.state === "online" && latencyMs !== undefined && (
        <span className="hidden font-mono tabular-nums sm:inline">{latencyMs} ms</span>
      )}
    </span>
  );
}
