/// Design tokens for Nexus Edu. The single source of truth for colour, space,
/// shape, and motion. See `DESIGN.md` at the repo root for the reasoning behind
/// every value here, including the contrast ratio each colour was chosen for.
///
/// Feature code must never contain a raw `Color(0x...)`, a one-off `fontSize`,
/// or a one-off `BorderRadius`. Read tokens through `context.tokens` instead.
library;

import 'package:flutter/material.dart';

/// Semantic colour set for one theme (light or dark).
///
/// Registered as a [ThemeExtension] so a widget reads the right value for the
/// active theme without branching on brightness.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.page,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.primary,
    required this.primaryPressed,
    required this.primaryTint,
    required this.primaryTintBorder,
    required this.secondary,
    required this.secondaryFill,
    required this.secondaryTint,
    required this.statusPresent,
    required this.statusLate,
    required this.statusAbsent,
    required this.shadow,
  });

  /// Scaffold background. Never used for a card.
  final Color page;

  /// Cards, sheets, app bars — the raised reading surface.
  final Color surface;

  /// Input fill, table zebra striping, pressed background.
  final Color surfaceAlt;

  /// Hairline: card edges and dividers.
  final Color border;

  /// Focused input ring, selected chip edge.
  final Color borderStrong;

  /// Primary text and headings.
  final Color ink;

  /// Secondary text, labels, captions. Passes AA for body copy.
  final Color inkMuted;

  /// Disabled text, placeholders, decorative icons.
  /// Below AA for body copy by design — never set running text in this.
  final Color inkFaint;

  /// The one accent. Interactive intent only: buttons, links, active states.
  final Color primary;
  final Color primaryPressed;

  /// Tinted primary for icon tiles, selected chips, and badges.
  final Color primaryTint;
  final Color primaryTintBorder;

  /// Supporting accent for streaks and earned states. Used sparingly.
  final Color secondary;
  final Color secondaryFill;
  final Color secondaryTint;

  /// Reserved status colours. These mean one thing each and are never spent on
  /// decoration: green is "present", not "save". Leave/holiday is deliberately
  /// colourless — use [surfaceAlt] with [inkMuted].
  final Color statusPresent;
  final Color statusLate;
  final Color statusAbsent;

  /// Black at low alpha. The only legal shadow colour: a coloured shadow is a
  /// glow, and glow is banned.
  final Color shadow;

  static const AppTokens light = AppTokens(
    page: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F3F7),
    border: Color(0xFFDDE1E9),
    borderStrong: Color(0xFFC3C9D6),
    ink: Color(0xFF171A20),
    inkMuted: Color(0xFF5B6270),
    inkFaint: Color(0xFF858C9A),
    primary: Color(0xFF26377A),
    primaryPressed: Color(0xFF1C2A61),
    primaryTint: Color(0xFFEDF0FB),
    primaryTintBorder: Color(0xFFC9D2F2),
    secondary: Color(0xFF8A5300),
    secondaryFill: Color(0xFFF0A02A),
    secondaryTint: Color(0xFFFDF3E3),
    statusPresent: Color(0xFF15803D),
    statusLate: Color(0xFF8A5300),
    statusAbsent: Color(0xFFB3261E),
    shadow: Color(0xFF000000),
  );

  static const AppTokens dark = AppTokens(
    page: Color(0xFF101216),
    surface: Color(0xFF171A20),
    surfaceAlt: Color(0xFF1E2229),
    border: Color(0xFF2A2F38),
    borderStrong: Color(0xFF3A404B),
    ink: Color(0xFFECEEF2),
    inkMuted: Color(0xFFA2A9B6),
    inkFaint: Color(0xFF6E7684),
    primary: Color(0xFFA8B8F0),
    primaryPressed: Color(0xFFC3CEF6),
    primaryTint: Color(0xFF1E2440),
    primaryTintBorder: Color(0xFF2E3766),
    secondary: Color(0xFFF0B357),
    secondaryFill: Color(0xFFF0B357),
    secondaryTint: Color(0xFF2A2113),
    statusPresent: Color(0xFF56C57F),
    statusLate: Color(0xFFE8AE4C),
    statusAbsent: Color(0xFFF2857E),
    shadow: Color(0xFF000000),
  );

  /// Text colour that reads on top of [primary] as a solid fill.
  Color get onPrimary => page == AppTokens.light.page
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF101216);

  @override
  AppTokens copyWith({
    Color? page,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? borderStrong,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? primary,
    Color? primaryPressed,
    Color? primaryTint,
    Color? primaryTintBorder,
    Color? secondary,
    Color? secondaryFill,
    Color? secondaryTint,
    Color? statusPresent,
    Color? statusLate,
    Color? statusAbsent,
    Color? shadow,
  }) {
    return AppTokens(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primaryTint: primaryTint ?? this.primaryTint,
      primaryTintBorder: primaryTintBorder ?? this.primaryTintBorder,
      secondary: secondary ?? this.secondary,
      secondaryFill: secondaryFill ?? this.secondaryFill,
      secondaryTint: secondaryTint ?? this.secondaryTint,
      statusPresent: statusPresent ?? this.statusPresent,
      statusLate: statusLate ?? this.statusLate,
      statusAbsent: statusAbsent ?? this.statusAbsent,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
      primaryTintBorder:
          Color.lerp(primaryTintBorder, other.primaryTintBorder, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryFill: Color.lerp(secondaryFill, other.secondaryFill, t)!,
      secondaryTint: Color.lerp(secondaryTint, other.secondaryTint, t)!,
      statusPresent: Color.lerp(statusPresent, other.statusPresent, t)!,
      statusLate: Color.lerp(statusLate, other.statusLate, t)!,
      statusAbsent: Color.lerp(statusAbsent, other.statusAbsent, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Real third-party brand colours — Gemini blue, Claude orange, and similar —
/// used only to identify which provider a certification track belongs to.
/// These are brand identifiers, not decorative accents, but DESIGN.md still
/// bans a raw `Color(0x...)` literal in `lib/features/**`, so they live here
/// instead of inline in the screen that badges them.
abstract final class AppBrandColors {
  static const Color aiFoundations = Color(0xFF7C3AED);
  static const Color gemini = Color(0xFF4285F4);
  static const Color claude = Color(0xFFD97706);
  static const Color promptEngineering = Color(0xFF059669);
  static const Color digitalTeaching = Color(0xFF2563EB);
}

/// Type styles that Material's [TextTheme] has no slot for.
@immutable
class AppTypeExtras extends ThemeExtension<AppTypeExtras> {
  const AppTypeExtras({
    required this.figure,
    required this.figureLg,
    required this.bodyStrong,
  });

  /// Tabular figures for inline numbers, roll numbers, and codes. Monospaced so
  /// a column of marks aligns.
  final TextStyle figure;

  /// The large number in a stat tile.
  final TextStyle figureLg;

  /// Emphasis inside prose, at body size.
  final TextStyle bodyStrong;

  @override
  AppTypeExtras copyWith({
    TextStyle? figure,
    TextStyle? figureLg,
    TextStyle? bodyStrong,
  }) {
    return AppTypeExtras(
      figure: figure ?? this.figure,
      figureLg: figureLg ?? this.figureLg,
      bodyStrong: bodyStrong ?? this.bodyStrong,
    );
  }

  @override
  AppTypeExtras lerp(ThemeExtension<AppTypeExtras>? other, double t) {
    if (other is! AppTypeExtras) return this;
    return AppTypeExtras(
      figure: TextStyle.lerp(figure, other.figure, t)!,
      figureLg: TextStyle.lerp(figureLg, other.figureLg, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
    );
  }
}

/// Spacing scale. Nothing outside these seven values.
///
/// Rhythm is not uniform: related things sit at [xs]–[sm], sections separate at
/// [lg]–[xl]. The same gap everywhere reads as machine-generated.
abstract final class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page gutter on a phone.
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: lg);

  /// Interior padding of a card.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Content is clamped to this width so a tablet does not render one
  /// enormously wide column.
  static const double contentMaxWidth = 640;

  /// At or above this width, teacher-facing screens may go two-pane.
  static const double twoPaneBreakpoint = 840;

  /// Minimum tap target on every side.
  static const double minTapTarget = 48;
}

/// Corner radii. Three values plus a pill — nothing else.
abstract final class AppRadius {
  /// Chips, badges, icon tiles, skeleton blocks.
  static const double sm = 8;

  /// Buttons, inputs, small cards.
  static const double md = 14;

  /// Cards, sheets, dialogs. The ceiling: a small card above this rounds into
  /// a blob.
  static const double lg = 20;

  /// Status chips, avatars, filter pills.
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Elevation. Three levels, and level 0 — a hairline with a whisper of shadow —
/// is the default for every card in the app.
abstract final class AppElevation {
  /// Default cards: a soft, barely-there drop that lifts the card off the page
  /// without a visible shadow band.
  static List<BoxShadow> e0(Color shadow) => [
    BoxShadow(
      color: shadow.withValues(alpha: 0.04),
      blurRadius: 16,
      spreadRadius: -6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Floating bars and raised sheets.
  static List<BoxShadow> e1(Color shadow) => [
    BoxShadow(
      color: shadow.withValues(alpha: 0.06),
      blurRadius: 20,
      spreadRadius: -10,
      offset: const Offset(0, 4),
    ),
  ];

  /// Dialogs, menus, popovers.
  static List<BoxShadow> e2(Color shadow) => [
    BoxShadow(
      color: shadow.withValues(alpha: 0.12),
      blurRadius: 30,
      spreadRadius: -8,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Motion. Reports state change; never entertains.
///
/// Continuous animation is banned outright — no `repeat()`, no pulsing dots, no
/// animated backgrounds. The one exception is a loading skeleton, which stops
/// when content arrives.
abstract final class AppMotion {
  /// Press, ripple, chip toggle.
  static const Duration tap = Duration(milliseconds: 120);

  /// Content appear, banner, list stagger.
  static const Duration enter = Duration(milliseconds: 200);

  /// Bottom sheet, dialog, page transition. The ceiling.
  static const Duration sheet = Duration(milliseconds: 320);

  /// Entering and most state change.
  static const Cubic standard = Cubic(0.2, 0, 0, 1);

  /// Exits.
  static const Curve exit = Curves.easeOut;

  /// Press feedback scale. No overshoot: a bouncing dialog reads as dated.
  static const double pressScale = 0.97;
}

/// Reads design tokens off the active theme.
extension AppThemeContext on BuildContext {
  /// Semantic colours for the active theme.
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;

  /// Type styles Material has no slot for.
  AppTypeExtras get typeExtras => Theme.of(this).extension<AppTypeExtras>()!;

  /// Material's text scale, already themed.
  TextTheme get text => Theme.of(this).textTheme;

  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  /// True when the user has asked the platform to reduce motion. Animations
  /// must fall back to an instant state change, not a slower one.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
