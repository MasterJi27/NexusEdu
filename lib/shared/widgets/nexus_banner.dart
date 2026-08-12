import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

enum NexusBannerKind { info, warning, error }

/// An inline banner for a message that belongs in the page, not a transient
/// `SnackBar`. Replaces the pattern of surfacing a raw exception string in a
/// `SnackBar(content: Text('$e'))`.
class NexusBanner extends StatelessWidget {
  const NexusBanner({
    super.key,
    required this.message,
    this.kind = NexusBannerKind.info,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final NexusBannerKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (Color fg, Color tint, Color border, IconData icon) = switch (kind) {
      NexusBannerKind.info => (t.primary, t.primaryTint, t.primaryTintBorder, Icons.info_outline),
      NexusBannerKind.warning => (t.statusLate, t.secondaryTint, t.statusLate.withValues(alpha: 0.3), Icons.warning_amber_rounded),
      NexusBannerKind.error => (t.statusAbsent, t.statusAbsent.withValues(alpha: 0.1), t.statusAbsent.withValues(alpha: 0.3), Icons.error_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              message,
              style: context.text.bodySmall?.copyWith(color: t.ink),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: context.text.labelMedium?.copyWith(color: fg)),
            ),
        ],
      ),
    );
  }
}
