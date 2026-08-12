# DESIGN.md — Nexus Edu visual system

The single source of truth for colour, type, space, shape, motion, and components.
Read with `PRODUCT.md`. Code home: `lib/core/theme/` and `lib/shared/widgets/`.

A value that is not in this file does not belong in a widget. Hardcoded `Color(0x...)`,
one-off `fontSize`, and one-off `BorderRadius` in `lib/features/**` are defects.

---

## 01 — Overview

**Direction: Modern Academic.** Printed-page calm, not dashboard spectacle. The reference is a
well-set textbook or a university notice: paper surface, ink text, hairline rules, one
authoritative accent, and numbers you can read in a column. This direction is inherited from
the project's own design export (`Mobile-App/mobile-app-nexus-edu-final.html`, "Modern Academic
(Editorial Base) + accent") which the Flutter implementation drifted off entirely.

**Why this and not the current look.** The app today is a dark-only neon surface: violet→cyan
gradients, coloured glow shadows, glassmorphic blur, animated particle orbs. That is the single
most recognisable signature of AI-generated UI, and it reads as a hobby project to the person
signing the invoice. A principal, a trustee, and a parent all trust "official document" before
they trust "cyberpunk". The study half of the product also has to sit next to an attendance
register — a legal record — without looking like a game.

**Three rules that decide most arguments.**

1. **Structure over effect.** Hierarchy comes from type size, weight, and whitespace. Then from
   a 1px border. Only then, rarely, from a shadow. Never from a gradient or a glow.
2. **Colour is information.** One accent for interactive intent. Green / amber / red belong to
   attendance and status and are never spent on decoration. A screen with six accent colours is
   a screen with none.
3. **The 2 GB phone wins.** If an effect costs a repaint every frame, it is deleted. There is no
   visual idea worth 45fps on the device most of our users own.

**Both themes ship.** Light is the default and the one designed first. Dark is a real, complete
second theme, not a colour inversion. Today `AppTheme.lightTheme` returns `darkTheme`, so the
theme switch in Settings does nothing — that is a bug this system fixes.

---

## 02 — Colour

All values are sRGB hex. Contrast ratios are stated against the surface the value is used on and
are the reason the value was chosen; changing a value means re-checking its ratio.

### Light theme (default)

| Token | Hex | Use | Contrast |
| --- | --- | --- | --- |
| `page` | `#F7F8FA` | Scaffold background | — |
| `surface` | `#FFFFFF` | Cards, sheets, app bar | — |
| `surfaceAlt` | `#F1F3F7` | Input fill, table zebra, pressed state | — |
| `border` | `#DDE1E9` | Hairline dividers and card edges | — |
| `borderStrong` | `#C3C9D6` | Focused input, selected chip edge | — |
| `ink` | `#171A20` | Primary text, headings | 17.4:1 on surface |
| `inkMuted` | `#5B6270` | Secondary text, labels, captions | 6.0:1 on surface |
| `inkFaint` | `#858C9A` | Disabled, placeholder, decorative icons only | 3.4:1 — never body text |
| `primary` | `#26377A` | Interactive intent: buttons, links, active tab, focus | 10.9:1 on surface |
| `primaryPressed` | `#1C2A61` | Pressed / hovered primary | — |
| `primaryTint` | `#EDF0FB` | Icon tiles, selected chip fill, badge fill | — |
| `primaryTintBorder` | `#C9D2F2` | Edge of a tinted element | — |
| `secondary` | `#8A5300` | Streak, highlight, "earned" states — text weight | 6.3:1 on surface |
| `secondaryFill` | `#F0A02A` | Streak icon fill, progress accent | — |
| `secondaryTint` | `#FDF3E3` | Streak badge background | — |

### Dark theme

