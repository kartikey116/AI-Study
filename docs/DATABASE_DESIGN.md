# Database Design

## Overview
The primary data store is **PostgreSQL** using **Prisma ORM**. **pgvector** is used for vector storage within the same database to simplify architecture.

## ERD Overview (Logical Schema)

### 1. Identity & Access
- **User**: `id`, `email`, `passwordHash`, `role`, `createdAt`, `updatedAt`
- **Profile**: `userId`, `displayName`, `avatarUrl`, `preferences` (JSON)
- **Device**: `id`, `userId`, `fcmToken`, `platform`, `lastActiveAt`
- **RefreshToken**: `token`, `userId`, `expiresAt`, `isRevoked`
- **Subscription**: `userId`, `planType` (FREE/PREMIUM), `validUntil`, `stripeCustomerId`

### 2. Document & RAG System
- **Document**: `id`, `userId`, `title`, `storageKey` (S3), `status` (UPLOADING/PROCESSING/READY/FAILED), `mimeType`, `sizeBytes`, `createdAt`
- **DocumentChunk**: `id`, `documentId`, `userId`, `chunkIndex`, `text`, `embedding` (vector), `pageNumber`, `chapterMetadata`
  - *Note:* `userId` is duplicated here to ensure strict tenant-isolation on vector searches.

### 3. AI & Chat
- **Conversation**: `id`, `userId`, `title`, `subjectId`, `createdAt`, `updatedAt`
- **Message**: `id`, `conversationId`, `role` (user/assistant/system), `content`, `metadata` (JSON - citations/references), `createdAt`
- **AIUsage**: `id`, `userId`, `provider`, `model`, `inputTokens`, `outputTokens`, `estimatedCost`, `requestType`, `createdAt`

### 4. Learning & Progress
- **StudySubject**: `id`, `userId`, `name`, `colorHex`, `createdAt`
- **Topic**: `id`, `subjectId`, `name`, `masteryScore` (0-100)
- **UserProgress**: Aggregated stats for dashboards.

### 5. Quizzes & Flashcards
- **Quiz**: `id`, `userId`, `subjectId`, `title`, `difficulty`, `createdAt`
- **Question**: `id`, `quizId`, `type` (MCQ/TF), `questionText`, `options` (JSON), `correctAnswer`, `explanation`
- **QuizAttempt**: `id`, `quizId`, `score`, `completedAt`
- **Flashcard**: `id`, `userId`, `frontText`, `backText`, `topicId`
- **FlashcardReview**: `id`, `flashcardId`, `easeFactor`, `interval`, `nextReviewAt`, `reviewCount` (Spaced Repetition tracking)

### 6. Study Planning
- **StudyPlan**: `id`, `userId`, `targetExamDate`, `goal`
- **StudyTask**: `id`, `planId`, `title`, `status`, `durationMinutes`
- **StudySession**: `id`, `userId`, `subjectId`, `startTime`, `endTime`, `focusDuration` (for Pomodoro tracker)

## Performance & Indexing Strategy
- **Vector Index:** HNSW or IVFFlat index on `DocumentChunk.embedding` depending on scale.
- **B-Tree Indexes:** On `userId` across all tenant tables (Documents, Conversations, Quizzes) to speed up scoped lookups.
- **Compound Indexes:** On `(userId, status)` for documents, `(flashcardId, nextReviewAt)` for spaced repetition queries.

## Security & Isolation
- **Row-Level Security (RLS)** is considered if required, but primarily tenant isolation is enforced at the Application/ORM layer by always appending `where: { userId: currentUserId }`.
