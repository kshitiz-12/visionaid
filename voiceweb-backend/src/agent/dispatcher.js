import { audit } from '../audit.js';
import { logger } from '../logger.js';
import * as flipkart from '../connectors/flipkart.js';
import * as gmail from '../connectors/gmail.js';
import * as swiggy from '../connectors/swiggy.js';
import * as whatsapp from '../connectors/whatsapp.js';
import { browserAgent } from './browserAgent.js';
import { confirmGate } from './confirmGate.js';
import { summarizeText } from './gemini.js';
import { helpText, parseIntent } from './intent.js';

export async function dispatchSpoken(spoken, { pdfText } = {}) {
  const intent = parseIntent(spoken);
  logger.info('intent', { type: intent.type, raw: spoken.slice(0, 120) });
  audit('command', { type: intent.type, raw: spoken.slice(0, 200) });

  try {
    const result = await runIntent(intent, { pdfText, spoken });
    audit('command_ok', {
      type: intent.type,
      spokenPreview: String(result.spoken || '').slice(0, 180),
    });
    return result;
  } catch (error) {
    logger.error('dispatch_failed', { error: String(error.message || error) });
    audit('command_error', { type: intent.type, error: String(error.message || error) });
    return {
      intent,
      spoken: `I hit a problem: ${String(error.message || error)}. Try again, or say help.`,
      ok: false,
    };
  }
}

async function runIntent(intent, { pdfText, spoken }) {
  switch (intent.type) {
    case 'help':
      return { intent, spoken: helpText(), ok: true };

    case 'pending_status': {
      const p = confirmGate.get();
      if (!p) {
        return { intent, spoken: 'Nothing is waiting for confirmation.', ok: true };
      }
      return {
        intent,
        spoken: p.spokenPrompt || `Pending action: ${p.kind}. Say confirm or cancel.`,
        pending: p,
        ok: true,
      };
    }

    case 'screen_read': {
      const view = await browserAgent.readVisibleText();
      const spokenOut = await summarizeText(
        `Page title: ${view.title}. URL: ${view.url}. Text: ${view.text}`,
        {
          hint:
            'Describe what is on screen in 2-4 short sentences for a blind user. Mention important buttons if obvious.',
        },
      );
      return {
        intent,
        spoken: spokenOut,
        meta: { url: view.url, title: view.title },
        ok: true,
      };
    }

    case 'summarize': {
      if (pdfText) {
        const spokenOut = await summarizeText(pdfText, {
          hint: 'Summarize this PDF for a blind student in clear short sentences.',
        });
        return { intent, spoken: spokenOut, ok: true };
      }
      const view = await browserAgent.readVisibleText({ maxChars: 12000 });
      const spokenOut = await summarizeText(view.text);
      return { intent, spoken: spokenOut, meta: { url: view.url }, ok: true };
    }

    case 'pdf_summarize': {
      if (!pdfText) {
        return {
          intent,
          spoken:
            'Use the Upload PDF button in the app, then say summarize. Or open a document in the browser and say summarize this page.',
          ok: true,
        };
      }
      const spokenOut = await summarizeText(pdfText, {
        hint: 'Summarize this PDF clearly for a blind user. List key points.',
      });
      return { intent, spoken: spokenOut, ok: true };
    }

    case 'confirm': {
      const pending = confirmGate.get();
      if (!pending) {
        return { intent, spoken: 'Nothing is waiting for confirmation.', ok: true };
      }
      confirmGate.clear();
      audit('confirm', { kind: pending.kind });
      if (pending.kind === 'whatsapp_send') {
        const r = await whatsapp.executeWhatsAppSend();
        return { intent, spoken: r.spoken, meta: { executed: pending }, ok: true };
      }
      if (pending.kind === 'swiggy_place') {
        const r = await swiggy.executeSwiggyConfirm();
        return { intent, spoken: r.spoken, meta: { executed: pending }, ok: true };
      }
      if (pending.kind === 'flipkart_place') {
        const r = await flipkart.executeFlipkartConfirm();
        return { intent, spoken: r.spoken, meta: { executed: pending }, ok: true };
      }
      return {
        intent,
        spoken: 'Confirmed, but I do not know how to finish that action.',
        ok: false,
      };
    }

    case 'cancel': {
      const was = confirmGate.clear();
      audit('cancel', { kind: was?.kind || null });
      return {
        intent,
        spoken: was ? 'Okay, cancelled.' : 'Nothing to cancel.',
        ok: true,
      };
    }

    case 'gmail_open':
      return { intent, ...(await gmail.openGmail()), ok: true };

    case 'gmail_unread':
      return { intent, ...(await gmail.unreadDigest()), ok: true };

    case 'whatsapp_open':
      return { intent, ...(await whatsapp.openWhatsApp()), ok: true };

    case 'whatsapp_send':
      return {
        intent,
        ...(await whatsapp.draftWhatsAppMessage({
          contact: intent.slots.contact,
          body: intent.slots.body,
        })),
        ok: true,
      };

    case 'swiggy_order':
      return {
        intent,
        ...(await swiggy.prepareSwiggyOrder(intent.slots.query)),
        ok: true,
      };

    case 'flipkart_order':
      return {
        intent,
        ...(await flipkart.prepareFlipkartOrder(intent.slots.query)),
        ok: true,
      };

    case 'open_url': {
      const nav = await browserAgent.navigate(intent.slots.url);
      return {
        intent,
        spoken: `Opened ${nav.title}.`,
        meta: nav,
        ok: true,
      };
    }

    default:
      return {
        intent,
        spoken:
          'I did not catch a known command. Say help. Or try: what’s on my screen, open Gmail, open WhatsApp, order on Swiggy, get milk on Flipkart, summarize.',
        ok: true,
        hint: spoken,
      };
  }
}