| Token | Hex | Use | Contrast |
| --- | --- | --- | --- |
| `page` | `#101216` | Scaffold background | — |
| `surface` | `#171A20` | Cards, sheets, app bar | — |
| `surfaceAlt` | `#1E2229` | Input fill, pressed state | — |
| `border` | `#2A2F38` | Hairline | — |
| `borderStrong` | `#3A404B` | Focused input, selected chip edge | — |
| `ink` | `#ECEEF2` | Primary text | 15.0:1 on surface |
| `inkMuted` | `#A2A9B6` | Secondary text | 7.4:1 on surface |
| `inkFaint` | `#6E7684` | Disabled, placeholder | 3.8:1 — never body text |
| `primary` | `#A8B8F0` | Interactive intent | 9.5:1 on page |
| `primaryPressed` | `#C3CEF6` | Pressed | — |
| `primaryTint` | `#1E2440` | Icon tiles, selected chip fill | — |
| `primaryTintBorder` | `#2E3766` | Edge of a tinted element | — |
| `secondary` | `#F0B357` | Streak, highlight | 8.6:1 on surface |
| `secondaryFill` | `#F0B357` | Same | — |
| `secondaryTint` | `#2A2113` | Streak badge background | — |

### Status — reserved, never decorative

These four exist to mean one thing each. `present` may not be used for a "Save" button.

| Meaning | Light | Dark | Where |
| --- | --- | --- | --- |
| Present / success / correct | `#15803D` (5.0:1) | `#56C57F` (8.0:1) | Attendance, quiz correct, saved |
| Late / warning / partial | `#8A5300` (6.3:1) | `#E8AE4C` (7.8:1) | Attendance late, low confidence |
| Absent / error / wrong | `#B3261E` (6.6:1) | `#F2857E` (7.0:1) | Attendance absent, quiz wrong, failures |
| Leave / holiday / neutral | `surfaceAlt` + `inkMuted` | `surfaceAlt` + `inkMuted` | Excused, holiday, not-applicable |

Leave is deliberately colourless. Four saturated status colours in one attendance grid is noise,
and a fifth accent hue on a dark surface is how cyan-on-dark slop gets in.

### Data visualisation

Charts use one series colour by default: `primary`. When more than one series is genuinely
needed, the ordered palette is `primary`, `secondary`, `#3F7D6E`, `#7A5C99`, `#8A5300`. Never
gradient-fill a chart. Never colour a chart by aesthetics when the series is a status — use the
status colours so a green bar always means present.

### Forbidden

- `LinearGradient` / `RadialGradient` / `SweepGradient` anywhere in `lib/features/**`.
  There are zero legitimate uses in this product.
- `BoxShadow` with any colour other than black at low alpha. Coloured shadow is glow.
- `ShaderMask` on text. Gradient text is unreadable and is a tell.
- `Colors.deepPurpleAccent`, `Colors.amberAccent`, `Colors.redAccent`, and every other
  `Colors.*Accent` constant. They are not in the system.
- Raw `Color(0x...)` literals outside `lib/core/theme/`.
- `BackdropFilter` / `ImageFilter.blur` used for decoration. Allowed only where content must
  genuinely be occluded behind a floating bar, and only at one blur value.
- Cream, beige, peach, or warm off-white page backgrounds.

---

## 03 — Typography

**Pairing: Fraunces (display) + IBM Plex Sans (body/UI) + IBM Plex Mono (figures).**

- **Fraunces** for headings only. A variable serif with real character — editorial, not the
  Playfair/Instrument Serif reflex, and not another italic-serif hero.
- **IBM Plex Sans** for everything functional. Distinctive without being Inter, exceptional at
  13–15px on a low-DPI screen, and it has a maintained **IBM Plex Sans Devanagari** sibling — so
  the Hindi UI is the same voice, not a fallback. That decides the pairing on its own.
- **IBM Plex Mono** for anything columnar: marks, percentages, roll numbers, attendance codes,
  timers, token counts. Tabular figures are the point — numbers in a column must align.

Never set body copy in Fraunces. Never set a heading in Plex Sans above 20px. One font for the
whole screen is the flat-hierarchy anti-pattern the current app has.

### Scale

Ratio is roughly 1.2–1.25 with deliberate gaps, so adjacent levels are never ambiguous.

