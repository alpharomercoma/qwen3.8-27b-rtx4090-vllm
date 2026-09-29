"use client";

import { useActionState } from "react";
import { unlock, type UnlockState } from "@/app/actions";
import { Mark } from "./mark";

export function Login() {
  const [state, action, pending] = useActionState<UnlockState, FormData>(unlock, { error: null });
  return (
    <main className="flex min-h-full items-center justify-center px-4 py-16">
      <form action={action} className="w-full max-w-sm">
        <div className="flex items-center gap-3">
          <Mark size={36} />
          <div>
            <h1 className="text-xl font-semibold tracking-tight">Heretic</h1>
            <p className="text-sm text-muted">Qwen3.8-27B on the team&apos;s RTX 4090</p>
          </div>
        </div>
        <label htmlFor="password" className="mt-10 block text-sm font-medium">
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          autoFocus
          required
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "password-error" : undefined}
          className="mt-2 block w-full rounded-lg border border-line bg-surface px-3 py-2.5 text-base outline-none focus:border-accent focus-visible:outline-none focus:ring-2 focus:ring-accent/30"
        />
        {state.error && (
          <p id="password-error" role="alert" className="mt-2 text-sm text-danger">
            {state.error}
          </p>
        )}
        <button
          type="submit"
          disabled={pending}
          className="mt-4 w-full rounded-lg bg-accent px-4 py-2.5 text-base font-medium text-accent-ink transition-opacity hover:opacity-90 disabled:opacity-60"
        >
          {pending ? "Checking…" : "Unlock"}
        </button>
      </form>
    </main>
  );
}
