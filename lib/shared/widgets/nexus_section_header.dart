import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// A section title with an optional trailing action.
///
/// Owns its own spacing so the rhythm is consistent: more room above the heading
/// than below it. A heading sitting closer to the block before it than to its
/// own content is a layout defect, and it was everywhere.
class NexusSectionHeader extends StatelessWidget {
  const NexusSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.spaceAbove = AppSpace.xl,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Set to zero for the first section on a screen, where the app bar already
  /// provides the separation.
  final double spaceAbove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: spaceAbove, bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpace.xxs),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                minimumSize: const Size(0, AppSpace.minTapTarget),
                textStyle: context.text.labelMedium,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
