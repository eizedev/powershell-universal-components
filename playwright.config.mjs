// Browser tests: the documentation site renders the module's own React component, so it is tested
// in Chromium, Firefox and WebKit (Safari's engine) without a PSU instance. Build the site first:
// pwsh ./docs/site/Build-Site.ps1
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
    testDir: "tests/browser",
    timeout: 60000,
    retries: process.env.CI ? 1 : 0,
    reporter: process.env.CI ? [["list"], ["github"]] : "list",
    use: { baseURL: "http://127.0.0.1:8765", viewport: { width: 1440, height: 900 } },
    webServer: { command: "node tests/browser/serve.mjs", url: "http://127.0.0.1:8765/", reuseExistingServer: !process.env.CI },
    projects: [
        { name: "chromium", use: { ...devices["Desktop Chrome"], viewport: { width: 1440, height: 900 } } },
        { name: "firefox", use: { ...devices["Desktop Firefox"], viewport: { width: 1440, height: 900 } } },
        { name: "webkit", use: { ...devices["Desktop Safari"], viewport: { width: 1440, height: 900 } } }
    ]
});
