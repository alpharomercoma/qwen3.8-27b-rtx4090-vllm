"use client";

import { createContext, useContext, useEffect, useState } from "react";
import type { ServerStatus } from "@/app/api/status/route";
import { BASE_PATH } from "@/lib/config";

export type Status = { state: "checking" } | ServerStatus;

const StatusContext = createContext<Status>({ state: "checking" });

/** Polls /api/status every 30 s while the tab is visible: is the GPU server up, and which model does it serve. */
export function ServerStatusProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<Status>({ state: "checking" });

  useEffect(() => {
    let cancelled = false;
    const check = async () => {
      if (document.visibilityState !== "visible") return;
      try {
        const res = await fetch(`${BASE_PATH}/api/status`, { cache: "no-store" });
        if (res.status === 401) return window.location.reload(); // session ended
        const body = (await res.json()) as ServerStatus;
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

  return <StatusContext.Provider value={status}>{children}</StatusContext.Provider>;
}

export const useServerStatus = () => useContext(StatusContext);

/** The model the server reports right now; undefined unless it is online. Use this for anything actionable. */
export function useLiveModel() {
  const status = useServerStatus();
  return status.state === "online" ? status.model : undefined;
}

/** For labels only: the served model, or the last one seen while the server is briefly unreachable. */
export function useServedModel() {
  const status = useServerStatus();
  const [last, setLast] = useState<ServerStatus["model"]>();
  const current = "model" in status ? status.model : undefined;
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- remember the last model the server reported
    if (current) setLast(current);
  }, [current]);
  return current ?? last;
}
