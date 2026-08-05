# VisionAid++ Architecture

## Design principles

### 1. Feature-first Clean Architecture

The codebase is split into feature modules. Each feature contains layered responsibilities:

- data
- domain
- presentation

This keeps business logic isolated from UI and infrastructure, which is essential for maintainability and testability.

### 2. Dependency inversion

Upper layers depend on abstractions, not concrete implementations. Repositories are interfaces in the domain layer and implementations are provided via data-layer repositories.

### 3. Voice-first interaction model

The product is designed around voice as the primary mode of interaction. All major flows are accessible without visual input, and the user experience is optimized to reduce cognitive load.

### 4. Privacy-first inference

Object detection happens on-device. No camera frames are transmitted to a server. This supports the offline-first requirement and reduces security exposure.

### 5. Adaptive context-aware prioritization

The Context Engine filters detected objects by priority score before speaking. This is the product’s research contribution and reduces information overload.

## Priority scoring model

The context engine calculates a priority score using:

- confidence
- distance
- motion
- user intent
- object importance
- navigation risk

This produces high-value alerts such as “Person approaching from right” instead of reading every object.

## Layer boundaries

### Flutter layer

- presentation: pages, widgets, providers
- domain: entities, use cases, repository contracts
- data: datasource implementations, models, repository implementations
- core: config, services, constants, theme, exceptions, utils

### Backend layer

- controllers
- routes
- services
- repositories
- middleware
- config
- models

## Why this architecture

This architecture reduces coupling between UI, domain logic, and infrastructure. It allows independent evolution of the AI, voice, and navigation subsystems without forcing cross-cutting changes. It also keeps the product scalable enough for future phases such as location memory, ordering, reminders, and analytics.
