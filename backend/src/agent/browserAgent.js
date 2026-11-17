import fs from 'fs';
import path from 'path';
import { chromium } from 'playwright';
import { config } from '../config.js';

/**
 * Single shared Chromium with a persistent profile so Gmail / WA / Swiggy
 * stay logged in between demos.
 */
export class BrowserAgent {
  constructor() {
    this.context = null;
    this.page = null;
    this.lastScreenshotPath = path.join(config.dataDir, 'last-screen.png');
  }

  async ensure() {
    if (this.page && !this.page.isClosed()) {
      return this.page;
    }
    fs.mkdirSync(config.userDataDir, { recursive: true });
    fs.mkdirSync(config.dataDir, { recursive: true });

    this.context = await chromium.launchPersistentContext(config.userDataDir, {
      headless: config.headless,
      viewport: { width: 1280, height: 800 },
      hasTouch: true,
      isMobile: false,
      ignoreDefaultArgs: ['--enable-automation'],
      args: [
        '--disable-blink-features=AutomationControlled',
        '--disable-infobars',
      ],
    });
    await this.context.addInitScript(() => {
      Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    });
    this.page = this.context.pages()[0] || (await this.context.newPage());
    return this.page;
  }

  async navigate(url) {
    const page = await this.ensure();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await this.screenshot();
    return { url: page.url(), title: await page.title() };
  }

  async screenshot() {
    const page = await this.ensure();
    await page.screenshot({ path: this.lastScreenshotPath, fullPage: false });
    return this.lastScreenshotPath;
  }

  async readVisibleText({ maxChars = 4000 } = {}) {
    const page = await this.ensure();
    const title = await page.title();
    const text = await page.evaluate(() => {
      const root = document.body;
      if (!root) return '';
      const clone = root.cloneNode(true);
      for (const sel of ['script', 'style', 'noscript', 'svg']) {
        clone.querySelectorAll(sel).forEach((n) => n.remove());
      }
      return (clone.innerText || '').replace(/\s+/g, ' ').trim();
    });
    await this.screenshot();
    const clipped = text.slice(0, maxChars);
    return { title, url: page.url(), text: clipped };
  }

  async clickText(label) {
    const page = await this.ensure();
    const locator = page.getByText(label, { exact: false }).first();
    await locator.click({ timeout: 15000 });
    await page.waitForTimeout(800);
    await this.screenshot();
    return { clicked: label, url: page.url() };
  }

  async type(selectorOrPlaceholder, value, { pressEnter = false } = {}) {
    const page = await this.ensure();
    let filled = false;
    try {
      await page.fill(selectorOrPlaceholder, value, { timeout: 4000 });
      filled = true;
    } catch {
      const byPlaceholder = page.getByPlaceholder(selectorOrPlaceholder);
      if ((await byPlaceholder.count()) > 0) {
        await byPlaceholder.first().fill(value);
        filled = true;
      } else {
        const byRole = page.getByRole('textbox').first();
        await byRole.fill(value);
        filled = true;
      }
    }
    if (pressEnter) {
      await page.keyboard.press('Enter');
      await page.waitForTimeout(1200);
    }
    await this.screenshot();
    return { filled, value };
  }

  async status() {
    if (!this.page || this.page.isClosed()) {
      return { ready: false };
    }
    return {
      ready: true,
      url: this.page.url(),
      title: await this.page.title(),
    };
  }

  async close() {
    if (this.context) {
      await this.context.close();
    }
    this.context = null;
    this.page = null;
  }
}

export const browserAgent = new BrowserAgent();
