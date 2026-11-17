import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';

export async function prepareSwiggyOrder(query) {
  const q = (query || 'maggi').trim();
  await browserAgent.navigate('https://www.swiggy.com/');
  const page = await browserAgent.ensure();

  try {
    // Cookie / location banners — best effort dismiss
    const allow = page.getByText(/allow|agree|got it/i).first();
    if (await allow.isVisible({ timeout: 2000 }).catch(() => false)) {
      await allow.click().catch(() => {});
    }
  } catch {
    /* ignore */
  }

  try {
    const search = page.getByPlaceholder(/search/i).first();
    await search.click({ timeout: 8000 });
    await search.fill(q);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2500);
  } catch {
    await browserAgent.type('Search', q, { pressEnter: true });
  }

  // Try add first item
  try {
    const add = page.getByText(/^add$/i).first();
    if (await add.isVisible({ timeout: 5000 }).catch(() => false)) {
      await add.click();
      await page.waitForTimeout(1000);
    }
  } catch {
    /* cart may need manual assist */
  }

  await browserAgent.screenshot();
  const view = await browserAgent.readVisibleText({ maxChars: 2000 });
  const pending = confirmGate.propose({
    kind: 'swiggy_place',
    query: q,
    spokenPrompt: `Swiggy search for ${q} is ready. I will not place the order until you say confirm. Say confirm to continue to cart/checkout, or cancel. Screen hint: ${view.title}.`,
  });

  return { spoken: pending.spokenPrompt, pending, title: view.title };
}

export async function executeSwiggyConfirm() {
  const page = await browserAgent.ensure();
  // Best-effort: open cart
  try {
    await page.getByText(/cart/i).first().click({ timeout: 5000 });
    await page.waitForTimeout(1500);
  } catch {
    /* ignore */
  }
  await browserAgent.screenshot();
  return {
    spoken:
      'Opened Swiggy cart area. Complete payment only if the cart looks correct. Say what’s on my screen to hear the page.',
  };
}
