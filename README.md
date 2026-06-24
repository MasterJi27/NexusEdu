# NexusEdu: Advanced AI Learning Ecosystem

NexusEdu is a next-generation educational application designed to go beyond traditional LMS. It transforms generic syllabi into a gamified, conversational, and interactive TikTok-style learning experience using RAG (Retrieval-Augmented Generation) and AI.

## Project Vision & 2-Day Roadmap

This application scaffolding is designed to be shipped in under **48 hours**. 
It utilizes:
1. **Flutter** + **Riverpod** for a production-ready, scalable frontend.
2. **GoRouter** for seamless deep-linking and shell routing.
3. **Card Swiper** for the engaging "Micro-learning" feed.
4. **Supabase / Firebase** (Optional backend) for fast real-time data sync.

### Architecture

```text
lib/
 ├── core/
 │    ├── theme/      (Dark/Light modes, Google Fonts)
 │    ├── network/    (Dio client for AI endpoints)
 │    └── utils/      (Constants, helpers)
 ├── features/
 │    ├── dashboard/  (Learning paths & progress)
 │    ├── feed/       (TikTok-style AI flashcards)
 │    ├── tutor/      (Conversational AI Tutor)
 │    └── navigation/ (Bottom Nav Shell Route)
 └── main.dart
```

### Advanced Capabilities to Implement

To make this app "non-generic" and win the competition, focus on these 3 AI layers:

1. **The Micro-Learning Engine (Feed Feature):**
   * Feed it a PDF syllabus.
   * Use an AI endpoint (e.g., Gemini 1.5 Pro) to chunk the PDF into 3-sentence concepts.
   * Render them in the `AiFeedScreen` (already scaffolded).

2. **The Socratic AI Tutor (Tutor Feature):**
   * Instead of just giving answers, the `TutorChatScreen` should prompt the user to think.
   * Connect it to an API (like OpenAI Realtime API or Gemini) to provide Voice-to-Voice interactions.

3. **Gamification (Dashboard Feature):**
   * Track time spent swiping on the feed.
   * Render dynamic "Skill Trees" instead of standard lists.

### How to Run
```bash
flutter pub get
flutter run
```