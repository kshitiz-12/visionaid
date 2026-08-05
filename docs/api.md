# VisionAid++ API Contract

## Authentication

- POST /auth/login
- POST /auth/register

## User and profile

- GET /profile
- PATCH /profile

## Emergency

- POST /emergency

## History

- GET /history
- POST /history

## Object memory

- POST /object/save
- GET /object/find

## Navigation

- POST /navigation

## OCR

- POST /ocr

## Detection

- POST /detection

## Scene

- POST /scene

## Response conventions

All endpoints use:

- success: true|false
- message: string
- data: object
- error: object|null

## Security

- JWT-based access tokens for protected routes
- Firebase user identity validation for mobile clients
- rate limiting and request validation middleware
- no raw camera frames in backend requests
