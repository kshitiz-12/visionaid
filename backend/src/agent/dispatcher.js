import { audit } from '../audit.js';
import { logger } from '../logger.js';
import * as flipkart from '../connectors/flipkart.js';
import * as gmail from '../connectors/gmail.js';
import * as swiggy from '../connectors/swiggy.js';
import * as whatsapp from '../connectors/whatsapp.js';
import { browserAgent } from './browserAgent.js';
import { confirmGate } from './confirmGate.js';
import { chatAnswer, speakBrief, summarizeText } from './gemini.js';
import { helpText } from './intent.js';
import {
  recall,
  setActiveApp,
  setLastIntentType,
} from './memory.js';
import { speakSanitize } from './speak.js';
import { understandSpoken } from './understand.js';

export async function dispatchSpoken(spoken, { pdfText } = {}) {
  const intent = await understandSpoken(spoken);
  logger.info('intent', {
    type: intent.type,
    via: intent.via,
    raw: spoken.slice(0, 120),
  });
  audit('command', {
    type: intent.type,
    via: intent.via,
    raw: spoken.slice(0, 200),
  });

  try {
    const result = await runIntent(intent, { pdfText, spoken });
    setLastIntentType(intent.type);
    if (result?.spoken) {
      result.spoken = speakSanitize(result.spoken);
    }
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

    case 'gmail_last':
      return { intent, ...(await gmail.lastMailDigest()), ok: true };

    case 'followup_brief': {
      const mem = recall();
      if (!mem?.text) {
        return {
          intent,
          spoken:
            'I do not have a recent mail or message saved. Say what is the last mail first, then tell me in brief.',
          ok: true,
        };
      }
      if (mem.kind === 'whatsapp') {
        return {
          intent,
          ...(await whatsapp.briefLastWhatsApp(mem.text)),
          ok: true,
        };
      }
      if (mem.kind === 'email' || mem.kind === 'email_list') {
        return {
          intent,
          ...(await gmail.briefLastMail(mem.text)),
          ok: true,
        };
      }
      const spokenOut = await speakBrief(mem.text, { kind: mem.kind || 'page' });
      return { intent, spoken: spokenOut, ok: true };
    }

    case 'gmail_unread':
      return { intent, ...(await gmail.unreadDigest()), ok: true };

    case 'whatsapp_open':
      return { intent, ...(await whatsapp.openWhatsApp()), ok: true };

    case 'whatsapp_read':
      return {
        intent,
        ...(await whatsapp.readLastMessage({
          contact: intent.slots.contact,
        })),
        ok: true,
      };

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
      setActiveApp('swiggy');
      return {
        intent,
        ...(await swiggy.prepareSwiggyOrder(intent.slots.query || 'maggi')),
        ok: true,
      };

    case 'flipkart_minutes':
    case 'flipkart_order':
      setActiveApp('flipkart');
      return {
        intent,
        ...(await flipkart.prepareFlipkartMinutesOrder(
          intent.slots.query || 'milk',
        )),
        ok: true,
      };

    case 'open_url': {
      const target =
        intent.slots.url ||
        (/youtube/i.test(spoken)
          ? 'https://www.youtube.com'
          : /maps/i.test(spoken)
            ? 'https://maps.google.com'
            : 'https://www.google.com');
      const nav = await browserAgent.navigate(target);
      setActiveApp('browser');
      return {
        intent,
        spoken: `Opened ${nav.title}.`,
        meta: nav,
        ok: true,
      };
    }

    case 'time_now': {
      const now = new Date();
      const spokenOut = now.toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
      });
      return {
        intent,
        spoken: `It is ${spokenOut}, India time.`,
        ok: true,
      };
    }

    case 'live_sports': {
      const q = encodeURIComponent(spoken || 'live cricket score');
      await browserAgent.navigate(`https://www.google.com/search?q=${q}&hl=en`);
      const view = await browserAgent.readVisibleText({ maxChars: 9000 });
      const spokenOut = await chatAnswer(spoken, {
        pageContext: `Title: ${view.title}\nURL: ${view.url}\nText: ${view.text}`,
        nowIso: new Date().toISOString(),
      });
      return {
        intent,
        spoken: spokenOut,
        meta: { url: view.url, title: view.title },
        ok: true,
      };
    }

    case 'chat': {
      const spokenOut = await chatAnswer(spoken, {
        nowIso: new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }),
      });
      return { intent, spoken: spokenOut, ok: true };
    }

    default: {
      const spokenOut = await chatAnswer(spoken, {
        nowIso: new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }),
      });
      return { intent, spoken: spokenOut, ok: true };
    }
  }
}
