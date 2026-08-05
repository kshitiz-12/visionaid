# VisionAid++ Research Contribution

## Core novelty

The novelty of VisionAid++ is not object detection. It is the adaptive context-aware decision engine that converts raw detection data into a concise, relevant spoken summary.

## Research objective

Reduce cognitive overload for blind or low-vision users by surfacing only the most relevant objects and hazards in context.

## Decision architecture

For each detected object, the system calculates a priority score:

PriorityScore = Confidence + Distance + Motion + UserIntent + ObjectImportance + NavigationRisk

Objects are ranked and only the highest-scoring ones are spoken. The output is shaped by the user’s current task and environment.

## Design rationale

Blind users do not need constant narration of every object. They need prioritized alerts that highlight immediate risks, navigation barriers, and emotionally relevant objects. This reduces both noise and mental fatigue.

## Research phases

- Phase 1: voice assistant, OCR, SOS, object detection
- Phase 2: risk detection, scene description, navigation, memory
- Phase 3: ordering, reminders, analytics, cloud sync

## Privacy and safety

The system is designed to minimize data transmission and operate offline wherever possible. Sensitive scene data remains local unless required for advanced optional AI assistance.
