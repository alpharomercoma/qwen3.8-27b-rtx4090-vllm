"use client";

import { Menu } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  loadChats,
  loadSettings,
  newChatId,
  saveChats,
  saveSettings,
  titleFor,
  type StoredChat,
} from "@/lib/chat-store";
import { MODEL_NAME } from "@/lib/config";
import type { ChatMessage, ChatRequestOptions } from "@/lib/types";
import { Conversation } from "./conversation";
import { Sidebar } from "./sidebar";
import { StatusPill } from "./status-pill";

export function ChatApp() {
  const [chats, setChats] = useState<StoredChat[] | null>(null);
  // The open conversation. A brand-new chat has an id before it has a first message.
  const [chatId, setChatId] = useState<string>(() => newChatId());
  const [settings, setSettings] = useState<ChatRequestOptions | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [storageFull, setStorageFull] = useState(false);
  const chatsRef = useRef<StoredChat[]>([]);
  // A conversation saves once more when it closes; that save must not bring back a chat that was just deleted.
  const deletedRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    // localStorage is only readable after hydration
    const loaded = loadChats();
    chatsRef.current = loaded;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time load from browser storage
    setChats(loaded);
    setSettings(loadSettings());
  }, []);

  const commit = useCallback((next: StoredChat[]) => {
    chatsRef.current = next;
    setChats(next);
    setStorageFull(!saveChats(next));
  }, []);

  const saveMessages = useCallback(
    (id: string, messages: ChatMessage[]) => {
      if (messages.length === 0 || deletedRef.current.has(id)) return;
      const now = Date.now();
      const existing = chatsRef.current.find((c) => c.id === id);
      const updated: StoredChat = existing
        ? { ...existing, messages, updatedAt: now }
        : { id, title: titleFor(messages), createdAt: now, updatedAt: now, messages };
      commit([updated, ...chatsRef.current.filter((c) => c.id !== id)]);
    },
    [commit],
  );

  const updateSettings = useCallback((next: ChatRequestOptions) => {
    setSettings(next);
    saveSettings(next);
  }, []);

  const openChat = (id: string) => {
    setChatId(id);
    setDrawerOpen(false);
  };
  const startNewChat = () => openChat(newChatId());
  const deleteChat = (id: string) => {
    deletedRef.current.add(id);
    commit(chatsRef.current.filter((c) => c.id !== id));
    if (id === chatId) setChatId(newChatId());
  };
  const renameChat = (id: string, title: string) => {
    commit(chatsRef.current.map((c) => (c.id === id ? { ...c, title: title.trim() || c.title } : c)));
  };

  if (chats === null || settings === null) {
    return <div className="h-full bg-paper" aria-busy="true" />;
  }

  const active = chats.find((c) => c.id === chatId);

  return (
    <div className="flex h-dvh overflow-hidden bg-paper">
      <Sidebar
        chats={chats}
        activeId={chatId}
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        onNew={startNewChat}
        onSelect={openChat}
        onDelete={deleteChat}
        onRename={renameChat}
        storageFull={storageFull}
      />
      <main className="flex min-w-0 flex-1 flex-col bg-surface md:my-2 md:mr-2 md:rounded-2xl md:border md:border-line">
        <header className="flex h-14 shrink-0 items-center gap-2 px-3 md:px-5">
          <button
            type="button"
            onClick={() => setDrawerOpen(true)}
            className="-ml-1 rounded-lg p-2 text-muted hover:bg-sunken hover:text-ink md:hidden"
            aria-label="Open chat list"
          >
            <Menu size={20} />
          </button>
          <h1 className="truncate text-[15px] font-medium">{active?.title ?? MODEL_NAME}</h1>
          <div className="ml-auto">
            <StatusPill />
          </div>
        </header>
        <Conversation
          key={chatId}
          chatId={chatId}
          initialMessages={active?.messages ?? []}
          settings={settings}
          onSettingsChange={updateSettings}
          onSave={saveMessages}
        />
      </main>
    </div>
  );
}