| Token | Font | Size / Line | Weight | Tracking | Use |
| --- | --- | --- | --- | --- | --- |
| `display` | Fraunces | 32 / 36 | 600 | −0.02em | One per screen, top of page |
| `titleLg` | Fraunces | 24 / 30 | 600 | −0.01em | Card hero, sheet title |
| `title` | Fraunces | 20 / 26 | 600 | −0.01em | Section heading |
| `subtitle` | Plex Sans | 17 / 24 | 600 | 0 | Card title, list group header |
| `body` | Plex Sans | 15 / 22 | 400 | 0 | Default. All prose. |
| `bodyStrong` | Plex Sans | 15 / 22 | 600 | 0 | Emphasis inside prose |
| `bodySm` | Plex Sans | 13 / 19 | 400 | 0 | Secondary text, helper |
| `label` | Plex Sans | 12 / 16 | 600 | +0.01em | Field labels, chips, tab labels |
| `figure` | Plex Mono | 15 / 20 | 500 | 0 | Inline numbers, codes |
| `figureLg` | Plex Mono | 28 / 32 | 600 | −0.01em | Stat tile value |

Hard floors: nothing below **12px**, ever. Body line-height never below **1.4**. Body tracking
never above **0.02em** — wide tracking on running text is a legibility cost with no upside.

`display` is for a short phrase. A full sentence set at 32px eats the viewport and is the
oversized-hero anti-pattern; long headings drop to `titleLg`.

### Rules

- Text scaling to **200%** must not clip. No fixed-height box around text. Use `Flexible`,
  `softWrap`, and let rows wrap. This is also what protects Hindi and regional copy.
- No `ALL CAPS` on anything longer than a 2-word label.
- No eyebrow / kicker labels above headings. Fold the words into the heading.
- Long-form reading surfaces (notes, solutions, AI explanations) clamp to a **68-character**
  measure and use `body` with 1.55 line-height.
- Numbers in any table or list use `figure`. A right-aligned column of proportional digits is
  a defect.

### Font delivery — required before the next release

`google_fonts` currently fetches Outfit over the network at runtime, with no fonts bundled. That
means first-frame text jank on every cold start and broken typography for a user with no
connection — unacceptable for an offline-first product. Bundle the three families as assets,
declare them in `pubspec.yaml`, and set `GoogleFonts.config.allowRuntimeFetching = false`.
Until that lands, the theme must resolve its `TextTheme` exactly once and cache it, never
per-rebuild.

---

## 04 — Space and layout

**Scale.** `xxs 4`, `xs 8`, `sm 12`, `md 16`, `lg 24`, `xl 32`, `xxl 48`. Nothing else.
No `EdgeInsets.all(17)`, no `SizedBox(height: 30)`.

**Rhythm is not uniform.** Related things sit at `xs`–`sm`. Sections separate at `lg`–`xl`.
The same gap everywhere is the monotonous-spacing anti-pattern.

**Page frame.**

- Horizontal gutter: `lg` (24) on phones, `xl` (32) at ≥600dp.
- Vertical: `md` (16) below the app bar, `xl` (32) between major sections, `xxl` (48) above the
  end of a scroll.
- A card sits `lg` from the screen edge and `md` from the next card.
- Card interior padding: `lg` (20–24). A bordered container never has less than `sm` (12).

**Tablets.** Content clamps to a `640` max width and centres. A 1024dp-wide screen with a single
full-bleed column is broken. Teacher screens (roster, attendance, gradebook) go two-pane at
≥840dp — list left, detail right.

**Headings own their space.** More space above a heading than below it, always. A heading closer
to the previous block than to its own content is a defect.

**Never nest cards.** A bordered surface inside a bordered surface inside a bordered surface is
the cardocalypse. Use a divider, a heading, or space. Maximum nesting depth: one.

**Tap targets.** 48×48dp minimum, everywhere, including icon buttons in list rows. 8dp minimum
between adjacent targets.

**Lists.** Anything that can exceed 10 items is a `ListView.builder` / `SliverList` with keys.
A `Column` of `.map()` inside a `SingleChildScrollView` over a variable-length list builds every
row on every frame and is a defect regardless of current data size.

---

## 05 — Shape and elevation

**Radius — three values plus a pill.**

| Token | Value | Use |
| --- | --- | --- |
| `rSm` | 8 | Chips, badges, icon tiles, skeleton blocks |
| `rMd` | 14 | Buttons, inputs, small cards |
| `rLg` | 20 | Cards, sheets, dialogs |
| `rPill` | 999 | Status chips, avatars, filter pills |

