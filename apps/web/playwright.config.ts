import { defineConfig, devices } from "@playwright/test";

// End-to-end checks of the deployed app (default) or a local build: E2E_BASE_URL=http://localhost:3100/heretic-inference
// Needs the app password in E2E_PASSWORD. Real answers from the GPU; nothing is mocked.
// Trailing slash: relative paths such as "./api/status" must resolve inside the base path.
const baseURL = (process.env.E2E_BASE_URL ?? "https://alphaexperiments.com/heretic-inference").replace(/\/?$/, "/");

export default defineConfig({
  testDir: "./e2e",
  timeout: 180_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  retries: 0,
  reporter: [["list"]],
  use: {
    baseURL,
    channel: "chrome",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "desktop", use: { ...devices["Desktop Chrome"], channel: "chrome" } },
    { name: "phone", use: { ...devices["Pixel 7"], channel: "chrome" }, grep: /@phone/ },
  ],
});
