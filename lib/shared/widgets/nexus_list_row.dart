import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/utils/tap_debounce.dart';

/// A leading icon, a title, an optional subtitle, and an optional trailing
/// widget — one row shape for saved items, history entries, and settings
/// links, instead of every screen hand-rolling its own `Row`/`ListTile`.
class NexusListRow extends StatelessWidget {
  const NexusListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.iconColor,
    this.titleColor,
    this.trailing,
    this.onTap,
    this.onDismissed,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;

  /// Overrides the leading icon's default `primary` — a destructive row
  /// (e.g. "Delete") should pass `statusAbsent` here.
  final Color? iconColor;

  /// Overrides the title's default `ink` — pairs with [iconColor] for a
  /// destructive row.
  final Color? titleColor;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// Set to make the row swipe-to-dismiss (e.g. delete a saved item).
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final row = InkWell(
      onTap: onTap == null
          ? null
          : () {
              if (TapDebounce.ready()) onTap!();
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpace.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconColor == null ? t.primaryTint : iconColor!.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xs),
                    child: Icon(leadingIcon, size: 20, color: iconColor ?? t.primary),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(color: titleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );

    if (onDismissed == null) return row;

    return Dismissible(
      key: ValueKey('$title-$subtitle'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed!(),
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: t.statusAbsent.withValues(alpha: 0.12),
          borderRadius: AppRadius.brMd,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Icon(Icons.delete_outline, color: t.statusAbsent),
          ),
        ),
      ),
      child: row,
    );
  }
}
