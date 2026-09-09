// Renders a clean PNG screenshot of the real Impact Hub 3D viewer
// (web/alive_ng_3d_viewer.html) so the donation project card can show the
// actual project instead of a stock photo.
//
// Usage:  node scripts/render_project_viewer_image.mjs
// Output: web/images/impact_hub_3d_view.png
//         assets/images/impact_hub_3d_view.png
//         viewer_render_status.txt  (DONE or ERROR: ...)

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const statusFile = path.join(root, 'viewer_render_status.txt');

function status(text) {
  try {
    fs.writeFileSync(statusFile, text);
  } catch (_) { }
}

try {
  const puppeteer = (await import('puppeteer')).default;

  const viewerPath = path.join(root, 'web', 'alive_ng_3d_viewer.html');
  if (!fs.existsSync(viewerPath)) {
    status('ERROR: viewer file missing at web/alive_ng_3d_viewer.html');
    process.exit(1);
  }
  const viewerUrl = 'file:///' + viewerPath.replaceAll('\\', '/');

  const webOutDir = path.join(root, 'web', 'images');
  const assetOutDir = path.join(root, 'assets', 'images');
  fs.mkdirSync(webOutDir, { recursive: true });
  fs.mkdirSync(assetOutDir, { recursive: true });

  const browser = await puppeteer.launch({ headless: 'new' });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 760, deviceScaleFactor: 2 });
    await page.goto(viewerUrl, { waitUntil: 'load' });

    // Hide the UI overlays so the screenshot is a clean 3D render.
    await page.evaluate(() => {
      for (const sel of ['.caption', '.hint', '.scale']) {
        const el = document.querySelector(sel);
        if (el) el.style.display = 'none';
      }
    });

    // Let the animation loop paint a few frames.
    await new Promise((r) => setTimeout(r, 1500));

    const viewport = await page.$('.viewport');
    if (!viewport) {
      status('ERROR: .viewport element not found in viewer page');
      process.exit(1);
    }

    await viewport.screenshot({ path: path.join(webOutDir, 'impact_hub_3d_view.png') });
    await viewport.screenshot({ path: path.join(assetOutDir, 'impact_hub_3d_view.png') });
    status('DONE');
  } finally {
    await browser.close();
  }
} catch (err) {
  status('ERROR: ' + (err && err.message ? err.message : String(err)));
  process.exit(1);
}
