"use server";

import { refresh } from "next/cache";
import { endSession, passwordMatches, startSession } from "@/lib/session";

export type UnlockState = { error: string | null };

export async function unlock(_prev: UnlockState, form: FormData): Promise<UnlockState> {
  const password = String(form.get("password") ?? "");
  if (!passwordMatches(password)) {
    await new Promise((r) => setTimeout(r, 600)); // slows guessing
    return { error: "That password is not right." };
  }
  await startSession();
  refresh();
  return { error: null };
}

export async function lock(): Promise<void> {
  await endSession();
  refresh();
}
