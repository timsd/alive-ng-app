const fs = require('fs');
const path = require('path');
const http = require('http');
const puppeteer = require('puppeteer');

const appUrl = process.env.APP_URL || 'http://localhost:8080';
const artifactsDir = path.join(__dirname, 'test_artifacts', 'web_routes');
const buildRoot = path.resolve(__dirname, '../../build/web');

function contentType(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  return {
    '.css': 'text/css; charset=utf-8',
    '.html': 'text/html; charset=utf-8',
    '.ico': 'image/x-icon',
    '.js': 'text/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
    '.wasm': 'application/wasm',
  }[extension] || 'application/octet-stream';
}

function startStaticServer() {
  if (!fs.existsSync(path.join(buildRoot, 'index.html'))) {
    throw new Error('build/web is missing. Run npm run build:web first.');
  }

  const target = new URL(appUrl);
  const port = Number(target.port || 8080);
  const host = target.hostname;

  return new Promise((resolve, reject) => {
    const server = http.createServer((request, response) => {
      const pathname = decodeURIComponent(
        new URL(request.url || '/', appUrl).pathname,
      );
      const relativePath = pathname === '/'
        ? 'index.html'
        : pathname.replace(/^\/+/, '');
      const candidate = path.resolve(buildRoot, relativePath);
      const insideBuild = candidate === buildRoot ||
        candidate.startsWith(`${buildRoot}${path.sep}`);
      const filePath = insideBuild && fs.existsSync(candidate) &&
          fs.statSync(candidate).isFile()
        ? candidate
        : path.join(buildRoot, 'index.html');

      response.writeHead(200, {
        'Content-Type': contentType(filePath),
        'Cache-Control': 'no-store',
      });
      fs.createReadStream(filePath).pipe(response);
    });

    server.once('error', reject);
    server.listen(port, host, () => resolve(server));
  });
}

const routes = process.env.SMOKE_ROUTE ? [process.env.SMOKE_ROUTE] : [
  '/',
  '/#/home',
  '/#/onboarding',
  '/#/auth',
  '/#/donation',
  '/#/gift-in-kind',
  '/#/non-monetary-gift',
  '/#/bible',
  '/#/bible-game',
  '/#/books-tracts',
  '/#/library',
  '/#/podcasts',
  '/#/interactive-lessons',
  '/#/kids-stories',
  '/#/kids-mission',
  '/#/testimonies',
  '/#/resources',
  '/#/daily',
  '/#/health',
  '/#/enhanced-health',
  '/#/prayer',
  '/#/prayer-wall',
  '/#/missions',
  '/#/events',
  '/#/chapters',
  '/#/chat',
  '/#/conference',
  '/#/profile',
  '/#/notification-settings',
  '/#/content-management',
  '/#/admin',
  '/#/privacy-policy',
  '/#/terms-conditions',
  '/#/help-support',
  '/#/about-app',
  '/#/about-alive',
];

function fileNameForRoute(route) {
  return route
    .replace(/^\/#?\//, '')
    .replace(/[^\w-]+/g, '_')
    .replace(/^_+|_+$/g, '') || 'landing';
}

async function waitForAppShell(page) {
  const isLandingPage = await page.evaluate(() => !window.location.hash);
  if (isLandingPage) {
    await page.waitForSelector('#open-web-app', { visible: true, timeout: 90000 });
    return;
  }

  await page.waitForSelector('flt-glass-pane', { timeout: 90000 });
  await page.waitForFunction(
    () => {
      const overlay = document.querySelector(
        '#app-loading-overlay, #flutter-bootstrap-overlay',
      );
      if (!overlay) return true;
      const style = window.getComputedStyle(overlay);
      return style.display === 'none' || style.visibility === 'hidden';
    },
    { timeout: 90000 },
  );
  await new Promise((resolve) => setTimeout(resolve, 500));
}

(async () => {
  fs.mkdirSync(artifactsDir, { recursive: true });

  const staticServer = process.env.APP_URL ? null : await startStaticServer();
  process.once('exit', () => staticServer?.close());

  const browser = await puppeteer.launch({
    headless: 'new',
    defaultViewport: { width: 390, height: 844, deviceScaleFactor: 1 },
  });

  const failures = [];

  for (const route of routes) {
    const page = await browser.newPage();
    const errors = [];
    const warnings = [];
    const target = new URL(route, appUrl).toString();

    let expectedDailyVerseMiss = false;
    page.on('pageerror', (error) => errors.push(error.message));
    page.on('response', (response) => {
      const status = response.status();
      const url = response.url();
      if (
        status === 404 &&
        url.includes('/tables/daily_verses/rows/')
      ) {
        // The app deliberately generates a fallback daily verse when the date row is absent.
        expectedDailyVerseMiss = true;
        return;
      }

      const expectedSignedOutAccountCheck =
        status === 401 && url.includes('/account');
      if (
        url.includes('api.alivenigeria.org') &&
        status >= 400 &&
        !expectedSignedOutAccountCheck
      ) {
        errors.push('HTTP ' + status + ': ' + url);
      }
    });
    page.on('console', (message) => {
      const text = message.text();
      const expectedGuestState =
        message.type() === 'error' &&
        (text.includes('Not signed in with the identity provider.') ||
          text.includes('Failed to load resource: the server responded with a status of 401') ||
          (expectedDailyVerseMiss && text.includes('status of 404')));
      if (message.type() === 'error' && !expectedGuestState) errors.push(text);
      if (message.type() === 'warning') warnings.push(text);
    });

    try {
      await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 60000 });
      await waitForAppShell(page);
      await page.screenshot({
        path: path.join(artifactsDir, `${fileNameForRoute(route)}.png`),
        fullPage: true,
      });

      const bodyText = await page.evaluate(() => document.body.innerText || '');
      const notFound = /page not found|not found/i.test(bodyText);
      if (notFound) {
        errors.push('Rendered a not-found screen.');
      }
    } catch (error) {
      errors.push(error.message);
      await page.screenshot({
        path: path.join(artifactsDir, `${fileNameForRoute(route)}_error.png`),
        fullPage: true,
      }).catch(() => {});
    } finally {
      await page.close();
    }

    if (errors.length > 0) {
      failures.push({ route, target, errors, warnings });
    }
  }

  await browser.close();
  await new Promise((resolve) => staticServer?.close(resolve) ?? resolve());

  if (failures.length > 0) {
    console.error(JSON.stringify({ appUrl, failures }, null, 2));
    process.exitCode = 1;
    return;
  }

  console.log(`Smoke tested ${routes.length} web routes at ${appUrl}.`);
  console.log(`Screenshots: ${artifactsDir}`);
})();
