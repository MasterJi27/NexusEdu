import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/utils/tap_debounce.dart';

enum NexusButtonVariant {
  /// Solid accent. One per screen region — the single most important action.
  primary,

  /// Bordered. The common secondary action.
  secondary,

  /// Text only. Tertiary actions and inline links.
  ghost,

  /// Destructive. Delete, revoke, remove.
  danger,
}

enum NexusButtonSize { medium, small }

/// The app's button.
///
/// Replaces an implementation that painted a cyan-to-violet gradient with a
/// violet glow shadow and 1.2px letter-spacing on the label — three separate
/// generated-UI tells in one widget. This one is a solid fill, no gradient, no
/// glow, and it respects the 48dp minimum tap target.
class NexusButton extends StatelessWidget {
  const NexusButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = NexusButtonVariant.primary,
    this.size = NexusButtonSize.medium,
    this.isLoading = false,
    this.fullWidth = false,
  });

  final String label;

  /// Null disables the button. A disabled button still announces itself to
  /// screen readers.
  final VoidCallback? onPressed;

  final IconData? icon;
  final NexusButtonVariant variant;
  final NexusButtonSize size;

  /// Shows a spinner in place of the icon and blocks taps. The label stays
  /// visible so the button does not change width mid-action.
  final bool isLoading;

  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onPressed != null && !isLoading;
    final height = size == NexusButtonSize.medium
        ? AppSpace.minTapTarget
        : 40.0;
    final hPad = size == NexusButtonSize.medium ? AppSpace.lg : AppSpace.md;

    final (Color bg, Color fg, Color? borderColor) = switch (variant) {
      NexusButtonVariant.primary => (t.primary, t.onPrimary, null),
      NexusButtonVariant.secondary => (t.surface, t.ink, t.border),
      NexusButtonVariant.ghost => (Colors.transparent, t.primary, null),
      NexusButtonVariant.danger => (t.statusAbsent, t.onPrimary, null),
    };

    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: enabled ? fg : t.inkFaint,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (isLoading || icon != null) const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final disabledBg = variant == NexusButtonVariant.ghost
        ? Colors.transparent
        : t.surfaceAlt;

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? disabledBg : bg,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? t.inkFaint : fg,
      ),
      overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.08)),
      minimumSize: WidgetStatePropertyAll(
        Size(fullWidth ? double.infinity : 0, height),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: hPad),
      ),
      textStyle: WidgetStatePropertyAll(
        size == NexusButtonSize.medium
            ? context.text.labelLarge
            : context.text.labelMedium?.copyWith(color: fg),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor),
        ),
      ),
      // No overshoot on press: scale-with-bounce reads as dated.
      animationDuration: AppMotion.tap,
    );

    return TextButton(
      onPressed: enabled
          ? () {
              if (TapDebounce.ready()) onPressed!();
            }
          : null,
      style: style,
      child: child,
    );
  }
}