Nothing above 20 on a card. A small card at 24+ rounds into a blob; the current app uses at
least five different radii, which is why nothing looks intentional.

**Elevation — three levels, and level 0 is the default.**

| Level | Treatment | Use |
| --- | --- | --- |
| `e0` | `surface` + 1px `border`, no shadow | Every card, every input, default |
| `e1` | `0 4px 20px -10px rgba(0,0,0,0.06)` + border | Floating bars, raised sheet, pressed-away card |
| `e2` | `0 10px 30px -8px rgba(0,0,0,0.12)` | Dialogs, menus, popovers |

Never a border and a wide diffuse shadow together at `e0` — hairline-plus-halo is a generated-UI
signature. Commit to the edge. In dark theme, elevation is expressed by `surfaceAlt` stepping up,
not by heavier shadow: shadow on a near-black surface is invisible and only costs frames.

---

## 06 — Motion

Motion reports state changes. It does not entertain.

| Token | Duration | Use |
| --- | --- | --- |
| `mTap` | 120ms | Press, ripple, chip toggle, checkbox |
| `mEnter` | 200ms | Content appear, list item stagger, banner |
| `mSheet` | 320ms | Bottom sheet, dialog, page transition |

Nothing exceeds 320ms. Two things may not animate simultaneously in the same region.

**Curves.** `AppMotion.standard = Cubic(0.2, 0, 0, 1)` for entering and for most state change.
`Curves.easeOut` for exits. That is the whole list.

**Forbidden.** `Curves.elasticOut`, `Curves.bounceOut`, and any overshoot on an interface
element — a dialog that springs past its position reads as dated and tacky. Press feedback is
`scale 0.97` at `mTap` with no bounce.

**Forbidden: continuous animation.** No `AnimationController.repeat()`, no
`.animate(onPlay: (c) => c.repeat())`, no pulsing status dots, no marquees, no animated
backgrounds, no particles, no drifting gradients. `lib/core/widgets/animated_background.dart`
repaints three 60px-blur circles and fifteen blurred particles behind the entire widget tree,
forever, on every screen that uses it. It is deleted, not tuned. A pulse is allowed in exactly
one place: a loading skeleton, which stops when content arrives.

**A spinner is a last resort.** Prefer a skeleton that matches the shape of the content that is
coming. Prefer optimistic UI where the write will almost certainly succeed.

**Respect `MediaQuery.disableAnimations`** and reduce-motion: fall back to an instant state
change, not a slower animation.

---

## 07 — Components

Everything below lives in `lib/shared/widgets/`. A feature screen that hand-rolls one of these
is a defect. Today `NexusCard`, `NexusButton`, and `NexusTextField` exist but are barely used,
while ~90 screens hand-roll `Container` + `BoxDecoration` + hardcoded hex — that is the core
duplication problem this inventory solves.

| Component | Purpose | Anti-pattern it kills |
| --- | --- | --- |
| `NexusScreen` | Scaffold shell: background, app bar style, safe area, tablet max-width clamp, scroll padding | 90 copies of `Scaffold(backgroundColor: Color(0xFF0F0F13), appBar: AppBar(...))` |
| `NexusCard` | `e0` surface: border, `rLg`, `lg` padding, optional tap | Glassmorphic `BackdropFilter` card; hand-rolled `Container` cards |
| `NexusButton` | `primary` / `secondary` / `ghost` / `danger`, sizes `md`/`sm`, loading, 48dp min | Gradient + glow buttons; `FilledButton` with `deepPurpleAccent` |
| `NexusTextField` | Label, hint, helper, error, multiline, counter, correct fill and focus ring | Hand-rolled `TextField` + `InputDecoration` in every screen |
| `NexusChipGroup` | Single- or multi-select filter chips from a `List<String>` | ~60 copies of `_buildSelectorRow` with a `Wrap` of `GestureDetector` |
| `NexusSectionHeader` | Title + optional trailing action | Bare `Text` with ad-hoc size/weight |
| `NexusStateView` | `loading` (skeleton) / `empty` / `error` (with retry) — the states the design export specified and the app never built | Infinite spinner; blank screen; raw exception text |
| `NexusSkeleton` | Pulsing block, line, and avatar primitives | Spinner-for-everything |
| `NexusBanner` | Inline `info` / `warning` / `error` with an action | `SnackBar(content: Text('$e'))` |
| `NexusStatTile` | One `figureLg` value + `label` + optional delta, tabular | Hero-metric grids of three invented numbers |
| `NexusListRow` | Leading icon, title, subtitle, trailing, swipe/dismiss | Hand-rolled saved-item rows |
| `NexusStarRating` | 5-star input/display | Duplicated star `Row(List.generate(5,...))` |
| `AttendanceStatusChip` | Present / Absent / Late / Leave, reserved colours, text label not colour alone | Colour-only status, which fails for colour-blind users |
| `AiToolScaffold` | The whole shell for an AI tool page: title, subtitle, input slot, primary action, loading, result card with copy/share/save, history list, empty + error states | ~60 screens of 300–500 lines each repeating this exact flow |

