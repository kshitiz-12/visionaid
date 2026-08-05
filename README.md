# VisionAid++

VisionAid++ is a production-grade mobile AI assistant for visually impaired users. It prioritizes accessible voice-first interaction, local inference for privacy-sensitive workloads, and a context-aware decision engine that limits spoken output to the highest-priority information.

## Architecture summary

- Flutter app with feature-first Clean Architecture
- Riverpod state management and GoRouter for navigation
- Node.js + Express backend with repository-based data access
- Firebase Auth + Firebase Cloud Messaging
- MongoDB Atlas for application data
- Cloudinary for media assets
- YOLOv8 TFLite on-device for object detection
- ML Kit OCR for offline text extraction
- Google Maps + ARCore for navigation and depth-aware alerts
- Gemini API only for advanced scene understanding

## Directory structure

- flutter/ — mobile application source code
- backend/ — Node.js API services and infrastructure
- ai/ — AI model scripts and context logic
- docs/ — product and architecture documentation
- scripts/ — automation and deployment helpers
- docker/ — deployment containers
- .github/ — CI/CD workflows

## Core product principle

The novelty is not raw object detection; it is the Adaptive Context-Aware AI Decision Engine that scores detected data by confidence, distance, motion, user intent, object importance, and navigation risk before speaking.

## Git strategy

- main
- develop
- feature/auth
- feature/vision
- feature/ocr
- feature/navigation
- feature/context
- feature/emergency

## Initial execution status

The project skeleton and architectural foundation are in place. The next workstream is the Flutter app shell and the backend service skeleton.
