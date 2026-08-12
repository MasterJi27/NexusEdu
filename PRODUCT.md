# PRODUCT.md — Nexus Edu

Design and product context. Every design or UI change reads this file first.
Companion file: `DESIGN.md` (visual system). This file holds strategy: who, what, why.

---

## Platform

`adaptive` — Flutter, Android-first.

- Shipping surface today: Android phone (Play Store, `minSdk 24`). Portrait.
- Must also work: 360×800 budget phones (the actual majority device in Indian schools), and
  600–1024 tablets, because teacher-facing screens get used on a school tablet.
- Backend: Node/Express + Prisma + Postgres. Single deployment today.
- iOS is not built. Do not add iOS-only interaction idioms.
- Real device floor: 2 GB RAM, mid-tier Snapdragon/Helio, patchy 4G, often on a shared phone.
  Everything is judged against that device, not a flagship.

## Who this is for

Three distinct users, and they are not variants of each other.

**1. The self-directed student (Class 9–12, JEE/NEET aspirant, or a college student).**
Studies alone, at night, on their own phone, usually in a hostel or a shared room.
Comes with one specific unblock in mind: "solve this sum", "make me notes for this chapter",
"quiz me before tomorrow's test". Reading fast, low patience, often on 4G that drops.
They pay for themselves, in small amounts, and only after the app has already helped once.

**2. The teacher.**
Government or private school, 35–60 students per section, 5–6 periods a day, plus
attendance registers, plus exam duty. Not paid to learn software. Judges a tool by one
question: does this take work off my plate today, without me entering data twice?
Uses the app between periods, standing, with 40 seconds free. If a task takes more taps
than the paper register, the paper register wins and the app is abandoned.

**3. The parent.**
Wants three facts: did my child attend, is my child falling behind, and what do I do about it.
Often lower digital literacy than the student, often reading in Hindi or a regional language,
often on a different phone than the one the student uses. Will not explore. Will not read a
dashboard. Needs to be told, not to look things up.

And behind all three, **the buyer**: a principal, trustee, director, or HOD. They do not use
the app. They approve the invoice. They care about attendance compliance, board-exam results,
parent complaints, and whether this creates work for their staff.

## Positioning

Nexus Edu is the study app that also runs the classroom's daily record — attendance and
progress — so a school gets one system instead of a register plus an app plus a WhatsApp group.

What a neighbouring product cannot truthfully claim:
- Pure AI study apps (Doubtnut, Photomath-likes) have no institutional record. They cannot
  tell a principal who was in class.
- Pure school ERPs (Fedena, Entab, MyClassboard, Teachmint) hold the record but give the
  student nothing they would open voluntarily on a Sunday.
- Nexus Edu's claim only holds if **both** halves are real. Today the study half is broad
  and the institutional half does not exist. That gap is the roadmap.

## What we can honestly claim today

Claim only these. Everything else is aspiration until the code backs it.

- A large library of AI study tools (solve, explain, notes, flashcards, quizzes, mnemonics,
  study plans) that work against a real backend AI proxy with per-user usage accounting.
- Real accounts: signup, login, password reset, device sessions, role field, parent–student
  linking, teacher-authored notes.
- Local progress tracking: streaks, XP, subject progress, spaced-repetition queue.
- Works on a budget Android phone.

## What we must NOT claim

These are currently absent or fabricated in the app. Writing them in UI copy, on the store
listing, or in a sales deck is a misrepresentation risk, not just a stretch.

- Peer comparison, class ranking, percentile, "students like you" — there is no cohort data.
- Predicted board/JEE scores or "exam readiness %" derived from real outcomes.
- Live classes, real-time study rooms, or verified peer tutoring with actual other humans.
- Plagiarism detection against any corpus.
- Handwriting or diagram recognition accuracy.
- Anything about attendance, until the attendance module ships.

Rule: if a number on screen cannot be traced to the user's own activity or to a backend
response, it must not be presented as a fact. Label it, derive it, or delete it.

## Evidence on hand

- A live Play Store listing with real installs.
- A working backend with AI usage logs per user (`AiUsageLog`) — real telemetry, real costs.
- A finished visual design system in `Mobile-App/mobile-app-nexus-edu-final.html`
  ("Modern Academic + accent"), including specified loading, empty, and error states.
  The Flutter app drifted off it entirely; `DESIGN.md` brings it back.
- No school pilot yet. No named institutional customer. No case study, no logos, no results
  data. Do not design screens or decks that assume social proof we do not have.

## Durable constraints

Things later work must preserve. Breaking one of these is a regression even if it looks better.

1. **The Play Store identity is load-bearing.** The published `applicationId` cannot change
   without abandoning every existing install, review, and rating. Treat it as frozen.
2. **Offline is normal, not an edge case.** Campus wifi and basement classrooms fail
   constantly. Every write a teacher or student makes must survive no-signal and sync later.
   A spinner is not an offline strategy.
3. **Budget device performance is a feature.** 60fps on a 360×800 2 GB phone outranks any
   visual effect. Continuous animation, blur, and shadow stacking are not free.
4. **Data about minors.** Most users are under 18. India's DPDP Act 2023 requires verifiable
   parental consent and purpose limitation; Play's Families policy applies. Collect the
   minimum, retain it for a stated period, and never ship biometrics or raw location off-device.
5. **Multilingual is a requirement, not a phase-2 nicety.** Hindi first, then regional.
   Fonts, layout, and copy length must survive translation. No fixed-height text containers.
6. **One accent colour, and semantic colours stay reserved.** Green, amber, and red belong to
   present / late / absent. Never spend them on decoration.
7. **Every teacher action must beat the paper register on taps.** If marking a class of 50
   takes longer than a pen, the feature has failed regardless of its architecture.
8. **Budget-conscious infrastructure.** Indian schools buy on price. The system must run
   credibly on one small VPS plus managed Postgres, and must degrade rather than fall over.

## Terminology

Use these words in UI copy. They are what Indian schools already say.

| Use | Not |
| --- | --- |
| Class, Section (Class 10-B) | Grade, Homeroom |
| Roll number | Student ID (in student-facing UI) |
| Period | Slot, Block |
| Attendance: Present / Absent / Late / Leave | Checked in, Punched in |
| Marks, Percentage | Score, Points (except gamification XP) |
| Board (CBSE / ICSE / State) | Curriculum |
| Fees | Billing (in institutional UI) |
| Notice | Announcement, Broadcast |
| Doubt | Question (when the student is stuck) |
| Revision | Review |

## Modes by surface

Impeccable reads the mode from the surface, not from the company.

- **Operate** — dashboard, attendance marking, teacher tools, gradebook, admin console,
  every AI tool screen. Scanability and native expectation outrank expression. This is most
  of the app.
- **Read** — notes, NCERT solutions, AI-generated explanations, textbook screens. Measure,
  rhythm, quiet hierarchy. Long-form comfort matters more than density here.
- **Persuade** — paywall, onboarding, the store listing, the institutional landing page and
  sales collateral. Design has to earn attention here, and only here.
- **Experience** — not applicable. There is no gallery surface in this product. If a screen
  feels like it wants to be Experience mode, it is probably decoration.
