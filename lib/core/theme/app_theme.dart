import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// Builds the app's two themes from the tokens in [AppTokens].
///
/// Both themes are real and complete. Light is the default and the one designed
/// first; dark is a second designed theme, not an inversion. (Before this, the
/// light getter returned the dark theme, so the theme switch in Settings changed
/// nothing.)
///
/// The two [ThemeData] objects are built once and cached. They used to be
/// constructed on every access, and `main.dart` reads both inside a
/// `ListenableBuilder`, so every settings change rebuilt two full themes and
/// re-resolved two Google Fonts text themes.
abstract final class AppTheme {
  static ThemeData? _light;
  static ThemeData? _dark;

  static ThemeData get lightTheme => _light ??= _build(AppTokens.light, Brightness.light);
  static ThemeData get darkTheme => _dark ??= _build(AppTokens.dark, Brightness.dark);

  /// Type pairing: Fraunces (display headings only) + IBM Plex Sans
  /// (everything functional) + IBM Plex Mono (tabular figures). See
  /// `DESIGN.md` section 03 for the rationale.
  ///
  /// Each weight used anywhere in the app is resolved once as its own variant,
  /// because `GoogleFonts.<family>()` only loads the closest matching weight
  /// for the call and FontWeight in a later `copyWith` does not re-resolve it.
  /// The corresponding files live in `assets/fonts/` named
  /// `<family>-<variant>.ttf`; with `allowRuntimeFetching = false` (set in
  /// `main.dart`) a missing file fails loudly instead of fetching at runtime.
  static final TextStyle _display = GoogleFonts.fraunces(
    fontWeight: FontWeight.w600,
  );
  static final TextStyle _body = GoogleFonts.ibmPlexSans(
    fontWeight: FontWeight.w400,
  );
  static final TextStyle _bodyStrong = GoogleFonts.ibmPlexSans(
    fontWeight: FontWeight.w600,
  );
  static final TextStyle _mono = GoogleFonts.ibmPlexMono(
    fontWeight: FontWeight.w500,
  );
  static final TextStyle _monoStrong = GoogleFonts.ibmPlexMono(
    fontWeight: FontWeight.w600,
  );

  static TextTheme _textTheme(AppTokens t) {
    return TextTheme(
      // Fraunces SemiBold — headings only.
      displaySmall: _display.copyWith(
        fontSize: 32,
        height: 36 / 32,
        letterSpacing: -0.64,
        color: t.ink,
      ),
      headlineMedium: _display.copyWith(
        fontSize: 24,
        height: 30 / 24,
        letterSpacing: -0.24,
        color: t.ink,
      ),
      headlineSmall: _display.copyWith(
        fontSize: 20,
        height: 26 / 20,
        letterSpacing: -0.2,
        color: t.ink,
      ),
      // IBM Plex Sans — everything functional.
      titleMedium: _bodyStrong.copyWith(
        fontSize: 17,
        height: 24 / 17,
        color: t.ink,
      ),
      titleSmall: _bodyStrong.copyWith(
        fontSize: 15,
        height: 20 / 15,
        color: t.ink,
      ),
      bodyLarge: _body.copyWith(
        fontSize: 15,
        height: 22 / 15,
        color: t.ink,
      ),
      bodyMedium: _body.copyWith(
        fontSize: 15,
        height: 22 / 15,
        color: t.ink,
      ),
      bodySmall: _body.copyWith(
        fontSize: 13,
        height: 19 / 13,
        color: t.inkMuted,
      ),
      labelLarge: _bodyStrong.copyWith(
        fontSize: 15,
        height: 20 / 15,
        color: t.ink,
      ),
      labelMedium: _bodyStrong.copyWith(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.12,
        color: t.inkMuted,
      ),
      labelSmall: _bodyStrong.copyWith(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.12,
        color: t.inkMuted,
      ),
    );
  }

  static AppTypeExtras _typeExtras(AppTokens t) {
    return AppTypeExtras(
      figure: _mono.copyWith(
        fontSize: 15,
        height: 20 / 15,
        color: t.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      figureLg: _monoStrong.copyWith(
        fontSize: 28,
        height: 32 / 28,
        letterSpacing: -0.28,
        color: t.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      bodyStrong: _bodyStrong.copyWith(
        fontSize: 15,
        height: 22 / 15,
        color: t.ink,
      ),
    );
  }

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final textTheme = _textTheme(t);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.primaryTint,
      onPrimaryContainer: t.primary,
      secondary: t.secondary,
      onSecondary: t.onPrimary,
      secondaryContainer: t.secondaryTint,
      onSecondaryContainer: t.secondary,
      error: t.statusAbsent,
      onError: t.onPrimary,
      errorContainer: t.statusAbsent.withValues(alpha: 0.12),
      onErrorContainer: t.statusAbsent,
      surface: t.surface,
      onSurface: t.ink,
      surfaceContainerLowest: t.page,
      surfaceContainerLow: t.page,
      surfaceContainer: t.surfaceAlt,
      surfaceContainerHigh: t.surfaceAlt,
      surfaceContainerHighest: t.surfaceAlt,
      onSurfaceVariant: t.inkMuted,
      outline: t.border,
      outlineVariant: t.border,
      shadow: t.shadow,
      scrim: t.shadow,
      inverseSurface: t.ink,
      onInverseSurface: t.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: t.page,
      canvasColor: t.page,
      dividerColor: t.border,
      splashFactory: InkSparkle.splashFactory,
      extensions: [t, _typeExtras(t)],

      appBarTheme: AppBarTheme(
        backgroundColor: t.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: t.ink, size: 24),
      ),

      dividerTheme: DividerThemeData(
        color: t.border,
        thickness: 1,
        space: 1,
      ),

      // Level 0: a hairline with a whisper of shadow. The default for every card.
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: BorderSide(color: t.border),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.primaryTint,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.brPill,
        ),
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium!.copyWith(
            color: selected ? t.primary : t.inkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? t.primary : t.inkMuted,
          );
        }),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: t.statusAbsent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: t.statusAbsent, width: 2),
        ),
        hintStyle: textTheme.bodyMedium!.copyWith(color: t.inkFaint),
        labelStyle: textTheme.labelMedium,
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall!.copyWith(color: t.statusAbsent),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          disabledBackgroundColor: t.surfaceAlt,
          disabledForegroundColor: t.inkFaint,
          minimumSize: const Size(0, AppSpace.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size(0, AppSpace.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: t.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          minimumSize: const Size(0, AppSpace.minTapTarget),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.inkMuted,
          minimumSize: const Size(
            AppSpace.minTapTarget,
            AppSpace.minTapTarget,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.primaryTint,
        side: BorderSide(color: t.border),
        labelStyle: textTheme.labelMedium!.copyWith(color: t.ink),
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(color: t.primary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        showCheckmark: false,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: t.shadow.withValues(alpha: 0.4),
        showDragHandle: true,
        dragHandleColor: t.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: BorderSide(color: t.border),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: t.surface),
        actionTextColor: t.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.surfaceAlt,
        circularTrackColor: t.surfaceAlt,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onPrimary : t.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.all(t.border),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: t.inkMuted,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        minVerticalPadding: AppSpace.sm,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: t.primary,
        unselectedLabelColor: t.inkMuted,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorColor: t.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: t.border,
      ),

      // Android is the only shipping target. Fade-forwards is the current
      // Material spec transition: no overshoot, inside the 320ms ceiling.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
