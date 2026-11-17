import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';
import { recall, remember, setActiveApp } from '../agent/memory.js';

/** Flipkart Minutes ONLY — never regular Flipkart or Grocery. */
const MINUTES_HOME =
  'https://www.flipkart.com/flipkart-minutes-store?marketplace=HYPERLOCAL';
const MINUTES_SEARCH = (q) =>
  `https://www.flipkart.com/search?q=${encodeURIComponent(q)}&marketplace=HYPERLOCAL&otracker=search`;
const MINUTES_CART =
  'https://www.flipkart.com/viewcart?marketplace=HYPERLOCAL';

async function dismissPopups(page) {
  for (const sel of [
    'button._2KpZ6l._2doB4z',
    'button:has-text("✕")',
    '[aria-label="Close"]',
    'button:has-text("Not now")',
  ]) {
    try {
      const el = page.locator(sel).first();
      if (await el.isVisible({ timeout: 500 }).catch(() => false)) {
        await el.click().catch(() => {});
      }
    } catch {
      /* ignore */
    }
  }
}

function assertMinutes(url) {
  if (/marketplace=GROCERY/i.test(String(url || ''))) {
    throw new Error('Refusing Grocery — Flipkart Minutes (HYPERLOCAL) only');
  }
}

async function openMinutesSearch(page, query) {
  setActiveApp('flipkart');
  await page.goto(MINUTES_HOME, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(1200);
  await dismissPopups(page);
  await page.goto(MINUTES_SEARCH(query), {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  });
  await page.waitForTimeout(2200);
  await dismissPopups(page);
  if (!/HYPERLOCAL/i.test(page.url())) {
    await page.goto(MINUTES_SEARCH(query), {
      waitUntil: 'domcontentloaded',
      timeout: 60000,
    });
    await page.waitForTimeout(1800);
  }
  assertMinutes(page.url());
}

async function scanProducts(page) {
  return page.evaluate(() => {
    const items = [];
    const blocks = Array.from(document.querySelectorAll('div, a, li'));
    for (const el of blocks) {
      const text = (el.innerText || '').replace(/\s+/g, ' ').trim();
      if (!text || text.length < 8 || text.length > 220) continue;
      if (!/₹|rs\.?/i.test(text)) continue;
      if (!/\badd\b/i.test(text)) continue;
      if (/my account|become a seller|download app/i.test(text)) continue;
      const price = (text.match(/₹\s?[\d,]+/) || [])[0] || '';
      const name = text
        .replace(/\badd\b/gi, ' ')
        .replace(/₹\s?[\d,]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 100);
      if (!name || name.length < 4) continue;
      const rect = el.getBoundingClientRect();
      if (rect.top < 80 || rect.height < 36) continue;
      let addEl = null;
      const kids = el.querySelectorAll('button, div, span');
      for (const k of kids) {
        if (/^(add|ADD)$/i.test((k.textContent || '').trim())) {
          const r = k.getBoundingClientRect();
          if (r.width > 20 && r.height > 12) {
            addEl = { x: r.left + r.width / 2, y: r.top + r.height / 2 };
            break;
          }
        }
      }
      items.push({
        name,
        price,
        hasAdd: Boolean(addEl),
        addX: addEl?.x || 0,
        addY: addEl?.y || 0,
        top: rect.top,
      });
      if (items.length >= 16) break;
    }
    const seen = new Set();
    return items.filter((it) => {
      const key = `${it.name}|${it.price}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  });
}

function categoryFromQuery(q) {
  const s = String(q || '').toLowerCase();
  if (/\bmilk\b/.test(s)) return 'milk';
  if (/\bbread\b/.test(s)) return 'bread';
  if (/\beggs?\b/.test(s)) return 'eggs';
  if (/\boil\b/.test(s)) return 'oil';
  if (/\brice\b/.test(s)) return 'rice';
  if (/\bcurd|yogurt\b/.test(s)) return 'curd';
  if (/\bbutter\b/.test(s)) return 'butter';
  if (/\bcheese\b/.test(s)) return 'cheese';
  if (/\btea\b/.test(s)) return 'tea';
  if (/\bcoffee\b/.test(s)) return 'coffee';
  if (/\bsugar\b/.test(s)) return 'sugar';
  if (/\bbanana|apple|mango|fruit\b/.test(s)) return 'fruit';
  if (/\btomato|onion|potato|vegetable\b/.test(s)) return 'vegetables';
  return 'item';
}

function brandFromQuery(q) {
  const m = String(q).match(
    /\b(nandini|amul|mother\s*dairy|heritage|aavin|jersey|govardhan|britannia|nestle|fortune|saffola|india gate|basmati|lay'?s|maggi|dove|lux|dettol)\b/i,
  );
  return m ? m[1].replace(/\s+/g, ' ') : '';
}

function scoreProduct(product, wanted) {
  const n = `${product.name}`.toLowerCase();
  const w = wanted.toLowerCase();
  const cat = categoryFromQuery(w);
  let score = 0;
  for (const token of w.split(/\s+/).filter((t) => t.length > 2)) {
    if (n.includes(token)) score += 3;
  }
  const brand = brandFromQuery(w);
  if (brand && new RegExp(brand.replace(/\s+/g, '\\s*'), 'i').test(n)) score += 10;
  if (/500/i.test(w) && /500/.test(n)) score += 4;
  if (/1\s?l|1000/i.test(w) && /1\s?l|1000/i.test(n)) score += 3;

  if (cat === 'milk') {
    if (/toned milk|full cream|cow milk|farm milk|dairy milk|good life|uht milk/i.test(n)) {
      score += 8;
    }
    if (/milkshake|badam|flavou?red|biscuit|cookies|chips|sofit|kool|almond milk|oat milk|soy milk|plant based|smoodh|toffee|caramel/i.test(n)) {
      score -= 14;
    }
    if (/milk/i.test(n)) score += 2;
  } else if (cat !== 'item') {
    if (n.includes(cat.replace(/s$/, '')) || n.includes(cat)) score += 4;
  }

  if (product.hasAdd) score += 1;
  return score;
}

function filterRelevant(products, wanted) {
  const cat = categoryFromQuery(wanted);
  if (cat === 'milk') {
    const dairy = products.filter(
      (p) =>
        /milk/i.test(p.name) &&
        !/milkshake|biscuit|cookies|chips|sofit|almond milk|oat milk|soy milk|plant based|badam|flavou?red|smoodh|toffee|caramel/i.test(
          p.name,
        ),
    );
    return dairy.length ? dairy : products;
  }
  if (cat === 'item') return products;
  const needle = cat.replace(/s$/, '');
  const hit = products.filter((p) => new RegExp(needle, 'i').test(p.name));
  return hit.length ? hit : products;
}

function searchQueryFor(wanted) {
  const brand = brandFromQuery(wanted);
  const cat = categoryFromQuery(wanted);
  if (cat === 'milk' && !/shake|biscuit/i.test(wanted)) {
    if (brand && !/toned|cream/i.test(wanted)) return `${brand} toned milk 500ml`;
    if (!/500|1\s?l/i.test(wanted)) return `${wanted} 500ml`;
  }
  return wanted;
}

function cleanSearchFromName(name) {
  return String(name || '')
    .replace(/\d+%\s*off/gi, ' ')
    .replace(/₹\s?[\d,]+/g, ' ')
    .replace(/\badd\b/gi, ' ')
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .filter((w) => w.length > 1 && !/^(ml|g|kg|l|off|at)$/i.test(w))
    .slice(0, 5)
    .join(' ');
}

async function pageLooksAdded(page) {
  const go = page.getByText(/go to cart|view cart/i).first();
  if (await go.isVisible({ timeout: 900 }).catch(() => false)) return true;
  return page
    .evaluate(() => {
      const nodes = Array.from(document.querySelectorAll('button, div, span'));
      for (const el of nodes) {
        const t = (el.textContent || '').trim();
        if (t !== '+' && t !== '−' && t !== '-' && t !== '–') continue;
        const r = el.getBoundingClientRect();
        if (r.width >= 12 && r.height >= 12 && r.top > 60) return true;
      }
      return /go to cart|view cart/i.test(document.body?.innerText || '');
    })
    .catch(() => false);
}

async function debugAddTargets(page, product) {
  try {
    const dump = await page.evaluate((nameHint) => {
      const needle = String(nameHint || '').toLowerCase().slice(0, 14);
      const adds = [];
      for (const el of document.querySelectorAll('button, div, span, a')) {
        const t = (el.textContent || '').trim();
        if (!/^add$/i.test(t)) continue;
        const r = el.getBoundingClientRect();
        if (r.width < 10 || r.height < 8 || r.top < 50) continue;
        let p = el.parentElement;
        let ptext = '';
        for (let i = 0; i < 6 && p; i += 1) {
          ptext = (p.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 140);
          if (ptext.toLowerCase().includes(needle) && /₹/.test(ptext)) break;
          p = p.parentElement;
        }
        adds.push({
          tag: el.tagName,
          cls: String(el.className || '').slice(0, 100),
          x: Math.round(r.left + r.width / 2),
          y: Math.round(r.top + r.height / 2),
          w: Math.round(r.width),
          h: Math.round(r.height),
          parent: ptext,
          match: ptext.toLowerCase().includes(needle),
        });
        if (adds.length >= 10) break;
      }
      const x = adds.find((a) => a.match)?.x || 294;
      const y = adds.find((a) => a.match)?.y || 456;
      const stack = [];
      let top = document.elementFromPoint(x, y);
      for (let i = 0; i < 8 && top; i += 1) {
        const cs = getComputedStyle(top);
        stack.push({
          tag: top.tagName,
          cls: String(top.className || '').slice(0, 80),
          id: top.id || '',
          text: (top.textContent || '').trim().slice(0, 40),
          pe: cs.pointerEvents,
          cursor: cs.cursor,
          z: cs.zIndex,
        });
        top = top.parentElement;
      }
      const iframes = Array.from(document.querySelectorAll('iframe')).map((f) => ({
        src: (f.src || '').slice(0, 120),
        w: f.getBoundingClientRect().width,
        h: f.getBoundingClientRect().height,
      }));
      const dataAttrs = [];
      for (const el of document.querySelectorAll('[data-id],[data-tkid],[id*="product"],[id*="listing"]')) {
        dataAttrs.push({
          id: el.getAttribute('data-id') || el.id || '',
          tkid: el.getAttribute('data-tkid') || '',
          text: (el.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 70),
        });
        if (dataAttrs.length >= 10) break;
      }
      const links = Array.from(document.querySelectorAll('a[href]'))
        .map((a) => a.getAttribute('href') || '')
        .filter((h) => /\/p\/|pid=|marketplace=HYPERLOCAL/i.test(h))
        .slice(0, 10);
      // Collect React handler names on Add stack
      const handlers = [];
      let cur = document.elementFromPoint(x, y);
      for (let i = 0; i < 10 && cur; i += 1) {
        const rk = Object.keys(cur).find((k) => k.startsWith('__reactProps$'));
        if (rk && cur[rk]) {
          handlers.push({
            depth: i,
            keys: Object.keys(cur[rk]).filter((k) => /^on[A-Z]/.test(k)),
          });
        }
        cur = cur.parentElement;
      }
      return { adds, hitTest: { x, y, stack }, iframes, dataAttrs, links, handlers };
    }, String(product?.name || '').slice(0, 24));
    const fs = await import('fs');
    const path = await import('path');
    const { config } = await import('../config.js');
    fs.writeFileSync(
      path.join(config.dataDir, 'add-debug.json'),
      JSON.stringify({ url: page.url(), product, dump }, null, 2),
    );
  } catch {
    /* ignore */
  }
}

async function realMouseClick(page, x, y) {
  const client = await page.context().newCDPSession(page);
  try {
    await client.send('Input.dispatchMouseEvent', {
      type: 'mouseMoved',
      x,
      y,
    });
    await page.waitForTimeout(80);
    await client.send('Input.dispatchMouseEvent', {
      type: 'mousePressed',
      x,
      y,
      button: 'left',
      clickCount: 1,
    });
    await page.waitForTimeout(60);
    await client.send('Input.dispatchMouseEvent', {
      type: 'mouseReleased',
      x,
      y,
      button: 'left',
      clickCount: 1,
    });
  } finally {
    await client.detach().catch(() => {});
  }
}

async function clickAddButtonNear(page, product) {
  await debugAddTargets(page, product);
  await dismissPopups(page);
  const hint = String(product?.name || '')
    .replace(/\d+%\s*Off/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 32);
  const short = hint.slice(0, 16);

  // Resolve the best ADD target for this product (prefer exact name match).
  const target = await page
    .evaluate((nameHint) => {
      const needle = String(nameHint || '').toLowerCase().slice(0, 18);
      let best = null;
      for (const el of document.querySelectorAll('div, span, button')) {
        const t = (el.textContent || '').trim();
        if (!/^add$/i.test(t)) continue;
        const r = el.getBoundingClientRect();
        if (r.width < 20 || r.height < 16 || r.top < 50) continue;
        let p = el;
        let matched = false;
        for (let i = 0; i < 8 && p; i += 1) {
          const ptext = (p.innerText || '').replace(/\s+/g, ' ').trim().toLowerCase();
          if (ptext.includes(needle) && /₹/.test(ptext) && ptext.length < 220) {
            matched = true;
            break;
          }
          p = p.parentElement;
        }
        if (!matched) continue;
        const score = r.width; // prefer the outer Add chip (~72px) over inner text (~34px)
        if (!best || score > best.score) {
          best = {
            x: r.left + Math.min(26, r.width * 0.4),
            y: r.top + r.height / 2,
            score,
          };
        }
      }
      return best;
    }, short)
    .catch(() => null);

  if (target) {
    const net = [];
    const onResp = async (res) => {
      try {
        const u = res.url();
        if (/flixcart\.com\/(image|batch)|rukminim|static-assets|google|facebook|omniture|doubleclick|\.png|\.jpg|\.woff|\.css/i.test(u)) {
          return;
        }
        if (!/flipkart|flixcart|1mg|minutes|mapi|cart|grocery|hyperlocal/i.test(u)) return;
        net.push({ status: res.status(), url: u.slice(0, 220), method: res.request().method() });
      } catch {
        /* ignore */
      }
    };
    page.on('response', onResp);

    // Prefer invoking the React press/click handler (Flipkart often ignores synthetic geometry misses).
    const reacted = await page
      .evaluate(({ x, y }) => {
        const el = document.elementFromPoint(x, y);
        if (!el) return { ok: false, reason: 'no-el' };
        const fake = {
          bubbles: true,
          cancelable: true,
          view: window,
          clientX: x,
          clientY: y,
          isTrusted: true,
          preventDefault() {},
          stopPropagation() {},
          nativeEvent: { isTrusted: true },
        };
        let cur = el;
        for (let i = 0; i < 12 && cur; i += 1) {
          const rk = Object.keys(cur).find(
            (k) => k.startsWith('__reactProps$') || k.startsWith('__reactEventHandlers$'),
          );
          if (rk && cur[rk]) {
            const p = cur[rk];
            for (const name of ['onClick', 'onPress', 'onPressIn', 'onPointerUp', 'onMouseUp']) {
              if (typeof p[name] === 'function') {
                try {
                  p[name](fake);
                  return { ok: true, via: name, tag: cur.tagName, cls: String(cur.className || '').slice(0, 40) };
                } catch (e) {
                  return { ok: false, reason: String(e).slice(0, 80) };
                }
              }
            }
          }
          // Also try fiber memoizedProps
          const fk = Object.keys(cur).find((k) => k.startsWith('__reactFiber$'));
          if (fk && cur[fk]) {
            let fiber = cur[fk];
            for (let d = 0; d < 10 && fiber; d += 1) {
              const mp = fiber.memoizedProps || {};
              for (const name of ['onClick', 'onPress', 'onPressIn']) {
                if (typeof mp[name] === 'function') {
                  try {
                    mp[name](fake);
                    return { ok: true, via: `fiber.${name}`, tag: cur.tagName };
                  } catch (e) {
                    return { ok: false, reason: String(e).slice(0, 80) };
                  }
                }
              }
              fiber = fiber.return;
            }
          }
          cur = cur.parentElement;
        }
        el.click();
        return { ok: true, via: 'dom.click' };
      }, { x: target.x, y: target.y })
      .catch((e) => ({ ok: false, reason: String(e) }));

    await page.waitForTimeout(1600);
    // If a size / pack sheet opened, tap confirm Add inside it
    try {
      const sheetAdd = page
        .locator('[role="dialog"], [class*="modal"], [class*="sheet"], [class*="popup"]')
        .getByText(/^add$/i)
        .first();
      if (await sheetAdd.isVisible({ timeout: 700 }).catch(() => false)) {
        await sheetAdd.click({ force: true });
        await page.waitForTimeout(1200);
      }
      const confirmAdd = page.getByRole('button', { name: /^add$/i }).first();
      if (await confirmAdd.isVisible({ timeout: 500 }).catch(() => false)) {
        await confirmAdd.click({ force: true });
        await page.waitForTimeout(1200);
      }
    } catch {
      /* ignore */
    }
    const afterUi = await page
      .evaluate(() => {
        const t = (document.body?.innerText || '').replace(/\s+/g, ' ').trim();
        return {
          hasDialog: Boolean(document.querySelector('[role="dialog"]')),
          snippet: t.slice(0, 500),
          addCount: Array.from(document.querySelectorAll('div,button,span')).filter((el) =>
            /^add$/i.test((el.textContent || '').trim()),
          ).length,
        };
      })
      .catch(() => null);
    try {
      const fs = await import('fs');
      const path = await import('path');
      const { config } = await import('../config.js');
      fs.writeFileSync(
        path.join(config.dataDir, 'add-net.json'),
        JSON.stringify({ target, reacted, net, afterUi, url: page.url() }, null, 2),
      );
    } catch {
      /* ignore */
    }
    if (await pageLooksAdded(page)) {
      page.off('response', onResp);
      return true;
    }

    await page.mouse.move(target.x, target.y);
    await page.waitForTimeout(100);
    try {
      await page.touchscreen.tap(target.x, target.y);
      await page.waitForTimeout(1400);
      if (await pageLooksAdded(page)) {
        page.off('response', onResp);
        return true;
      }
    } catch {
      /* no touch */
    }
    await realMouseClick(page, target.x, target.y);
    await page.waitForTimeout(1400);
    page.off('response', onResp);
    if (await pageLooksAdded(page)) return true;
  }

  // Playwright text locator fallback
  try {
    const escaped = short.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const cards = page.locator('div').filter({ hasText: new RegExp(escaped, 'i') });
    const n = Math.min(await cards.count(), 10);
    for (let i = 0; i < n; i += 1) {
      const card = cards.nth(i);
      const box = await card.boundingBox().catch(() => null);
      if (!box || box.height > 420 || box.height < 40 || box.width < 80) continue;
      const add = card.getByText(/^add$/i).first();
      if (!(await add.isVisible({ timeout: 400 }).catch(() => false))) continue;
      await add.scrollIntoViewIfNeeded().catch(() => {});
      const ab = await add.boundingBox().catch(() => null);
      if (ab) {
        await realMouseClick(page, ab.x + Math.min(26, ab.width * 0.4), ab.y + ab.height / 2);
      } else {
        await add.click({ force: true, timeout: 4000 });
      }
      await page.waitForTimeout(1200);
      if (await pageLooksAdded(page)) return true;
    }
  } catch {
    /* next */
  }

  if (product?.addX && product?.addY) {
    await realMouseClick(page, product.addX - 10, product.addY);
    await page.waitForTimeout(1200);
    if (await pageLooksAdded(page)) return true;
  }

  return pageLooksAdded(page);
}

async function productStillHasAdd(page, productName) {
  const short = String(productName || '')
    .toLowerCase()
    .replace(/\d+%\s*off/g, ' ')
    .trim()
    .slice(0, 16);
  return page
    .evaluate((needle) => {
      for (const el of document.querySelectorAll('div')) {
        const text = (el.innerText || '').replace(/\s+/g, ' ').trim().toLowerCase();
        if (!text.includes(needle) || !/₹/.test(text) || text.length > 220) continue;
        const r = el.getBoundingClientRect();
        if (r.height > 420 || r.height < 40) continue;
        if (/\badd\b/i.test(text) && !/[−\-–]\s*[1-9]|[1-9]\s*[+＋]/.test(text)) return true;
      }
      return false;
    }, short)
    .catch(() => true);
}

async function clickAdd(page, product) {
  if (!product) return false;
  try {
    await page.bringToFront();
  } catch {
    /* ignore */
  }
  const beforeHadAdd = await productStillHasAdd(page, product.name);
  const ok = await clickAddButtonNear(page, product);
  if (ok) return true;

  // Detect success by card switching from Add → qty stepper
  await page.waitForTimeout(800);
  const stillAdd = await productStillHasAdd(page, product.name);
  if (beforeHadAdd && !stillAdd) return true;

  // Open product from card link then add on PDP if grid Add is blocked
  try {
    const short = String(product.name || '')
      .replace(/\d+%\s*Off/gi, '')
      .trim()
      .slice(0, 20);
    const escaped = short.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const link = page.locator('a').filter({ hasText: new RegExp(escaped, 'i') }).first();
    if (await link.isVisible({ timeout: 800 }).catch(() => false)) {
      await link.click({ timeout: 4000 }).catch(() => {});
      await page.waitForTimeout(1800);
      await dismissPopups(page);
      const pdpAdd = page.getByText(/^add$/i).first();
      if (await pdpAdd.isVisible({ timeout: 2000 }).catch(() => false)) {
        const ab = await pdpAdd.boundingBox();
        if (ab) await realMouseClick(page, ab.x + 20, ab.y + ab.height / 2);
        else await pdpAdd.click({ force: true });
        await page.waitForTimeout(1500);
        if (await pageLooksAdded(page)) return true;
      }
    }
  } catch {
    /* ignore */
  }

  // Cart check — only success if real line items exist
  const searchUrl = page.url();
  try {
    await page.goto(MINUTES_CART, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForTimeout(1500);
    const cartText = await page.evaluate(() =>
      (document.body?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 2000),
    );
    const empty =
      /your cart is empty|missing cart items|cart is empty/i.test(cartText) ||
      !/\bremove\b|place order/i.test(cartText);
    if (!empty) return true;
    await page.goto(searchUrl, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForTimeout(1500);
  } catch {
    /* ignore */
  }
  return false;
}

function proposeAlternatives(wanted, brand, alts) {
  const cat = categoryFromQuery(wanted);
  const label = brand || wanted;
  const catSpeak = cat === 'item' ? 'similar product' : cat;
  remember({
    kind: 'minutes_alts',
    source: 'flipkart_minutes',
    brand: brand || '',
    query: wanted,
    options: alts,
    text: alts.map((a) => a.name).join('\n'),
  });
  const altLine = alts
    .map((a, i) => `${i + 1}. ${a.name}${a.price ? ` at ${a.price}` : ''}`)
    .join('. ');
  return confirmGate.propose({
    kind: 'flipkart_alt',
    query: wanted,
    brand: brand || '',
    options: alts,
    spokenPrompt: `${label} is not available on Flipkart Minutes right now. Should I add any other ${catSpeak}? There are a few similar options: ${altLine}. Say add option 1, or cancel.`,
  });
}

export async function prepareFlipkartMinutesOrder(query) {
  const wanted = (query || 'milk').trim().replace(/\s+/g, ' ');
  const brand = brandFromQuery(wanted);
  const searchQ = searchQueryFor(wanted);
  const page = await browserAgent.ensure();
  await openMinutesSearch(page, searchQ);

  let products = await scanProducts(page);
  if (products.length < 2) {
    await page.waitForTimeout(1500);
    products = await scanProducts(page);
  }

  remember({
    kind: 'minutes_catalog',
    source: 'flipkart_minutes',
    query: wanted,
    text: products.map((p) => `${p.name} ${p.price}`).join('\n'),
  });

  if (!products.length) {
    return {
      spoken: `I opened Flipkart Minutes and searched for ${wanted}, but I could not see products. Check your pin code in the Minutes window, then try again.`,
      ok: true,
      meta: { products: [], url: page.url() },
    };
  }

  const relevant = filterRelevant(products, wanted);
  const ranked = relevant
    .map((p) => ({ ...p, score: scoreProduct(p, wanted) }))
    .sort((a, b) => b.score - a.score);

  // Brand or exact ask missing → offer similar for ANY product category.
  if (brand) {
    const brandHits = ranked.filter((p) =>
      new RegExp(brand.replace(/\s+/g, '\\s*'), 'i').test(p.name),
    );
    if (!brandHits.length) {
      const alts = ranked.slice(0, 3);
      const pending = proposeAlternatives(wanted, brand, alts);
      await browserAgent.screenshot();
      return {
        spoken: pending.spokenPrompt,
        pending,
        ok: true,
        meta: { brandMissing: true, brand, alts, url: page.url() },
      };
    }
  } else if (!ranked.length || ranked[0].score < 4) {
    const alts = ranked.slice(0, 3);
    if (alts.length) {
      const pending = proposeAlternatives(wanted, '', alts);
      await browserAgent.screenshot();
      return {
        spoken: pending.spokenPrompt,
        pending,
        ok: true,
        meta: { weakMatch: true, alts, url: page.url() },
      };
    }
  }

  const best = ranked[0];
  const added = await clickAdd(page, best);
  await browserAgent.screenshot();
  const pending = confirmGate.propose({
    kind: 'flipkart_place',
    query: best.name,
    product: best,
    spokenPrompt: added
      ? `On Flipkart Minutes I added ${best.name}${best.price ? ` for ${best.price}` : ''}. Say confirm to open the Minutes cart, or say remove it. I will not pay.`
      : `On Flipkart Minutes I found ${best.name}${best.price ? ` for ${best.price}` : ''}, but Add may need one tap. Say confirm to open cart, or cancel.`,
  });
  return {
    spoken: pending.spokenPrompt,
    pending,
    ok: true,
    meta: { added, picked: best, ranked: ranked.slice(0, 5), url: page.url() },
  };
}

export async function addMinutesAlternative(args) {
  const input = args && typeof args === 'object' ? args : {};
  let optionIndex = Number(input.optionIndex);
  if (!Number.isFinite(optionIndex) || optionIndex < 0) optionIndex = -1;
  const hint = String(input.nameHint || input.query || '').trim();

  // "add option 1" / "1" → index 0
  if (optionIndex < 0 && /^\d+$/.test(hint)) {
    optionIndex = Math.max(0, Number(hint) - 1);
  }
  if (optionIndex < 0 && /option\s*(\d+)/i.test(hint)) {
    optionIndex = Math.max(0, Number(hint.match(/option\s*(\d+)/i)[1]) - 1);
  }
  if (optionIndex < 0) optionIndex = 0;

  const pending = confirmGate.get();
  const mem = recall();
  const options =
    (pending && pending.kind === 'flipkart_alt' && pending.options) ||
    (mem && mem.kind === 'minutes_alts' && mem.options) ||
    [];

  if (pending && pending.kind === 'flipkart_alt') confirmGate.clear();

  let pick = options[optionIndex] || options[0];
  if (hint && options.length && !/^\d+$|^option\s*\d+/i.test(hint)) {
    const h = hint.toLowerCase();
    const found = options.find((o) =>
      String(o.name || '')
        .toLowerCase()
        .includes(h.slice(0, 12)),
    );
    if (found) pick = found;
  }

  if (!pick) {
    return {
      spoken:
        'I do not have alternative options saved. Ask again for the product on Flipkart Minutes.',
      ok: true,
    };
  }

  const page = await browserAgent.ensure();

  // Try current page first (alts were just listed here).
  let products = await scanProducts(page);
  const needle = String(pick.name || '')
    .toLowerCase()
    .replace(/\d+%\s*off/g, ' ')
    .trim()
    .slice(0, 18);
  let match =
    products.find((p) => String(p.name).toLowerCase().includes(needle.slice(0, 14))) ||
    null;

  if (!match || !match.hasAdd) {
    const searchBits = cleanSearchFromName(pick.name) || 'milk';
    await openMinutesSearch(page, searchBits);
    products = await scanProducts(page);
    const ranked = products
      .map((p) => ({ ...p, score: scoreProduct(p, pick.name) }))
      .sort((a, b) => b.score - a.score);
    match =
      ranked.find((p) =>
        String(p.name)
          .toLowerCase()
          .includes(needle.slice(0, 12)),
      ) ||
      ranked[0] ||
      null;
  }

  if (!match) {
    return {
      spoken: `I could not find ${pick.name} again on Minutes. Try another option.`,
      ok: true,
    };
  }

  const added = await clickAdd(page, match);
  await browserAgent.screenshot();
  const next = confirmGate.propose({
    kind: 'flipkart_place',
    query: match.name,
    product: match,
    spokenPrompt: added
      ? `Added ${match.name} on Flipkart Minutes. Say confirm to open the cart, or remove it.`
      : `Found ${match.name}. Say confirm to open cart — you may need to tap Add once.`,
  });
  return { spoken: next.spokenPrompt, pending: next, ok: true, meta: { added, match } };
}

export async function executeFlipkartConfirm() {
  const page = await browserAgent.ensure();
  try {
    const go = page.getByText(/go to cart|view cart/i).first();
    if (await go.isVisible({ timeout: 1200 }).catch(() => false)) {
      await go.click({ timeout: 4000 });
      await page.waitForTimeout(1500);
    }
  } catch {
    /* fall through */
  }
  await page.goto(MINUTES_CART, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(2000);
  await dismissPopups(page);
  if (/GROCERY/i.test(page.url())) {
    await page.goto(MINUTES_CART, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(1200);
  }
  assertMinutes(page.url());
  await browserAgent.screenshot();
  return readMinutesCart();
}

export async function readMinutesCart() {
  const page = await browserAgent.ensure();
  if (!/viewcart/i.test(page.url())) {
    await page.goto(MINUTES_CART, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(1800);
  }
  assertMinutes(page.url());
  const info = await page.evaluate(() => {
    const cartText = (document.body?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 2500);
    const emptyPhrase =
      /your cart is empty|missing cart items|cart is empty|no items in your cart/i.test(
        cartText,
      );
    const hasRemove = /\bremove\b/i.test(cartText);
    const hasPlaceOrder = /place order|continue to|proceed to checkout/i.test(cartText);
    // Ignore promo ₹ (Paytm banner); require remove/place-order for a real cart.
    const hasItems = hasRemove || hasPlaceOrder;
    return { cartText, emptyPhrase, hasItems };
  });
  remember({
    kind: 'minutes_cart',
    source: 'flipkart_minutes',
    text: info.cartText,
  });
  const empty = info.emptyPhrase || !info.hasItems;
  if (empty) {
    return {
      spoken: 'Your Flipkart Minutes cart is empty right now.',
      meta: { empty: true, url: page.url() },
      ok: true,
    };
  }
  const bits =
    info.cartText.match(
      /(?:nandini|amul|heritage|milky mist|mother dairy|toned milk|full cream|[A-Z][a-z]+.{0,40}milk)[^.]{0,40}₹?\s?[\d,]*/gi,
    ) || [];
  const hint = bits[0]
    ? bits[0].replace(/\s+/g, ' ').trim().slice(0, 140)
    : info.cartText.replace(/Categories Account More Cart.{0,200}/i, '').trim().slice(0, 180);
  return {
    spoken: `Flipkart Minutes cart is open. I see: ${hint}. Say remove it if you want it taken out, or pay manually if correct.`,
    meta: { empty: false, url: page.url() },
    ok: true,
  };
}

export async function removeFromMinutesCart(itemHint = '') {
  const page = await browserAgent.ensure();
  await page.goto(MINUTES_CART, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(2000);
  await dismissPopups(page);
  assertMinutes(page.url());

  const hint = String(itemHint || '').trim();
  let removed = false;

  try {
    if (hint) {
      const row = page
        .locator('div, li, a')
        .filter({
          hasText: new RegExp(
            hint.slice(0, 16).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'),
            'i',
          ),
        })
        .first();
      const rem = row.getByText(/remove|delete/i).first();
      if (await rem.isVisible({ timeout: 2000 }).catch(() => false)) {
        await rem.click({ timeout: 4000 });
        removed = true;
      }
    }
  } catch {
    /* fall through */
  }

  if (!removed) {
    try {
      const rem = page.getByText(/^remove$/i).first();
      if (await rem.isVisible({ timeout: 2500 }).catch(() => false)) {
        await rem.click({ timeout: 4000 });
        removed = true;
      }
    } catch {
      /* ignore */
    }
  }

  try {
    const yes = page.getByRole('button', { name: /remove|yes|confirm/i }).first();
    if (await yes.isVisible({ timeout: 1500 }).catch(() => false)) {
      await yes.click();
      removed = true;
    }
  } catch {
    /* ignore */
  }

  await page.waitForTimeout(1200);
  await browserAgent.screenshot();
  const after = await readMinutesCart();
  return {
    spoken: removed
      ? `I removed ${hint || 'the item'} from Flipkart Minutes cart. ${after.spoken}`
      : `I could not tap Remove clearly. ${after.spoken} You can tap Remove in the Minutes window.`,
    ok: true,
    meta: { removed, ...(after.meta || {}) },
  };
}

export const prepareFlipkartOrder = prepareFlipkartMinutesOrder;
