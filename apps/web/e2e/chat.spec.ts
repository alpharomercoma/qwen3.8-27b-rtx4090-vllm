import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test, type Page } from "@playwright/test";

const PASSWORD = process.env.E2E_PASSWORD ?? "";
test.beforeAll(() => {
  if (!PASSWORD) throw new Error("Set E2E_PASSWORD to the app password (the APP_PASSWORD on Vercel).");
});
// baseURL ends in /heretic-inference; "" resolves to it, "./api/..." to its API routes
const home = "";

// the composer; getByLabel("Message") would also match every "Edit message" button
const composer = (page: Page) => page.getByRole("textbox", { name: "Message", exact: true });

async function unlock(page: Page) {
  await page.goto(home);
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Unlock" }).click();
  await expect(composer(page)).toBeVisible();
}

async function ask(page: Page, text: string) {
  await composer(page).fill(text);
  await composer(page).press("Enter");
  // the Regenerate button appears when the answer has finished
  await expect(page.getByRole("button", { name: "Regenerate answer" })).toBeVisible({ timeout: 150_000 });
  return (await page.locator(".answer").last().innerText()).trim();
}

test("the app is locked without the password; API routes refuse", async ({ page, request }) => {
  await page.goto(home);
  await expect(page.getByLabel("Password")).toBeVisible();
  await expect(composer(page)).toHaveCount(0);
  expect((await request.get("./api/status")).status()).toBe(401);
  expect((await request.post("./api/chat", { data: { messages: [] } })).status()).toBe(401);
});

test("a wrong password is refused, the right one unlocks", async ({ page }) => {
  await page.goto(home);
  await page.getByLabel("Password").fill("not-the-password");
  await page.getByRole("button", { name: "Unlock" }).click();
  await expect(page.getByRole("alert").filter({ hasText: "not right" })).toBeVisible();
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Unlock" }).click();
  await expect(composer(page)).toBeVisible();
  const cookie = (await page.context().cookies()).find((c) => c.name === "heretic_session");
  expect(cookie?.httpOnly).toBe(true);
  expect(cookie?.path).toBe("/heretic-inference");
});

test("the GPU server shows as online", async ({ page }) => {
  await unlock(page);
  await expect(page.getByRole("status").filter({ hasText: "Online" })).toBeVisible();
});

test("an answer streams with reasoning, telemetry, and is saved", async ({ page }) => {
  await unlock(page);
  const think = page.getByRole("button", { name: "Think" });
  if ((await think.getAttribute("aria-pressed")) !== "true") await think.click();
  const answer = await ask(page, "What is 17 * 23? Reply with the number only.");
  expect(answer).toContain("391");
  await expect(page.getByRole("button", { name: /Thought for/ })).toBeVisible();
  const stats = page.getByLabel("Answer statistics").last();
  await expect(stats).toContainText("s to first token");
  await expect(stats).toContainText("tokens");
  // saved in this browser: it survives a reload
  await page.reload();
  await page.getByRole("button", { name: /^What is 17 \* 23/ }).click();
  await expect(page.locator(".answer").last()).toContainText("391");
});

test("thinking off, stop, edit and regenerate", async ({ page }) => {
  await unlock(page);
  const think = page.getByRole("button", { name: "Think" });
  if ((await think.getAttribute("aria-pressed")) === "true") await think.click();
  await composer(page).fill("Count from 1 to 300, one number per line.");
  await composer(page).press("Enter");
  await expect(page.locator(".answer").last()).toContainText("5", { timeout: 60_000 });
  await page.getByRole("button", { name: "Stop generating" }).click();
  await expect(page.getByRole("button", { name: "Send" })).toBeVisible();
  expect(await page.getByRole("button", { name: /Thought for/ }).count()).toBe(0);
  expect((await page.locator(".answer").last().innerText()).includes("300")).toBe(false);

  await page.locator("main div.whitespace-pre-wrap", { hasText: "Count from 1" }).hover();
  await page.getByRole("button", { name: "Edit message" }).click();
  await page.getByRole("textbox", { name: "Edit message" }).fill("Reply with exactly the word: pong");
  await page.getByRole("textbox", { name: "Edit message" }).press("Enter");
  await expect(page.getByRole("button", { name: "Regenerate answer" })).toBeVisible({ timeout: 60_000 });
  expect((await page.locator(".answer").last().innerText()).toLowerCase()).toContain("pong");
  expect(await page.locator("main div.whitespace-pre-wrap.bg-sunken").count()).toBe(1);

  await page.getByRole("button", { name: "Regenerate answer" }).click();
  await expect(page.getByRole("button", { name: "Stop generating" })).toBeHidden({ timeout: 60_000 });
  await expect(page.getByRole("button", { name: "Regenerate answer" })).toBeVisible();
  expect((await page.locator(".answer").last().innerText()).toLowerCase()).toContain("pong");
});

test("a multi-turn conversation keeps context", async ({ page }) => {
  await unlock(page);
  await ask(page, "My project is called Bantayog. Reply with just: noted.");
  const second = await ask(page, "What is my project called? One word.");
  expect(second).toContain("Bantayog");
});

test("the terminal dialog shows the API URL and model, never a key", async ({ page }) => {
  await unlock(page);
  await page.getByRole("button", { name: "Use from the terminal" }).click();
  const dialog = page.getByRole("dialog");
  await expect(dialog).toContainText("https://alphaexperiments.com/heretic-inference/v1");
  await expect(dialog).toContainText("qwen3.8-27b-heretic");
  await expect(dialog).toContainText("$HERETIC_API_KEY");
  const text = await dialog.innerText();
  expect(text).not.toMatch(/sk-heretic-(?!PASTE)[A-Za-z0-9_-]{20,}/);
  // the config commands are exactly the ones documented (and tested) in docs/CLIENTS.md
  const docs = readFileSync(join(__dirname, "../../../docs/CLIENTS.md"), "utf8");
  const documented = docs.split("\n").filter((line) => line.startsWith("jq '.provider"));
  expect(documented).toHaveLength(2);
  for (const line of documented) expect(text).toContain(line);
});

test("rename and delete a chat", async ({ page }) => {
  await unlock(page);
  await ask(page, "Reply with the word: temporary");
  const row = page.getByRole("navigation", { name: "Chats" }).getByRole("button", { name: /^Reply with the word: temporary/ });
  await row.first().hover();
  await page.getByRole("button", { name: /^Rename Reply with the word: temporary/ }).first().click();
  await page.getByRole("textbox", { name: "Chat title" }).fill("E2E renamed chat");
  await page.getByRole("textbox", { name: "Chat title" }).press("Enter");
  const renamed = page.getByRole("navigation", { name: "Chats" }).getByRole("button", { name: "E2E renamed chat", exact: true });
  await expect(renamed).toBeVisible();
  await renamed.hover();
  await page.getByRole("button", { name: "Delete E2E renamed chat" }).click();
  await page.getByRole("button", { name: "Delete", exact: true }).click();
  await expect(renamed).toHaveCount(0);
});

test("@phone the chat list opens as a drawer and the page does not scroll sideways", async ({ page }) => {
  await unlock(page);
  await page.getByRole("button", { name: "Open chat list" }).click();
  await expect(page.getByRole("button", { name: "New chat" })).toBeInViewport();
  await page.getByRole("button", { name: "Close chat list" }).click();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(0);
  const answer = await ask(page, "Reply with exactly: ok");
  expect(answer.toLowerCase()).toContain("ok");
});
