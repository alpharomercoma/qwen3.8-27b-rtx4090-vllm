"use client";

import { useEffect, useState } from "react";
import { BASE_PATH } from "@/lib/config";

type Status = { state: "checking" | "online" | "offline" | "unauthorized"; latencyMs?: number };

const LABEL: Record<Status["state"], string> = {
  checking: "Checking",
  online: "Online",
  offline: "Offline",
  unauthorized: "Rejected",
};

const HINT: Record<Status["state"], string> = {
  checking: "Checking the GPU server",
  online: "The GPU server answers",
  offline: "The GPU server does not answer; it may be restarting",
  unauthorized: "The GPU server rejected this app's credentials",
};

/** GPU server reachability, polled every 30 s while the tab is visible. */
export function StatusPill() {
  const [status, setStatus] = useState<Status>({ state: "checking" });

  useEffect(() => {
    let cancelled = false;
    const check = async () => {
      if (document.visibilityState !== "visible") return;
      try {
        const res = await fetch(`${BASE_PATH}/api/status`, { cache: "no-store" });
        if (res.status === 401) return window.location.reload(); // session ended
        const body = (await res.json()) as Status;
        if (!cancelled) setStatus(body);
      } catch {
        if (!cancelled) setStatus({ state: "offline" });
      }
    };
    void check();
    const timer = setInterval(check, 30_000);
    document.addEventListener("visibilitychange", check);
    return () => {
      cancelled = true;
      clearInterval(timer);
      document.removeEventListener("visibilitychange", check);
    };
  }, []);

  const color =
    status.state === "online" ? "bg-ok" : status.state === "checking" ? "bg-muted animate-pulse" : "bg-danger";
  const title = status.latencyMs !== undefined ? `${HINT[status.state]} (round trip ${status.latencyMs} ms)` : HINT[status.state];

  return (
    <span
      className="inline-flex shrink-0 items-center gap-2 whitespace-nowrap rounded-full border border-line px-2.5 py-1 text-xs text-muted"
      title={title}
      role="status"
      aria-label={title}
    >
      <span className={`size-2 rounded-full ${color}`} />
      <span className="hidden sm:inline">RTX 4090</span>
      <span className="text-ink">{LABEL[status.state]}</span>
      {status.state === "online" && status.latencyMs !== undefined && (
        <span className="hidden font-mono tabular-nums sm:inline">{status.latencyMs} ms</span>
      )}
    </span>
  );
}
