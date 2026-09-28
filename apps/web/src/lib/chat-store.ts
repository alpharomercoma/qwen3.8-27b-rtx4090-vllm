"use client";

import type { ChatMessage, ChatRequestOptions } from "./types";

// Conversations live in this browser only (localStorage). The server keeps nothing.
export type StoredChat = {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  messages: ChatMessage[];
};

const CHATS_KEY = "heretic:chats:v1";
const SETTINGS_KEY = "heretic:settings:v1";
export const THEME_KEY = "heretic:theme";

export const DEFAULT_SETTINGS: ChatRequestOptions = { thinking: true, system: "" };

export function loadChats(): StoredChat[] {
  try {
    const raw = localStorage.getItem(CHATS_KEY);
    const chats = raw ? (JSON.parse(raw) as StoredChat[]) : [];
    return Array.isArray(chats) ? chats.sort((a, b) => b.updatedAt - a.updatedAt) : [];
  } catch {
    return [];
  }
}

/** Returns false when the browser refused the write (storage full or blocked). */
export function saveChats(chats: StoredChat[]): boolean {
  try {
    localStorage.setItem(CHATS_KEY, JSON.stringify(chats));
    return true;
  } catch {
    return false;
  }
}

export function loadSettings(): ChatRequestOptions {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    return raw ? { ...DEFAULT_SETTINGS, ...(JSON.parse(raw) as Partial<ChatRequestOptions>) } : DEFAULT_SETTINGS;
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function saveSettings(settings: ChatRequestOptions): void {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch {
    // settings are a convenience; ignore a refused write
  }
}

export function newChatId(): string {
  return crypto.randomUUID();
}

export function titleFor(messages: ChatMessage[]): string {
  const first = messages.find((m) => m.role === "user");
  const text = first?.parts.map((p) => (p.type === "text" ? p.text : "")).join(" ") ?? "";
  const oneLine = text.replace(/\s+/g, " ").trim();
  return oneLine.length > 60 ? `${oneLine.slice(0, 57)}…` : oneLine || "New chat";
}

/** Sidebar groups by last activity. */
export function groupLabel(ts: number, now = Date.now()): string {
  const day = (t: number) => new Date(t).setHours(0, 0, 0, 0);
  const diffDays = Math.round((day(now) - day(ts)) / 86_400_000);
  if (diffDays <= 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  if (diffDays < 7) return "Previous 7 days";
  if (diffDays < 30) return "Previous 30 days";
  return "Older";
}
