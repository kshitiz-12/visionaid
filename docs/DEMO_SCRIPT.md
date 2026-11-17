# 5–7 minute viva demo script

**Before panel enters:** backend running, Chromium logged into Gmail + WhatsApp Web, app Settings saved with API URL + SOS number.

| Time | You do | They should hear / see |
|------|--------|-------------------------|
| 0:00 | Show architecture slide (`ARCHITECTURE.md`) | Clear layers |
| 0:40 | Open app → Listen → “Help” | Spoken command list |
| 1:10 | “Open Gmail” | Browser mirror updates; Gmail opens |
| 1:40 | “Any new mail?” | Spoken digest |
| 2:20 | “What’s on my screen?” | Short description of current page |
| 3:00 | “Order Maggi on Swiggy” | “Say confirm…” (pending) |
| 3:30 | “Confirm” | Cart/checkout step; **no silent pay** |
| 4:10 | Upload PDF → summary spoken | Document understanding |
| 4:50 | SOS chip | Dialer opens with saved contact |
| 5:20 | Limitations slide | Honest: OTP, UI changes, confirm gate |
| 5:50 | Q&A | Point to `/api/audit` evidence log |

## Backup if a site fails

Use chips: Open Google → What’s on my screen → Summarize → SOS. Still shows full pipeline.
