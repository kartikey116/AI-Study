# Development Roadmap

## Phase 0: Project Discovery & Architecture (Current)
- [x] Repository analysis
- [x] Architectural design (Monolith + Flutter)
- [x] Database ERD & Schema planning
- [x] API specification
- [x] AI architecture definition
- [x] UI Design System definition

## Phase 1: Foundation & Setup
- Initialize Flutter project (Riverpod, GoRouter, core theme).
- Initialize Node.js/TypeScript backend (Express/NestJS, Prisma, PostgreSQL).
- Set up Docker & Docker Compose for local dev (DB, Redis).
- Implement Authentication (JWT, UI Login/Register).
- Build basic Home Dashboard UI (static/mock data).

## Phase 2: AI Chat Foundation
- Backend Chat API with SSE streaming.
- LLM Provider integration (OpenAI/Gemini).
- Flutter Chat UI (Message bubbles, input, streaming support).
- Save conversation history to DB.

## Phase 3: Document Processing & RAG
- S3 / R2 storage integration.
- Document upload flow (Pre-signed URLs).
- BullMQ Background workers for PDF processing (Extraction, Chunking).
- pgvector embedding generation and storage.
- RAG Agent implementation (Hybrid search, Context injection).
- UI for uploading and viewing documents.

## Phase 4: Quizzes & Flashcards
- AI Prompts for structured Quiz/Flashcard generation.
- Backend modules for Quizzes and Spaced Repetition logic.
- Flutter UI for taking Quizzes and swiping Flashcards.
- Adaptive learning tracking (Topic mastery scores).

## Phase 5: Study Planner & Focus Timer
- AI Study Planner generation based on goals.
- Local SQLite integration in Flutter for Focus Timer.
- Pomodoro timer UI and background execution.
- Sync offline sessions to backend.

## Phase 6: Voice & Advanced AI
- Voice-to-text integration for chat.
- "Deep Think" mode routing to premium models.
- AI Study Tip periodic generation.

## Phase 7: Subscriptions & Notifications
- Stripe/RevenueCat integration for Free vs Premium limits.
- Quota tracking service.
- Push notifications for reminders.

## Phase 8: Hardening & Observability
- Logging, error tracking, analytics.
- Rate limiting, security audits, RAG tenant isolation tests.
- Performance tuning (Caching, DB Indexes).

## Phase 9: Production Deployment
- CI/CD pipelines.
- Cloud deployment (Backend, DB, Redis, Flutter build).
- Final App Store / Play Store preparations.