`AiToolScaffold` is the highest-leverage component in the app. Roughly sixty feature screens are
the same page: type something, pick a subject, press generate, read markdown, save to local
history. Collapsing them onto one shell removes thousands of lines and makes every future design
change land in one file instead of sixty.

**States are not optional.** Every component that loads data implements default, loading, empty,
and error. A screen that only implements "has data" is unfinished.

**Icons.** Material Symbols outlined at 20px in list rows and 24px in nav. One weight. An icon
never appears without a text label in navigation or status. Icon containers do not sit stacked
above a heading — that layout is the universal AI feature-card template; put the icon beside the
title or let it sit in flow.

**Empty states.** Say what goes here and give one action. No illustrations — specifically no
hand-coded SVG mascots or shape-assembled hero art. A line of type and a button beats clip art.

---

## 08 — Copy

Copy is design. `clarify` rules:

- **Say it once.** Label, sublabel, helper, and hint saying the same thing in four registers is
  the redundant-writing anti-pattern.
- **No marketing verbs in product UI.** Not *supercharge*, *unleash*, *revolutionise*,
  *world-class*, *next-generation*, *seamless*, *empower*. Say what the button does.
- **No emoji in labels, buttons, headings, or status.** They break at small sizes, they do not
  translate, and they read as unserious to an institutional buyer.
- **Em-dashes: at most one per screen.** Use a comma, a colon, or a full stop.
- **Errors name the cause and the next step.** "Couldn't reach the server. Check your connection
  and try again." Never "Error: Exception".
- **Never present a fallback as an answer.** When an AI call fails, say it failed. The current
  `AiAgentService._getLocalFallback` returns invented prose ("The answer involves applying the
  relevant formula…", "The experiment was conducted successfully") that is indistinguishable
  from a real answer. That is worse than an error message.
- **Numbers get their basis.** "82% — your 40 answered questions" not a bare "82%". If there is
  no basis, there is no number.
- **Hindi and regional copy is 20–35% longer.** Design for the long string.

---

## 09 — Do / Don't

| Do | Don't |
| --- | --- |
| Hierarchy from type and space | Hierarchy from gradient and glow |
| One accent, reserved status colours | Six accent hues per screen |
| 1px border for edges | Border plus a wide soft shadow |
| Three radii | Five radii and a 44px blob |
| Skeletons shaped like the content | A centred spinner |
| Motion on state change, ≤320ms | Perpetual background animation |
| `ListView.builder` with keys | `Column(children: list.map(...))` |
| Text label with every status colour | Colour-only status |
| Real numbers, or no number | Invented percentiles and peer ranks |
| Tokens from this file | `Color(0xFF1E1E1E)` in a feature file |

---

## 10 — Enforcement

A change is done when all of these hold:

1. `flutter analyze` is clean. The baseline is zero issues; keep it there.
2. `grep -rn "Color(0x" lib/features/` returns nothing.
3. `grep -rn "LinearGradient\|deepPurpleAccent\|BackdropFilter" lib/features/` returns nothing.
4. No `repeat(` outside `NexusSkeleton`.
5. The screen renders correctly at 360×800 and at 200% text scale with no clipping and no
   horizontal overflow.
6. Light and dark both checked. Both are real themes.
7. Loading, empty, and error states exist and were looked at.
