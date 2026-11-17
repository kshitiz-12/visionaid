import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';

/** Flipkart Minutes only (quick grocery). Normal Flipkart browse is disabled. */
export async function prepareFlipkartMinutesOrder(query) {
  const q = (query || 'milk').trim();
  // Minutes storefront — falls back to Minutes search URL.
  await browserAgent.navigate(
    `https://www.flipkart.com/search?q=${encodeURIComponent(q)}&marketplace=FLIPKART&as-show=off&as=off`,
  );
  // Try Minutes-specific entry if available in UI.
  const page = await browserAgent.ensure();
  try {
    const minutes = page.getByText(/minutes/i).first();
    if (await minutes.isVisible({ timeout: 2500 }).catch(() => false)) {
      await minutes.click().catch(() => {});
      await page.waitForTimeout(1200);
    }
  } catch {
    /* ignore */
  }

  try {
    const close = page.locator('button._2KpZ6l._2doB4z');
    if (await close.isVisible({ timeout: 1500 }).catch(() => false)) {
      await close.click().catch(() => {});
    }
  } catch {
    /* login modal */
  }

  try {
    const search = page.getByPlaceholder(/search/i).first();
    if (await search.isVisible({ timeout: 2000 }).catch(() => false)) {
      await search.fill(q);
      await page.keyboard.press('Enter');
      await page.waitForTimeout(2000);
    }
  } catch {
    /* already on search */
  }

  await browserAgent.screenshot();
  const pending = confirmGate.propose({
    kind: 'flipkart_place',
    query: q,
    spokenPrompt: `Flipkart Minutes search for ${q} is ready. Say confirm to open cart, or cancel. I will not pay without confirm.`,
  });
  return { spoken: pending.spokenPrompt, pending };
}

export async function executeFlipkartConfirm() {
  const page = await browserAgent.ensure();
  try {
    await page.goto('https://www.flipkart.com/viewcart', {
      waitUntil: 'domcontentloaded',
      timeout: 60000,
    });
  } catch {
    await page.getByText(/cart/i).first().click().catch(() => {});
  }
  await browserAgent.screenshot();
  return {
    spoken:
      'Flipkart Minutes cart is open. Check items, then pay manually if correct.',
  };
}

// Back-compat alias (dispatcher may still import old name briefly)
export const prepareFlipkartOrder = prepareFlipkartMinutesOrder;
