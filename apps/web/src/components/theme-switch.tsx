"use client";

import { Monitor, Moon, Sun } from "lucide-react";
import { useEffect, useState } from "react";
import { THEME_KEY } from "@/lib/chat-store";

type Theme = "system" | "light" | "dark";
const NEXT: Record<Theme, Theme> = { system: "light", light: "dark", dark: "system" };
const LABEL: Record<Theme, string> = { system: "Theme: system", light: "Theme: light", dark: "Theme: dark" };

function apply(theme: Theme) {
  const dark = theme === "dark" || (theme === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.classList.toggle("dark", dark);
}

export function ThemeSwitch() {
  const [theme, setTheme] = useState<Theme>("system");

  useEffect(() => {
    let saved: Theme = "system";
    try {
      saved = (localStorage.getItem(THEME_KEY) as Theme | null) ?? "system";
    } catch {}
    // eslint-disable-next-line react-hooks/set-state-in-effect -- read the saved theme after hydration
    setTheme(saved);
    const media = matchMedia("(prefers-color-scheme: dark)");
    const follow = () => {
      let current: Theme = "system";
      try {
        current = (localStorage.getItem(THEME_KEY) as Theme | null) ?? "system";
      } catch {}
      if (current === "system") apply("system");
    };
    media.addEventListener("change", follow);
    return () => media.removeEventListener("change", follow);
  }, []);

  const Icon = theme === "light" ? Sun : theme === "dark" ? Moon : Monitor;
  return (
    <button
      type="button"
      onClick={() => {
        const next = NEXT[theme];
        setTheme(next);
        try {
          localStorage.setItem(THEME_KEY, next);
        } catch {}
        apply(next);
      }}
      className="rounded-lg p-2 text-muted hover:bg-sunken hover:text-ink"
      aria-label={`${LABEL[theme]}. Change theme`}
      title={LABEL[theme]}
    >
      <Icon size={16} />
    </button>
  );
}
