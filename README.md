# 🎓 StudyAI — Intelligent AI Study Companion

<p align="center">
  <img src="img/homesc.jpg" width="280" alt="StudyAI Home Screen" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="img/aiTutor.jpg" width="280" alt="StudyAI AI Tutor Screen" />
</p>

<p align="center">
  <b>Transform your study materials into an interactive, personalized learning powerhouse.</b><br/>
  Powered by Flutter, Node.js, Express, Prisma, Supabase (pgvector), and Google Gemini.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" />
  <img src="https://img.shields.io/badge/TypeScript-5.x-3178C6?style=for-the-badge&logo=typescript&logoColor=white" />
  <img src="https://img.shields.io/badge/Prisma-ORM-2D3748?style=for-the-badge&logo=prisma&logoColor=white" />
  <img src="https://img.shields.io/badge/PostgreSQL-Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" />
  <img src="https://img.shields.io/badge/Google-Gemini_AI-8E75C2?style=for-the-badge&logo=google&logoColor=white" />
</p>

---

## 📖 Table of Contents
1. [Overview](#-overview)
2. [Screenshots & Visual Tour](#-screenshots--visual-tour)
3. [Key Features](#-key-features)
4. [How to Use Guide](#-how-to-use-guide)
5. [Architecture & Tech Stack](#-architecture--tech-stack)
6. [Project Structure](#-project-structure)
7. [Installation & Setup](#-installation--setup)
8. [Security & GitHub Verification](#-security--github-verification)
9. [License](#-license)

---

## 🌟 Overview

**StudyAI** is an all-in-one AI study companion mobile app built for students and lifelong learners. Instead of passively reading hundreds of pages of PDF textbooks, students can upload their study materials and instantly:
- **Chat with a specialized AI Tutor** grounded in their uploaded PDFs with real-time SSE streaming.
- **Generate AI practice quizzes** with multiple difficulties, instant scoring, and step-by-step explanations.
- **Memorize key concepts with flashcards** powered by a SuperMemo-style spaced repetition algorithm.
- **Build personalized 7-day study schedules** tailored to their upcoming exams and targets.
- **Track focus sessions** with a built-in Pomodoro timer and gamified analytics (study time, streaks, learner level).

---

## 📱 Screenshots & Visual Tour

| Home Dashboard | AI Tutor (Streaming Chat) | Documents & Notes |
| :---: | :---: | :---: |
| <img src="img/homesc.jpg" width="260" alt="Home Dashboard" /> | <img src="img/aiTutor.jpg" width="260" alt="AI Tutor Chat" /> | <img src="img/doc.jpg" width="260" alt="Documents Library" /> |
| *Stats, Mascot, Quick Actions & Recent Quizzes* | *Streaming responses, context pill & prompt chips* | *PDF uploads, chunk processing status* |

| 7-Day Study Schedule | Interactive Quiz Test | Quiz History & Scores |
| :---: | :---: | :---: |
| <img src="img/study_plan.jpg" width="260" alt="Study Plan" /> | <img src="img/QuizScreen.jpg" width="260" alt="Quiz Screen" /> | <img src="img/myquizess.jpg" width="260" alt="Quiz History" /> |
| *Personalized roadmap & task completion* | *Multiple choice with explanations* | *Track scores & resume active tests* |

| Profile & Settings |
| :---: |
| <img src="img/profile.jpg" width="260" alt="Profile Screen" /> |
| *Account preferences & learning stats* |

---

## 🚀 Key Features

### 1. 🤖 AI Tutor Chat
- **Streaming Responses**: Real-time Server-Sent Events (SSE) streaming for instant response rendering.
- **Context Grounding (RAG)**: Switch between **General Study (AI)**, **All Uploaded Documents**, or a **Specific PDF**.
- **Academic Domain Guardrails**: Strict security guidelines ensuring the tutor stays focused on academic subjects and politely redirects non-study queries (recipes, pop culture, gossip).
- **Suggested Prompts**: Instant one-tap chips (`💡 Explain this simply`, `📄 Give me an example`, `❓ Test me`).
- **Rich Markdown & LaTeX Math**: Seamless rendering of formatted text, bullet lists, code syntax, and LaTeX formulas.

### 2. 📄 Document RAG System
- Upload PDF study guides, lecture notes, and textbook chapters.
- Text extraction, chunking, and semantic vector embeddings stored in PostgreSQL using `pgvector`.
- Semantic search and reranking to ground AI answers strictly in the student's materials.

### 3. 🎯 AI Quizzes & Practice Tests
- Automatically generates quizzes with configurable question counts, topics, and difficulties (*Easy, Medium, Hard*).
- Live progress saving: resume in-progress quizzes anytime without losing progress.
- Comprehensive review screen with percentage scores, question breakdown, and detailed explanations.

### 4. 🗂️ Spaced Repetition Flashcards
- Automatically extract flashcard decks from uploaded documents or custom topics.
- Spaced repetition algorithm tracking review counts, ease factor, intervals, and due dates.

### 5. 📅 7-Day Adaptive Study Schedule
- Enter exam subjects, target score, and target date to generate a structured 7-day revision roadmap.
- Interactive checkboxes for daily tasks (Revision, Quiz, Reading) with concurrency locks to avoid duplicate requests.

### 6. ⏱️ Focus Timer (Pomodoro)
- 25-minute Pomodoro study sessions with animated countdown timer and sound alerts.
- Completed sessions automatically sync with the backend to credit study time.

### 7. 📊 Gamified Analytics & Dashboard
- **Dynamic Stats**:
  - **Study Time**: Sum of Focus Timer sessions and quiz attempt durations.
  - **Tasks Done**: Number of completed study tasks and completed quizzes.
  - **Streak**: Consecutive daily study activity tracking.
  - **Learner Level**: Gamified XP progression system (`Level 1`, `Level 2`, `Level 3`, etc.).

---

## 📘 How to Use Guide

```mermaid
flowchart LR
    A["1. Sign Up / Login"] --> B["2. Upload PDF Docs"]
    B --> C["3. Ask AI Tutor"]
    B --> D["4. Generate Quizzes"]
    B --> E["5. Review Flashcards"]
    C --> F["6. Follow 7-Day Schedule"]
    D --> F
    E --> F
    F --> G["7. Track Progress & Level Up"]
```

### Step 1: Sign Up & Log In
- Open the app, register with your name and email, and log in. Your first name will be personalized across your dashboard and AI greeting.

### Step 2: Upload Study Documents
- Navigate to the **Documents** tab.
- Tap **Upload PDF** to upload lecture notes or textbook chapters.
- Wait for status to show `READY` (chunked & embedded).

### Step 3: Chat with AI Tutor
- Tap the center **Sparkle FAB** or **AI Tutor** from the Home screen.
- Tap the **Context** bar at the top to choose:
  - *General Study (AI)*: General knowledge across all subjects.
  - *All Uploaded Documents*: Search across all your uploaded PDFs.
  - *Specific PDF*: Focus answers exclusively on one document.
- Ask questions or tap suggestions like `💡 Explain this simply`.

### Step 4: Test Your Recall with Quizzes
- Tap **Quizzes & Tests** on the Home screen.
- Tap **New Quiz**, select a topic or document, choose difficulty, and tap **Generate Quiz**.
- Answer questions and review detailed explanations for incorrect answers.

### Step 5: Review Flashcards
- Tap **Flashcard Decks** to practice active recall using spaced repetition cards.

### Step 6: Create your Study Schedule
- Go to the **Schedule** tab, enter your subjects and target date, and tap **Generate Plan**.
- Check off daily tasks as you complete them.

### Step 7: Focus with Pomodoro Sessions
- Tap **Focus Timer** on the Home screen to start a 25-minute deep work session.

---

## 🏗️ Architecture & Tech Stack

```mermaid
graph TD
    subgraph MobileClient ["Mobile Client (Flutter)"]
      A["Flutter Mobile App"]
      A1["Riverpod State Management"]
      A2["GoRouter Navigation"]
      A3["Dio HTTP & SSE Client"]
    end

    subgraph BackendService ["Backend (Node.js + Express)"]
      B["Express API Gateway"]
      B1["Auth & JWT Middleware"]
      B2["Study Orchestrator"]
      B3["Intent Router"]
      B4["Tutor, Quiz & Planner Agents"]
    end

    subgraph StorageService ["Storage & Database (Supabase)"]
      C[("PostgreSQL DB")]
      C1[("pgvector Embeddings")]
      C2[("Object Storage / PDFs")]
    end

    subgraph LLMService ["LLM Provider"]
      D["Google Gemini API"]
    end

    A <-->|REST API & SSE Stream| B
    B <-->|Prisma ORM| C
    B <-->|Vector Retrieval| C1
    B <-->|File Management| C2
    B <-->|AI Prompts & Streaming| D
```

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Frontend Framework** | **Flutter / Dart** | Cross-platform mobile application (Android & iOS). |
| **State Management** | **Riverpod** | Reactive, compile-safe dependency injection & state management. |
| **Networking** | **Dio** | HTTP client with authentication interceptors and SSE streaming support. |
| **Backend Runtime** | **Node.js + TypeScript** | Strongly typed, modular backend REST API. |
| **Database & ORM** | **PostgreSQL + Prisma ORM** | Relational schema with migrations and automated typings. |
| **Vector Search** | **Supabase pgvector** | Native PostgreSQL vector storage for semantic document chunking. |
| **AI / LLM Engine** | **Google Gemini (`@ai-sdk/google`)** | `gemini-3.8-flash` for tutoring, quiz generation, and planner agents. |

---

## 📂 Project Structure

```text
AI Study/
├── app/                              # Flutter Mobile Application
│   ├── lib/
│   │   ├── core/                     # Networking, design system, layouts
│   │   │   ├── components/           # Message bubbles, stat cards, buttons
│   │   │   ├── layout/               # MainLayout & Bottom Navigation Bar
│   │   │   ├── network/              # DioClient & AuthInterceptor
│   │   │   └── theme/                # Colors, typography, spacing, radius
│   │   ├── features/
│   │   │   ├── auth/                 # Sign-in, sign-up, user state
│   │   │   ├── chat/                 # AI Assistant / AI Tutor screen & repository
│   │   │   ├── dashboard/            # Home screen, focus timer, dashboard providers
│   │   │   ├── documents/            # PDF upload & management
│   │   │   ├── flashcard/            # Flashcard decks & review screen
│   │   │   ├── profile/              # User profile & preferences
│   │   │   ├── quiz/                 # Quiz setup, interactive test & history
│   │   │   └── study_plan/           # 7-day study planner screen
│   │   └── main.dart
│   └── pubspec.yaml
│
├── backend/                          # Node.js Express TypeScript API
│   ├── prisma/
│   │   └── schema.prisma             # Database schema (Users, Docs, Quizzes, Sessions)
│   ├── src/
│   │   ├── ai/
│   │   │   ├── agents/               # TutorAgent, QuizAgent, FlashcardAgent, PlannerAgent
│   │   │   ├── providers/            # GeminiProvider & AI SDK integration
│   │   │   ├── routers/              # IntentRouter (heuristic & LLM classification)
│   │   │   ├── services/             # RAG chunk retrieval & reranking
│   │   │   └── orchestrator.ts       # Central AI study orchestrator
│   │   ├── middleware/               # JWT authentication middleware
│   │   ├── routes/                   # Auth, Chat, Docs, Quiz, Flashcard, Study routes
│   │   ├── utils/                    # Prisma DB client, PDF parser, Supabase client
│   │   └── index.ts                  # Server entry point
│   ├── .env.example                  # Template for environment variables (SAFE TO COMMIT)
│   ├── package.json
│   └── tsconfig.json
│
├── img/                              # App screenshots used in documentation
│   ├── homesc.jpg
│   ├── aiTutor.jpg
│   ├── doc.jpg
│   ├── study_plan.jpg
│   ├── QuizScreen.jpg
│   ├── myquizess.jpg
│   └── profile.jpg
│
├── docs/                             # Architecture & API specifications
├── .gitignore                        # Root gitignore protecting all secrets
└── README.md
```

---

## ⚙️ Installation & Setup

### Prerequisites
- **Node.js** (v18.x or higher)
- **Flutter SDK** (v3.19 or higher)
- **PostgreSQL Database** (e.g. via [Supabase](https://supabase.com) with `pgvector` enabled)
- **Google Gemini API Key** (from [Google AI Studio](https://aistudio.google.com/app/apikey))

---

### 1. Backend Setup

1. **Navigate to the backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure Environment Variables:**
   Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
   Open `.env` and configure your credentials:
   ```env
   PORT=3000

   # Supabase / PostgreSQL Connection Strings
   DATABASE_URL="postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1"
   DIRECT_URL="postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:5432/postgres"

   # Google Gemini API Key
   GOOGLE_GENERATIVE_AI_API_KEY="your_gemini_api_key_here"

   # Supabase Storage & Service Key
   SUPABASE_URL="https://your_project.supabase.co"
   SUPABASE_SERVICE_ROLE_KEY="your_supabase_service_role_key_here"
   ```

4. **Run Prisma Migrations:**
   ```bash
   npx prisma db push
   ```

5. **Start the Development Server:**
   ```bash
   npm run dev
   ```
   The backend will start running on `http://localhost:3000`.

---

### 2. Mobile App Setup (Flutter)

1. **Navigate to the app directory:**
   ```bash
   cd ../app
   ```

2. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```

3. **Configure Backend URL (if running on a physical device or emulator):**
   In `lib/core/network/dio_client.dart`:
   - For **Android Emulator**: `http://10.0.2.2:3000/api/v1`
   - For **iOS Simulator**: `http://127.0.0.1:3000/api/v1`
   - For **Physical Device**: `http://YOUR_LOCAL_IP_ADDRESS:3000/api/v1`

4. **Launch the App:**
   ```bash
   flutter run
   ```

---

## 🔒 Security & GitHub Verification

Before pushing to GitHub, verify that your repository is secure:

### Security Protections Implemented:
- ✅ **`.env` files are ignored**: Both root `.gitignore` and `backend/.gitignore` strictly exclude `.env`, `.env.*`, and sensitive keystores.
- ✅ **`.env.example` provides safe placeholders**: Only dummy variables are stored in version control.
- ✅ **No hardcoded API keys**: Gemini API keys and Supabase credentials are loaded strictly via `process.env`.
- ✅ **Android/iOS Keystores ignored**: Keystores (`*.jks`, `*.keystore`, `google-services.json`) are ignored in `.gitignore`.

### Verification Steps Before `git push`:
Run this command from the project root to ensure `.env` is ignored:
```bash
git check-ignore -v backend/.env
```
*(If git is initialized, this will confirm that `backend/.env` is excluded and will NOT be committed).*


