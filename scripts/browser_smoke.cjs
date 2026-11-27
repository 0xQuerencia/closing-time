const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const output = process.env.CLOSING_TIME_BROWSER_OUT || 'build/browser-smoke';
const url = 'http://127.0.0.1:8137/index.html';
const findings = {};
const errors = [];

async function waitForExport(page) {
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    const status = document.querySelector('#status');
    return canvas && canvas.width > 0 && canvas.height > 0 && (!status || getComputedStyle(status).display === 'none');
  }, {}, { timeout: 90000 });
}

async function screenshot(page, name) {
  await page.screenshot({ path: path.join(output, name + '.png'), timeout: 120000 });
}

function userFile(filename) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('/userfs');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains('FILE_DATA')) {
        db.close();
        resolve(null);
        return;
      }
      const store = db.transaction('FILE_DATA').objectStore('FILE_DATA');
      const keys = store.getAllKeys();
      keys.onsuccess = () => {
        const key = keys.result.find(entry => String(entry).endsWith('/' + filename));
        if (!key) {
          db.close();
          resolve(null);
          return;
        }
        const file = store.get(key);
        file.onsuccess = () => {
          db.close();
          resolve(new TextDecoder().decode(file.result.contents));
        };
        file.onerror = () => reject(file.error);
      };
      keys.onerror = () => reject(keys.error);
    };
  });
}

async function waitForUserFile(page, filename) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const content = await page.evaluate(userFile, filename);
    if (content !== null) return content;
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  throw new Error('Timed out waiting for the browser save ' + filename);
}

async function main() {
  fs.mkdirSync(output, { recursive: true });
  const server = spawn('python3', ['-m', 'http.server', '8137', '--bind', '127.0.0.1', '--directory', 'build/web'], { stdio: 'ignore' });
  let browser;
  try {
    let ready = false;
    for (let attempt = 0; attempt < 40; attempt += 1) {
      try {
        if ((await fetch(url)).ok) {
          ready = true;
          break;
        }
      } catch {}
      await new Promise(resolve => setTimeout(resolve, 250));
    }
    assert.ok(ready, 'the local Web export is served');
    browser = await chromium.launch({
      headless: true,
      executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined,
      args: ['--enable-webgl', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
    });
    const page = await browser.newPage({ viewport: { width: 1024, height: 640 }, deviceScaleFactor: 1 });
    await page.addInitScript(() => {
      window.closingTimeAudio = [];
      window.AudioContext = new Proxy(window.AudioContext, {
        construct(target, args, constructor) {
          const context = Reflect.construct(target, args, constructor);
          window.closingTimeAudio.push(context);
          return context;
        },
      });
    });
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (/SCRIPT ERROR|Failed to load|WebGL 2 not available|GL_INVALID/i.test(message.text())) errors.push(message.text());
    });
    page.on('response', response => {
      if (response.status() >= 400 && /\.(pck|wasm|js)(\?|$)/.test(response.url())) errors.push(response.status() + ' ' + response.url());
    });
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await waitForExport(page);
    await page.waitForTimeout(2800);
    await screenshot(page, '01-title');
    await page.locator('canvas').focus();
    await page.keyboard.press('Enter', { delay: 120 });
    const saved = JSON.parse(await waitForUserFile(page, 'closing_time_opening.json'));
    await screenshot(page, '02-prologue');
    assert.equal(saved?.chapter, 'apartment', 'New Game writes the apartment checkpoint');
    findings.savedChapter = saved.chapter;
    const settings = await waitForUserFile(page, 'settings.cfg');
    assert.match(settings, /graphics_mode="performance"/, 'a fresh browser session starts in Performance mode');
    findings.firstRunGraphics = 'performance';

    for (let line = 0; line < 3; line += 1) {
      await page.keyboard.press('e', { delay: 120 });
      await page.waitForTimeout(550);
    }
    await page.waitForFunction(() => document.pointerLockElement === document.querySelector('canvas'), {}, { timeout: 10000 });
    findings.audioContext = await page.evaluate(() => window.closingTimeAudio.map(context => context.state));
    assert.ok(findings.audioContext.includes('running'), 'a user gesture unlocks Web Audio');
    await screenshot(page, '03-apartment');
    await page.keyboard.down('KeyD');
    await page.waitForTimeout(1550);
    await page.keyboard.up('KeyD');
    await page.keyboard.down('KeyW');
    await page.waitForTimeout(1150);
    await page.keyboard.up('KeyW');
    await screenshot(page, '04-apartment-moved');

    await page.evaluate(() => document.exitPointerLock());
    await page.waitForFunction(() => document.pointerLockElement === null);
    await page.mouse.click(750, 325);
    await page.waitForFunction(() => document.pointerLockElement === document.querySelector('canvas'), {}, { timeout: 10000 });
    findings.pointerLockReacquired = true;

    await page.setViewportSize({ width: 640, height: 360 });
    await page.waitForFunction(() => {
      const canvas = document.querySelector('canvas');
      return canvas.width === 640 && canvas.height === 360;
    });
    findings.resizedCanvas = '640x360';
    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForExport(page);
    await page.waitForTimeout(2500);
    await screenshot(page, '05-title-reloaded');
    await page.locator('canvas').focus();
    await page.keyboard.press('ArrowDown', { delay: 120 });
    await page.waitForTimeout(400);
    await page.keyboard.press('Enter', { delay: 120 });
    await page.waitForFunction(() => document.pointerLockElement === document.querySelector('canvas'), {}, { timeout: 15000 });
    await page.waitForTimeout(1000);
    await screenshot(page, '06-continued');
    const continued = JSON.parse(await page.evaluate(userFile, 'closing_time_opening.json'));
    assert.deepEqual(continued, saved, 'Continue uses the same persisted opening checkpoint');
    findings.persisted = true;
    assert.equal(errors.length, 0, errors.join('\n'));
    fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify({ passed: true, findings, errors }, null, 2));
    console.log('CLOSING TIME WEB SMOKE PASS');
  } catch (error) {
    fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify({ passed: false, error: String(error), findings, errors }, null, 2));
    throw error;
  } finally {
    if (browser) await browser.close();
    server.kill();
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
