import "server-only";
import { createHmac, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import { BASE_PATH } from "./config";

// The app is behind one shared password (APP_PASSWORD). Unlocking sets a signed cookie; the signing key includes
// the password, so changing APP_PASSWORD (or SESSION_SECRET) signs everyone out.
export const SESSION_COOKIE = "heretic_session";
const MAX_AGE_S = 60 * 60 * 24 * 30;

function signingKey(): string {
  const secret = process.env.SESSION_SECRET;
  const password = process.env.APP_PASSWORD;
  if (!secret || secret.length < 32) throw new Error("SESSION_SECRET must be set (32+ characters)");
  if (!password) throw new Error("APP_PASSWORD must be set");
  return `${secret}\u0000${password}`;
}

const sign = (payload: string) => createHmac("sha256", signingKey()).update(payload).digest("base64url");

export function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

export function passwordMatches(candidate: string): boolean {
  const password = process.env.APP_PASSWORD;
  return !!password && safeEqual(candidate, password);
}

function newToken(): string {
  const payload = `v1.${Math.floor(Date.now() / 1000)}`;
  return `${payload}.${sign(payload)}`;
}

function tokenIsValid(token: string | undefined): boolean {
  if (!token) return false;
  const [version, issued, signature] = token.split(".");
  if (version !== "v1" || !issued || !signature) return false;
  const age = Date.now() / 1000 - Number(issued);
  if (!Number.isFinite(age) || age < -60 || age > MAX_AGE_S) return false;
  return safeEqual(sign(`${version}.${issued}`), signature);
}

export async function isUnlocked(): Promise<boolean> {
  return tokenIsValid((await cookies()).get(SESSION_COOKIE)?.value);
}

export async function startSession(): Promise<void> {
  (await cookies()).set(SESSION_COOKIE, newToken(), {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: BASE_PATH,
    maxAge: MAX_AGE_S,
  });
}

export async function endSession(): Promise<void> {
  (await cookies()).delete({ name: SESSION_COOKIE, path: BASE_PATH });
}
