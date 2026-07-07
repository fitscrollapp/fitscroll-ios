// Headless render of localized, FRAMELESS Google Play screenshots (1080×2160).
//
// Uses the system Google Chrome (no browser download) + the already-running
// PRODUCTION server (bun run start). For each locale it loads
// /?android=1&locale=xx and drives the page's own html-to-image capture hook
// (window.__fitscroll.captureCard) to grab each card at EXACTLY 1080×2160,
// writing them into public/screenshots/android/<locale>/NN-name.png.
//
// Single browser, closed at the end — no daemons, no worker leaks.

import puppeteer from "puppeteer-core";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PORT = process.env.PORT || "3100";
const BASE = `http://localhost:${PORT}`;
const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT = join(__dirname, "public", "screenshots", "android");

const LOCALES = ["en", "tr", "pt-BR", "es", "fr", "de", "it", "ja", "ko", "zh-Hans", "ru"];
const W = 1080;
const H = 2160;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ["--no-sandbox", "--disable-dev-shm-usage", "--force-color-profile=srgb"],
});

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 1200, deviceScaleFactor: 1 });

  for (const loc of LOCALES) {
    const dir = join(OUT, loc);
    rmSync(dir, { recursive: true, force: true });
    mkdirSync(dir, { recursive: true });

    await page.goto(`${BASE}/?android=1&locale=${encodeURIComponent(loc)}`, {
      waitUntil: "networkidle0",
      timeout: 60000,
    });

    // Wait for base64 image preload + the render hook to be live.
    await page.waitForFunction(
      () => window.__fitscroll && window.__fitscroll.ready && window.__fitscroll.android,
      { timeout: 60000 },
    );
    await sleep(2500); // let fonts + offscreen export refs settle

    const ids = await page.evaluate(() => window.__fitscroll.slides);
    for (let i = 0; i < ids.length; i++) {
      const dataUrl = await page.evaluate(
        (idx, w, h) => window.__fitscroll.captureCard(idx, w, h),
        i,
        W,
        H,
      );
      const b64 = dataUrl.split(",")[1];
      const name = `${String(i + 1).padStart(2, "0")}-${ids[i]}.png`;
      writeFileSync(join(dir, name), Buffer.from(b64, "base64"));
    }
    console.log(`[${loc}] saved ${ids.length} cards`);
  }
} finally {
  await browser.close();
}
console.log("done");
