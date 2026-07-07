// Headless render of localized App Store screenshots.
// Uses the system Google Chrome (no browser download) + the already-running
// production server at :3000. Drives each locale's "Export All" and saves the
// PNGs into <out>/<locale>/. Single browser, closed at the end — no daemons.

import puppeteer from "puppeteer-core";
import { existsSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const BASE = "http://localhost:3000";
const OUT = join(homedir(), "Downloads", "fitscroll-shots");
const LOCALES = ["en", "tr", "pt-BR", "es", "fr", "de", "it", "ja", "ko", "zh-Hans", "ru"];
const EXPECTED = 7; // slides per locale

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const pngs = (dir) => (existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith(".png")) : []);

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ["--no-sandbox", "--disable-dev-shm-usage", "--force-color-profile=srgb"],
});

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1500, height: 1000, deviceScaleFactor: 1 });
  const client = await page.createCDPSession();

  for (const loc of LOCALES) {
    const dir = join(OUT, loc);
    rmSync(dir, { recursive: true, force: true });
    mkdirSync(dir, { recursive: true });
    await client.send("Page.setDownloadBehavior", { behavior: "allow", downloadPath: dir });

    await page.goto(`${BASE}/?locale=${encodeURIComponent(loc)}`, {
      waitUntil: "networkidle0",
      timeout: 60000,
    });
    await sleep(3500); // let image preload (base64) + fonts settle

    // Click the page's own "Export All" button.
    const clicked = await page.evaluate(() => {
      const b = [...document.querySelectorAll("button")].find((x) =>
        /export all/i.test(x.textContent || ""),
      );
      if (b) { b.click(); return true; }
      return false;
    });
    if (!clicked) { console.log(`[${loc}] ✗ Export All button not found`); continue; }

    // Wait until all 7 PNGs land (no .crdownload temp files remain).
    const deadline = Date.now() + 90000;
    while (Date.now() < deadline) {
      const done = pngs(dir).length;
      const pending = existsSync(dir)
        ? readdirSync(dir).filter((f) => f.endsWith(".crdownload")).length
        : 0;
      if (done >= EXPECTED && pending === 0) break;
      await sleep(700);
    }
    console.log(`[${loc}] saved ${pngs(dir).length}/${EXPECTED}`);
  }
} finally {
  await browser.close();
}
console.log("done");
