import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';

export async function prepareFlipkartOrder(query) {
  const q = (query || 'milk').trim();
  // Minutes often redirects; main site search is more stable for demos.
  await browserAgent.navigate('https://www.flipkart.com/');
  const page = await browserAgent.ensure();

  try {
    const close = page.locator('button._2KpZ6l._2doB4z');
    if (await close.isVisible({ timeout: 2000 }).catch(() => false)) {
      await close.click().catch(() => {});
    }
  } catch {
    /* login modal */
  }

  try {
    const search = page.getByPlaceholder(/search/i).first();
    await search.fill(q);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2500);
  } catch {
    await browserAgent.type('Search for Products', q, { pressEnter: true });
  }

  try {
    const add = page.getByText(/add to cart/i).first();
    if (await add.isVisible({ timeout: 5000 }).catch(() => false)) {
      await add.click();
      await page.waitForTimeout(1000);
    }
  } catch {
    /* ignore */
  }

  await browserAgent.screenshot();
  const pending = confirmGate.propose({
    kind: 'flipkart_place',
    query: q,
    spokenPrompt: `Flipkart search for ${q} is ready. Say confirm to open cart/checkout, or cancel. I will not pay without confirm.`,
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
      'Flipkart cart is open. Check items, then pay manually if correct. Say what’s on my screen for a readout.',
  };
}
