# VisionAid++ — Exact Product Flow

No login. No OTP.

## 1. First open — language

TTS (English): “Welcome to VisionAid. Which language do you prefer?”  
User picks **English** or **Hindi**.

## 2. Simple profile setup

- Name  
- Emergency contact phone  
Saved on device only.

## 3. Voice Home

TTS: “VisionAid is ready. How can I help?”  
User speaks commands.

## 4–8. Pipeline (next builds)

Speech → Intent → Vision/OCR/… → **Context Engine** → TTS  

Camera/YOLO comes after Supabase DB is healthy on Render.
