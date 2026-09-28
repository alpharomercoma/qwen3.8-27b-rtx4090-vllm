"use client";

import { Lock, Pencil, SquarePen, Terminal, Trash2, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { lock } from "@/app/actions";
import { groupLabel, type StoredChat } from "@/lib/chat-store";
import { ApiAccessDialog } from "./api-access";
import { Mark } from "./mark";
import { ThemeSwitch } from "./theme-switch";

type Props = {
  chats: StoredChat[];
  activeId: string;
  open: boolean;
  onClose: () => void;
  onNew: () => void;
  onSelect: (id: string) => void;
  onDelete: (id: string) => void;
  onRename: (id: string, title: string) => void;
  storageFull: boolean;
};

export function Sidebar({ chats, activeId, open, onClose, onNew, onSelect, onDelete, onRename, storageFull }: Props) {
  const [apiOpen, setApiOpen] = useState(false);
  const groups: { label: string; chats: StoredChat[] }[] = [];
  for (const chat of chats) {
    const label = groupLabel(chat.updatedAt);
    const group = groups.at(-1);
    if (group?.label === label) group.chats.push(chat);
    else groups.push({ label, chats: [chat] });
  }

  return (
    <>
      {open && <div className="fixed inset-0 z-30 bg-black/50 md:hidden" onClick={onClose} aria-hidden="true" />}
      <nav
        aria-label="Chats"
        className={`fixed inset-y-0 left-0 z-40 flex w-72 flex-col bg-paper transition-transform md:static md:z-auto md:translate-x-0 ${
          open ? "translate-x-0 shadow-xl" : "-translate-x-full"
        }`}
      >
        <div className="flex h-14 items-center gap-2.5 px-4">
          <Mark size={26} />
          <span className="text-[15px] font-semibold tracking-tight">Heretic</span>
          <button
            type="button"
            onClick={onClose}
            className="ml-auto rounded-lg p-1.5 text-muted hover:bg-sunken hover:text-ink md:hidden"
            aria-label="Close chat list"
          >
            <X size={18} />
          </button>
        </div>
        <div className="px-3">
          <button
            type="button"
            onClick={onNew}
            className="flex w-full items-center gap-2 rounded-lg border border-line bg-surface px-3 py-2 text-sm font-medium hover:border-accent/50"
          >
            <SquarePen size={16} className="text-accent" />
            New chat
          </button>
        </div>
        <div className="mt-3 flex-1 overflow-y-auto px-2 pb-3">
          {chats.length === 0 && <p className="px-2 py-3 text-sm text-muted">Your chats appear here. They are saved in this browser only.</p>}
          {groups.map((group) => (
            <section key={group.label} className="mt-2">
              <h2 className="px-2 pb-1 pt-2 text-xs font-medium text-muted">{group.label}</h2>
              <ul>
                {group.chats.map((chat) => (
                  <ChatRow
                    key={chat.id}
                    chat={chat}
                    active={chat.id === activeId}
                    onSelect={() => onSelect(chat.id)}
                    onDelete={() => onDelete(chat.id)}
                    onRename={(title) => onRename(chat.id, title)}
                  />
                ))}
              </ul>
            </section>
          ))}
        </div>
        {storageFull && (
          <p role="alert" className="mx-3 mb-2 rounded-lg bg-danger/10 px-3 py-2 text-xs text-danger">
            This browser&apos;s storage is full, so new messages are not saved. Delete old chats to free space.
          </p>
        )}
        <div className="flex items-center gap-1 border-t border-line px-2 py-2">
          <button
            type="button"
            onClick={() => setApiOpen(true)}
            className="flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-muted hover:bg-sunken hover:text-ink"
          >
            <Terminal size={16} />
            Use from the terminal
          </button>
          <div className="ml-auto flex items-center">
            <ThemeSwitch />
            <form action={lock}>
              <button
                type="submit"
                className="rounded-lg p-2 text-muted hover:bg-sunken hover:text-ink"
                aria-label="Lock"
                title="Lock"
              >
                <Lock size={16} />
              </button>
            </form>
          </div>
        </div>
      </nav>
      <ApiAccessDialog open={apiOpen} onClose={() => setApiOpen(false)} />
    </>
  );
}

function ChatRow({
  chat,
  active,
  onSelect,
  onDelete,
  onRename,
}: {
  chat: StoredChat;
  active: boolean;
  onSelect: () => void;
  onDelete: () => void;
  onRename: (title: string) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (editing) inputRef.current?.select();
  }, [editing]);

  if (editing) {
    return (
      <li>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            onRename(inputRef.current?.value ?? "");
            setEditing(false);
          }}
        >
          <input
            ref={inputRef}
            defaultValue={chat.title}
            aria-label="Chat title"
            onBlur={(e) => {
              onRename(e.currentTarget.value);
              setEditing(false);
            }}
            onKeyDown={(e) => e.key === "Escape" && setEditing(false)}
            className="w-full rounded-lg border border-accent bg-surface px-2 py-1.5 text-sm outline-none focus-visible:outline-none"
          />
        </form>
      </li>
    );
  }

  return (
    <li className="group relative">
      <button
        type="button"
        onClick={onSelect}
        aria-current={active ? "page" : undefined}
        className={`w-full truncate rounded-lg py-1.5 pl-2 pr-16 text-left text-sm ${
          active ? "bg-surface font-medium shadow-[inset_0_0_0_1px_var(--line)]" : "hover:bg-sunken"
        }`}
        title={chat.title}
      >
        {chat.title}
      </button>
      <div
        className={`absolute inset-y-0 right-1 flex items-center gap-0.5 ${
          confirming ? "" : "opacity-0 focus-within:opacity-100 group-hover:opacity-100"
        }`}
      >
        {confirming ? (
          <>
            <button
              type="button"
              onClick={onDelete}
              className="rounded-md bg-danger px-2 py-0.5 text-xs font-medium text-white"
            >
              Delete
            </button>
            <button
              type="button"
              onClick={() => setConfirming(false)}
              className="rounded-md p-1 text-muted hover:text-ink"
              aria-label="Keep chat"
            >
              <X size={14} />
            </button>
          </>
        ) : (
          <>
            <button
              type="button"
              onClick={() => setEditing(true)}
              className="rounded-md p-1 text-muted hover:text-ink"
              aria-label={`Rename ${chat.title}`}
            >
              <Pencil size={14} />
            </button>
            <button
              type="button"
              onClick={() => setConfirming(true)}
              className="rounded-md p-1 text-muted hover:text-danger"
              aria-label={`Delete ${chat.title}`}
            >
              <Trash2 size={14} />
            </button>
          </>
        )}
      </div>
    </li>
  );
}
