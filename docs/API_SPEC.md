# API Specification

## General Principles
- **Base URL:** `/api/v1`
- **Content-Type:** `application/json`
- **Authentication:** Bearer JWT in the `Authorization` header.
- **Pagination:** Uses `page` and `limit` query params, returning `{ data: [...], meta: { total, page, limit } }`.
- **Standard Error Response:**
  ```json
  {
    "error": {
      "code": "ERROR_CODE_STRING",
      "message": "Human readable message",
      "details": [] 
    }
  }
  ```

## Endpoints

### 1. Authentication (`/auth`)
- `POST /auth/register` - Create a new user.
- `POST /auth/login` - Authenticate and receive JWT + Refresh Token.
- `POST /auth/refresh` - Rotate refresh token.
- `POST /auth/logout` - Revoke tokens.

### 2. User & Dashboard (`/users`)
- `GET /users/me` - Get profile and subscription status.
- `PATCH /users/me` - Update profile data.
- `GET /users/dashboard` - Get aggregated dashboard data (streak, study time, tasks).
- `GET /users/ai-tip` - Get the daily personalized AI study tip.

### 3. Documents (`/documents`)
- `POST /documents/upload-url` - Request a pre-signed S3 URL for PDF upload.
- `POST /documents` - Notify backend that upload is complete; triggers processing job.
- `GET /documents` - List user documents.
- `GET /documents/:id` - Get document details and processing status.
- `DELETE /documents/:id` - Delete document and cascade chunks.

### 4. Chat & AI Tutor (`/chat`)
- `POST /chat` - Send a message. Returns a stream (SSE) for AI generation.
- `GET /conversations` - List chat histories.
- `GET /conversations/:id/messages` - Get messages for a specific conversation.

### 5. Quizzes (`/quizzes`)
- `POST /quizzes/generate` - Trigger AI to generate a quiz based on subject/document.
- `GET /quizzes/:id` - Fetch quiz questions.
- `POST /quizzes/:id/attempts` - Submit quiz answers and calculate score.

### 6. Flashcards (`/flashcards`)
- `POST /flashcards/generate` - Generate flashcards from weak topics or documents.
- `GET /flashcards/review` - Get flashcards due for review today (spaced repetition).
- `POST /flashcards/:id/review` - Submit review result (EASY/HARD/AGAIN) to update SR intervals.

### 7. Study Planner (`/study-plans`)
- `POST /study-plans/generate` - AI generates a schedule based on exam dates.
- `GET /study-plans` - Get current active plan.
- `PATCH /study-tasks/:id` - Mark task as complete.

### 8. Focus Timer (`/sessions`)
- `POST /sessions` - Sync a locally completed focus session to the backend.

## Security & Rate Limiting
- **Rate Limits:** Enforced via Redis.
  - Auth: 5 req/min.
  - Chat/AI Generation: 10-50 req/hour based on subscription.
  - Standard API: 100 req/min.
- **Tenant Isolation:** Every endpoint controller strictly extracts `userId` from the JWT and uses it in database queries.
