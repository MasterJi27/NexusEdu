import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/utils/tap_debounce.dart';

/// The app's one card surface: elevation level 0 — a 1px border with a whisper
/// of shadow (`AppElevation.e0`).
///
/// Replaces the previous glassmorphic implementation, which wrapped every card
/// in a `BackdropFilter` blur. That cost a full-surface blur per card per frame
/// on devices that can least afford it, and read as generated UI. The current
/// surface keeps the softness (rounded corners, quiet shadow) without the blur.
///
/// Cards do not nest. If you are putting a [NexusCard] inside a [NexusCard],
/// use a [Divider], a heading, or spacing instead.
class NexusCard extends StatelessWidget {
  const NexusCard({
    super.key,
    required this.child,
    this.padding = AppSpace.card,
    this.margin,
    this.onTap,
    this.borderColor,
    this.background,
    this.elevated = false,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// When set, the whole card is a tap target with a ripple.
  final VoidCallback? onTap;

  /// Overrides the hairline. Use a status colour only to mark state, never for
  /// decoration.
  final Color? borderColor;

  /// Overrides the surface. Use a tint token, not a raw colour.
  final Color? background;

  /// Promotes the card to elevation level 1. Reserve for surfaces that genuinely
  /// float above content, such as a sticky bar.
  final bool elevated;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = InkWell(
        onTap: () {
          if (TapDebounce.ready()) onTap!();
        },
        borderRadius: AppRadius.brLg,
        child: content,
      );
    }

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? t.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: borderColor ?? t.border),
        boxShadow: elevated ? AppElevation.e1(t.shadow) : AppElevation.e0(t.shadow),
      ),
      child: ClipRRect(borderRadius: AppRadius.brLg, child: content),
    );

    if (semanticLabel != null) {
      card = Semantics(label: semanticLabel, container: true, child: card);
    }

    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}
