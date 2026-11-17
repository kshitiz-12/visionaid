# Major project report outline (fill with your college format)

## 1. Title
VoiceWeb Agent: A Voice-Controlled Browser Assistant for Accessible Web Task Automation

## 2. Abstract (≈150 words)
State the problem (visual web UIs), approach (Flutter voice + Playwright browser + confirm gate), modules (Gmail, WhatsApp Web, Swiggy/Flipkart, PDF, SOS), and result (working sideloaded prototype with human-in-the-loop safety).

## 3. Objectives
- Voice interaction in English and Hindi  
- Operate major web services via automated browser  
- Require confirmation before send/pay  
- Provide screen readout and PDF summary  
- Emergency calling from the mobile client  

## 4. Literature / existing systems
TalkBack, Voice Access, screen readers, RPA (Playwright/Selenium), LLM summarization. Position VoiceWeb as **voice + RPA + HITL**, not computer vision navigation.

## 5. System requirements
Hardware: Android phone + PC. Software: Flutter, Node, Chromium. Network: LAN for demo.

## 6. Design
Paste architecture diagram from `ARCHITECTURE.md`. Explain intent router, connectors, confirm gate, audit log.

## 7. Implementation
Modules, APIs (`/api/command`, `/api/pdf/summarize`, `/api/screenshot`), Flutter settings and mirror.

## 8. Testing
Manual test cases: help, gmail open, screen read, swiggy confirm/cancel, pdf, SOS, backend down.

## 9. Results & screenshots
App home, mirror, pending confirm, audit log snippet, settings.

## 10. Limitations & future work
OTP/captcha, site fragility, official Gmail API OAuth, deeper WhatsApp reliability, on-device LLM.

## 11. Conclusion
## 12. References
