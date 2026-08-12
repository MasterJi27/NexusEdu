# UX Research — Indian EdTech Patterns (BYJU'S / Unacademy / Vedantu / Doubtnut)

Compiled from 2025-2026 public research on edtech onboarding, retention and
gamification. Purpose: a short checklist of proven patterns and how Nexus Edu
already covers them (or not).

## 1. Activation: first win in under 5-7 minutes
Benchmarks: apps that deliver value in the first 3 minutes get ~2x Day-1
retention; personalized (2-3 question) onboarding lifts day-7 retention 20-30%.

- Pattern: signup asks goal + exam date + daily minutes, then the app lands the
  student on ONE action, not a menu. First lesson short, then quiz, then
  instant feedback ("4/5 right, top 30%").
- Nexus now: onboarding asks class; dashboard offers Today's plan (1/3 done),
  syllabus path, daily quiz with XP. Gap: no first-run "earned win" moment —
  the Daily Quiz on day one effectively plays this role; consider a one-time
  "finish your first quiz" nudge with a visible reward.
- Gap: exam date / daily-minutes micro-commitment is not collected. Profile has
  exam date (used by planner). Daily-minutes could feed the study planner
  defaults.

## 2. Habit loop: streaks with forgiveness, not punishment
Research: streaks raise return rates, but a broken streak becomes a reason to
quit — the fix is a "streak saver" (one missed day doesn't break it).

- Nexus now: streak counter on profile + daily quiz. Gap: no streak-saver and
  no streak-risk notification. Cheap win: allow one grace day.

## 3. Notifications: behavioral, not broadcast
Generic daily blasts collapse within a week. What works: messages tied to
inactivity, streak risk, or deadlines, at the learner's own active time.

- Nexus now: class-task notifications, teacher notes. Gap: no local inactivity
  reminders, no deadline/streak-risk triggers, no best-time logic. Cheap local
  win: a settings toggle "remind me when I miss my streak" scheduling a local
  notification.

## 4. Progress visibility is the retention engine
"Module 3 of 10" is decoration; mastery confidence, skill progression and
branching paths are the real motivators. Progress persistence across sessions
(land exactly where you left off) is a core expectation.

- Nexus now: strong — syllabus path with progress, analytics (mastery heatmap,
  trajectory, AI coach), topic mastery, XP/levels. This is the app's biggest
  strength; keep protecting it.

## 5. Low-data / offline is a first-class citizen (Doubtnut/Unacademy)
Tier-2/3 reality: 2G/3G, data at a premium, shared family devices, old phones.
Doubtnut's WhatsApp channel exists precisely because the app was too heavy.
Unacademy Mini (PWA) cut data and loaded instantly.

- Nexus now: strong and getting stronger — notes/QR fully offline, offline
  exams over hotspot and BLE (new), low-dependency backend AI.
- Gap: no "download for offline" for content (feed shorts, NCERT pages) —
  future work; the offline exam feature is the right direction.

## 6. Gamification: rewards for achievement, not activity
Badges for milestones, XP tied to real outcomes, near-completion cues
(anticipation beats reward). Leaderboards alone are decoration.

- Nexus now: XP from quizzes, leaderboard, certifications with real completion.
  Good alignment. Keep tying XP to outcomes.

## 7. Role-aware information architecture (Unacademy 2021 rewrite)
Condense to what each persona needs daily: Planner / Self-study / Profile for
independent learners; eliminate decision-making for dependent ones. Smart
defaults, "get out of her way".

- Nexus now: 6 tabs (Learn/Shorts/Tutor/Notes/Profile/Classroom) + teacher and
  parent dashboards + role-gated routes. Matches the pattern; the Classroom tab
  mirrors Unacademy's Planner intent for school life.

## 8. Vernacular and accessibility (Doubtnut)
Junior students fail to understand English-only flows; language selection must
come FIRST; numbers/OTP fail on shared devices (kids don't know their own
number).

- Nexus now: multi-language tutor exists (AI answers in the student's
  language). Gap: app UI itself is English-only; a language toggle for UI
  strings is a large lift — out of scope for now, note for roadmap.

## 9. Social/cohort accountability
Groups that show each other's progress create natural accountability
(Unacademy Groups; Vedantu class cohorts).

- Nexus now: leaderboard, study groups screens, peer comparison. Gap: no
  class-level "who's done today's plan" visibility — the classroom notifications
  + tasks partially cover it.

## Actionable shortlist (cheap → valuable)
1. ✅ Streak saver (one grace day) + streak-risk local notification toggle.
   - Grace day: `AppSettings.computeStreak` — one missed day keeps the streak and
     consumes the shield; a second miss resets it. Dashboard warns "your streak
     shield saved you" when the shield is consumed; profile card shows the state.
   - Local notification: `StreakNotificationService` schedules a daily 7pm
     "streak needs you today" reminder (flutter_local_notifications + timezone),
     tied to the existing Settings → Streak alerts toggle, boot-surviving.
2. ✅ First-run "earn your first win" nudge + first-win XP bonus.
   - Dashboard nudge for streaks ≤ 1 with today's quiz undone; completing the
     first quiz of the day grants +15 XP once (GamificationService) and the
     dashboard celebrates it.
3. ✅ Collect daily-minutes goal; use as planner default.
   - `AppSettings.dailyMinutesGoal` (default 30) surfaced on the Focus screen as
     a tap-to-cycle goal (15/30/45/60/90) with a reached state.
4. ✅ Keep pushing offline-first features.
   - Offline exams done; NCERT solutions now cache the generated text
     (viewable offline, no tokens on re-open, newest 10 kept, green "Available
     offline" mark); guest Shorts search falls back to the local syllabus
     catalog when the YouTube API is unreachable.
5. ✅ Continue role-aware IA; revisit if a 7th tab ever appears (it shouldn't).
   - Near-completion cue added: subject cards ≥85% show "Almost there".
