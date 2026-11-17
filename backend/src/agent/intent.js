/**
 * Offline-first bilingual intent router (EN + HI).
 * Order matters: specific mail/WA reads before broad chat/send patterns.
 */

const PATTERNS = [
  {
    type: 'confirm',
    re: /^(confirm|yes|yeah|yep|ok|okay|haan|haa|हां|हाँ|जी हाँ|sahi|theek hai|place order|send it|go ahead)$/i,
  },
  {
    type: 'cancel',
    re: /^(cancel|no|nope|nahi|नहीं|ना|stop|abort|mat bhejo|रद्द)$/i,
  },
  {
    type: 'help',
    re: /\b(help|what can you do|commands|मदद|कमांड|help me)\b/i,
  },
  {
    type: 'time_now',
    re: /\b(what('?s| is) the time|current time|time (batao|bolo)|समय\s*(क्या|बताओ)|kitna baja|कितना\s*बजा|time kya hai)\b/i,
  },
  {
    type: 'screen_read',
    re: /\b(what('?s| is) on (my )?screen|read (the )?screen|what do you see|describe (the )?page|screen pe kya|स्क्रीन)\b/i,
  },
  {
    type: 'summarize',
    re: /\b(summarize (this )?page|summary of (this )?page|page summary|सारांश)\b/i,
  },
  // Mail — open vs read last (before generic "tell me")
  {
    type: 'gmail_open',
    re: /\b(open (gmail|mail|email|inbox)|gmail (khol|open)|mail kholo?|जीमेल\s*खोल|मेल\s*खोल)\b/i,
  },
  {
    type: 'gmail_last',
    re: /\b((what('?s| is)|tell me|read|check|batao|bolo).{0,24}(last|latest|newest|recent|first).{0,12}(mail|email|e-?mail)|last (mail|email)|first (mail|email)|latest (mail|email)|read (my )?(last )?mail|नया मेल|आखिरी\s*मेल|last mail kya)\b/i,
  },
  {
    type: 'followup_brief',
    re: /\b(tell me in brief|in brief|more detail|more details|read more|explain( that| more)?|full (mail|message)|thoda detail|brief mein|संक्षेप|और\s*बताओ|detail batao)\b/i,
  },
  {
    type: 'gmail_unread',
    re: /\b(any (new )?mail|unread (mail|email)?|new emails?|mail digest|inbox digest|कोई\s*मेल)\b/i,
  },
  {
    type: 'gmail_reply',
    re: /\b(reply\s+(saying|to\s+(this|the)?\s*mail|with)|respond\s+saying|answer\s+(the\s+)?mail)\b/i,
  },
  {
    type: 'gmail_compose',
    re: /\b(compose\s+(a\s+)?(mail|email)|write\s+(a\s+)?(mail|email)|email\s+\w+|send\s+(a\s+)?(mail|email)\s+to)\b/i,
  },
  {
    type: 'gmail_search',
    re: /\b(open\s+(mail|email)\s+from|find\s+(mail|email)|search\s+(mail|email|inbox)|mail\s+from)\b/i,
  },
  {
    type: 'whatsapp_chats',
    re: /\b(who\s+messaged|recent\s+chats|chat\s+list|unread\s+chats|whatsapp\s+chats)\b/i,
  },
  // WhatsApp read last from contact BEFORE send
  {
    type: 'whatsapp_read',
    re: /\b((last|latest)\s+(message|msg|chat)|message\s+from|msg\s+from|whatsapp.{0,30}(from|mummy|mom)|tell me.{0,40}(message|msg)|read.{0,30}(message|msg)).{0,40}(from|of|mummy|mom|papa|dad)?/i,
  },
  {
    type: 'whatsapp_open',
    re: /\b(open whatsapp|whatsapp (khol|open)|व्हाट्सऐप\s*खोल)\b/i,
  },
  {
    type: 'whatsapp_reply',
    re: /\b(reply\s+saying|respond\s+saying|tell\s+them|answer\s+saying)\b/i,
  },
  {
    type: 'whatsapp_send',
    re: /\b((send|bhejo|भेजो).{0,40}whatsapp|whatsapp.{0,40}(send|message|msg|bol|say)|message\s+\w+\s+(say|bol|:)|send\s+.+\s+to\s+\w+)\b/i,
  },
  {
    type: 'swiggy_order',
    re: /\b((order|get).{0,30}swiggy|swiggy.{0,40}(order|maggi|pizza|burger|biryani)|order (maggi|pizza|burger|biryani))\b/i,
  },
  // Flipkart Minutes ONLY — never plain Flipkart / bare "milk"
  {
    type: 'flipkart_minutes',
    re: /\b(flipkart\s*minutes|minutes\s*(pe|par|on)?|fk\s*minutes|फ्लिपकार्ट\s*मिनट्स)\b/i,
  },
  {
    type: 'live_sports',
    re: /\b(cricket|live score|ipl|t20|world cup|क्रिकेट|स्कोर|live match|which match|kaunsa match)\b/i,
  },
  {
    type: 'pending_status',
    re: /\b(pending|waiting for confirm|क्या पेंडिंग)\b/i,
  },
  {
    type: 'open_url',
    re: /\b(open|khol|खोल)\s+(https?:\/\/\S+|google|youtube|maps)\b/i,
  },
  {
    type: 'chat',
    re: /\b(joke|jokes|funny|tell me|who is|what is|why |how |weather|news|fact|चुटकुला|मजाक|batao|bolo)\b/i,
  },
];

export function parseIntent(spoken) {
  const text = (spoken || '').trim().replace(/\s+/g, ' ');
  if (!text) {
    return { type: 'unknown', raw: text, slots: {} };
  }

  // Soft normalize STT flubs for mail
  const soft = text
    .replace(/\b(male|meal|mall|melt)\b/gi, 'mail')
    .replace(/\be[\s-]?mail\b/gi, 'email');

  for (const row of PATTERNS) {
    if ((row.type === 'confirm' || row.type === 'cancel') && row.re.test(soft)) {
      return { type: row.type, raw: text, slots: {} };
    }
  }

  for (const row of PATTERNS) {
    if (row.type === 'confirm' || row.type === 'cancel') continue;
    if (row.re.test(soft)) {
      return { type: row.type, raw: text, slots: extractSlots(row.type, soft) };
    }
  }

  return { type: 'chat', raw: text, slots: {} };
}

function extractSlots(type, text) {
  const slots = {};
  if (
    type === 'whatsapp_send' ||
    type === 'whatsapp_read' ||
    type === 'whatsapp_reply'
  ) {
    const from =
      text.match(
        /(?:from|of|to|को)\s+(mummy|mom|mama|papa|dad|[\w]{2,24})/i,
      ) ||
      text.match(
        /(?:message|msg|chat)\s+(?:from\s+)?(mummy|mom|mama|papa|dad|[\w]{2,24})/i,
      );
    if (from) slots.contact = from[1].trim();
    else if (/mummy|mom|मम्मी/i.test(text)) slots.contact = 'Mom';
    else slots.contact = '';

    if (type === 'whatsapp_send' || type === 'whatsapp_reply') {
      const m =
        text.match(/(?:saying|say|bol|bolke|कि|:)\s+(.+)$/i) ||
        text.match(/message\s+\w+\s+(.+)$/i) ||
        text.match(/tell them\s+(.+)$/i);
      slots.body = (m?.[1] || '').trim();
    }
  }
  if (type === 'gmail_reply') {
    const m = text.match(/(?:saying|say|with|:)\s+(.+)$/i);
    slots.body = (m?.[1] || '').trim();
  }
  if (type === 'gmail_compose') {
    const to =
      text.match(/(?:to|को)\s+([\w.@+-]{2,40})/i) ||
      text.match(/email\s+([\w.@+-]{2,40})/i);
    if (to) slots.to = to[1];
    const m = text.match(/(?:saying|say|about|:)\s+(.+)$/i);
    slots.body = (m?.[1] || '').trim();
  }
  if (type === 'gmail_search') {
    const m =
      text.match(/(?:from|about)\s+(.+)$/i) ||
      text.match(/search\s+(?:mail|email|inbox)\s+(.+)$/i);
    slots.query = (m?.[1] || text).replace(/open|mail|email|from|search|inbox/gi, '').trim();
  }
  if (type === 'swiggy_order') {
    const m = text.match(
      /(?:order|get|swiggy)\s+(?:me\s+)?(.+?)(?:\s+on\s+swiggy|$)/i,
    );
    let q = (m?.[1] || text).replace(/swiggy|order|get|on/gi, '').trim();
    slots.query = q || 'maggi';
  }
  if (type === 'flipkart_minutes') {
    const m = text.match(
      /(?:order|get|buy|minutes)\s+(.+?)(?:\s+on\s+flipkart|\s+from\s+minutes|$)/i,
    );
    let q = (m?.[1] || text)
      .replace(/flipkart|minutes|order|get|buy|from|on/gi, '')
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
    'Tap Listen and speak naturally, like talking to a person.',
    'Mail: open Gmail. What is the last mail. Any unread mail. Tell me in brief. Reply saying thanks. Compose mail to someone saying hello. Open mail from Google.',
    'WhatsApp: open WhatsApp. Who messaged me. Last unread message. Last message from mummy. Tell me in brief. Reply saying I will call you. Send hello to Kshitiz — then confirm.',
    'Ask: what is the time, tell me a joke, cricket live score.',
    'Food: order Maggi on Swiggy — then confirm.',
    'Cancel anytime. Help. SOS for emergency.',
  ].join(' ');
}
