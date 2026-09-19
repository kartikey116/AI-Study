# UI Design System & UX Principles

## 1. Visual Language
The application must feel like a premium, polished commercial product designed for students. It avoids generic templates and leans into a distinctive aesthetic.

- **Theme:** Light pastel background with lavender/purple accents.
- **Vibe:** Minimal, friendly, soft, modern, and focused.
- **Geometry:** Large rounded corners (e.g., 20px-24px radii), clean whitespace.
- **Shadows:** Soft, diffused drop shadows to create depth without harshness.
- **Typography:** Modern sans-serif (e.g., Inter, Poppins, or SF Pro). Clean visual hierarchy.

## 2. Core Tokens
- **Primary Color:** Lavender / Soft Purple (e.g., `#8B5CF6`, `#A78BFA`).
- **Accent Color:** Subtle Pink gradients (e.g., `#F472B6` to `#D8B4FE`).
- **Background:** Off-white or extremely light gray/lavender tint (e.g., `#F8FAFC` or `#FCF5FF`).
- **Surface (Cards):** Pure White (`#FFFFFF`).
- **Text Primary:** Dark Slate (`#1E293B`).
- **Text Secondary:** Cool Gray (`#64748B`).

## 3. Core Components (Flutter)
- `AppCard`: White background, large border radius, soft shadow.
- `AppButton`: Gradient or solid lavender, fully rounded (pill shape).
- `AIMessageBubble`: Subtle gradient background (lavender/pink), rounded corners (with one sharp corner pointing to the avatar).
- `UserMessageBubble`: Light gray/white background, aligned right.
- `SkeletonLoader`: Used universally for loading states instead of blocking spinners.

## 4. UX Principles
- **Minimize Cognitive Load:** The home screen immediately answers "What should I do next?" (e.g., Today's study goal, Continue studying).
- **Graceful Degradation:** Features like the Focus Timer and Study Plans work offline.
- **Performance First:** The dashboard loads instantly using cached SQLite data while fetching updates in the background.
- **Streaming AI:** AI chat responses use SSE to stream text immediately, preventing the user from waiting on long inference times.

## 5. Screen Breakdown
### Home Dashboard
- Personalized greeting & avatar.
- Study statistics (Time, Tasks, Streak).
- AI Study Tip (cached periodically, not generated on every load).
- Quick Actions (Chat, Timer, Plan).
- Upcoming revision tasks.

### AI Assistant Chat
- Clean messaging interface.
- Inline suggested action chips ("Explain simply", "Make a quiz").
- Mode selector ("Normal" vs "Deep Think").
- Microphone button for voice input.
- Attachment button for documents.
