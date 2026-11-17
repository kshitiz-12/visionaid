/**
 * Offline-first bilingual intent router (EN + HI).
 * Gemini is only used later for summarization, not for routing.
 */

const PATTERNS = [
  {
    type: 'screen_read',
    re: /\b(what('?s| is) on (my )?screen|read (the )?screen|what do you see|describe (the )?page|screen pe kya|kya dikh|स्क्रीन|क्या दिख)\b/i,
  },
  {
    type: 'summarize',
    re: /\b(summarize|summary|summarise|सारांश|samansh|summary batao)\b/i,
  },
  {
    type: 'pdf_summarize',
    re: /\b(pdf|document|marksheet|resume|cv)\b/i,
  },
  {
    type: 'confirm',
    re: /^(confirm|yes|yeah|yep|ok|okay|haan|haa|हां|हाँ|जी|sahi|theek|place order|send it|go ahead)$/i,
  },
  {
    type: 'cancel',
    re: /^(cancel|no|nope|nahi|नहीं|ना|stop|abort|mat|रद्द)$/i,
  },
  {
    type: 'gmail_open',
    re: /\b(open gmail|gmail khol|gmail open|जीमेल\s*खोल|जीमेल)\b/i,
  },
  {
    type: 'gmail_unread',
    re: /\b(any (new )?mail|unread|new email|emails?|inbox|mail aayi|नया मेल|ईमेल)\b/i,
  },
  {
    type: 'whatsapp_open',
    re: /\b(open whatsapp|whatsapp khol|व्हाट्सऐप\s*खोल|व्हाट्सएप)\b/i,
  },
  {
    type: 'whatsapp_send',
    re: /\b(whatsapp|message|msg|भेजो|बोलो)\b/i,
  },
  {
    type: 'swiggy_order',
    re: /\b(swiggy|order food|खाना|maggi|pizza|burger|biryani|food order)\b/i,
  },
  {
    type: 'flipkart_order',
    re: /\b(flipkart|minutes|grocery|दूध|milk|bread|atta|rice)\b/i,
  },
  {
    type: 'open_url',
    re: /\b(open|khol|खोल)\s+(https?:\/\/\S+|google|youtube|maps)\b/i,
  },
  {
    type: 'pending_status',
    re: /\b(pending|waiting|confirm (kya|status)|क्या पेंडिंग)\b/i,
  },
  {
    type: 'help',
    re: /\b(help|what can you do|commands|मदद|कमांड|help me)\b/i,
  },
];

export function parseIntent(spoken) {
  const text = (spoken || '').trim();
  if (!text) {
    return { type: 'unknown', raw: text, slots: {} };
  }

  // Prefer explicit confirm/cancel as whole utterance.
  for (const row of PATTERNS) {
    if ((row.type === 'confirm' || row.type === 'cancel') && row.re.test(text)) {
      return { type: row.type, raw: text, slots: {} };
    }
  }

  for (const row of PATTERNS) {
    if (row.type === 'confirm' || row.type === 'cancel') continue;
    if (row.re.test(text)) {
      return { type: row.type, raw: text, slots: extractSlots(row.type, text) };
    }
  }
  return { type: 'unknown', raw: text, slots: {} };
}

function extractSlots(type, text) {
  const slots = {};
  if (type === 'whatsapp_send') {
    const m =
      text.match(
        /(?:whatsapp|message|msg)\s+(?:to\s+)?(\w[\w\s]{0,40}?)(?:\s+say|\s+bol|:|\s+ki|\s+कि)\s+(.+)$/i,
      ) ||
      text.match(
        /(?:send|bhejo|भेजो)\s+(.+?)\s+(?:on whatsapp|whatsapp|को)\s*:?\s*(.*)$/i,
      );
    if (m) {
      slots.contact = (m[1] || '').trim();
      slots.body = (m[2] || '').trim();
    } else {
      slots.contact = '';
      slots.body = text;
    }
  }
  if (type === 'swiggy_order') {
    const m = text.match(
      /(?:order|swiggy|manga[o]|मंग[ाो]|खोल)\s+(?:me\s+)?(.+?)(?:\s+on\s+swiggy|$)/i,
    );
    let q = (m?.[1] || text).replace(/swiggy/ig, '').replace(/order/ig, '').trim();
    slots.query = q || 'maggi';
  }
  if (type === 'flipkart_order') {
    const m = text.match(
      /(?:order|get|buy|flipkart|minutes)\s+(.+?)(?:\s+on\s+flipkart|$)/i,
    );
    let q = (m?.[1] || text)
      .replace(/flipkart|minutes|grocery/gi, '')
      .trim();
    slots.query = q || 'milk';
  }
  if (type === 'open_url') {
    if (/google/i.test(text)) slots.url = 'https://www.google.com';
    else if (/youtube/i.test(text)) slots.url = 'https://www.youtube.com';
    else if (/maps/i.test(text)) slots.url = 'https://maps.google.com';
    else {
      const u = text.match(/https?:\/\/\S+/);
      slots.url = u ? u[0] : 'https://www.google.com';
    }
  }
  return slots;
}

export function helpText() {
  return [
    'VoiceWeb Agent commands:',
    'What’s on my screen?',
    'Open Gmail. Any new mail?',
    'Open WhatsApp. Message Mom say I will call at five — then confirm.',
    'Order Maggi on Swiggy — then say confirm.',
    'Get milk on Flipkart — then say confirm.',
    'Summarize this page. Or upload a PDF in the app.',
    'Cancel. Help. Emergency from the SOS button.',
  ].join(' ');
}
