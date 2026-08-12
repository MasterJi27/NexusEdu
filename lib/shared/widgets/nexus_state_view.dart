import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_skeleton.dart';

/// The three states every data-loading surface owes the user, in one widget:
/// loading, empty, and error.
///
/// The project's own design export specified all three; the app shipped none of
/// them, which is why so many screens end at an infinite spinner or a blank
/// area. A screen that only implements "has data" is unfinished.
///
/// ```dart
/// if (loading) return const NexusStateView.loading();
/// if (error != null) return NexusStateView.error(message: error, onRetry: load);
/// if (items.isEmpty) {
///   return NexusStateView.empty(
///     title: 'No notes yet',
///     description: 'Notes you save from any AI tool show up here.',
///     actionLabel: 'Open the tutor',
///     onAction: () => context.push('/tutor'),
///   );
/// }
/// ```
class NexusStateView extends StatelessWidget {
  const NexusStateView._({
    required this._kind,
    this.title,
    this.description,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.skeletonRows = 3,
  });

  /// A skeleton shaped like the content that is coming.
  const NexusStateView.loading({int rows = 3})
    : this._(kind: _StateKind.loading, skeletonRows: rows);

  /// Says what goes here and offers one way to get it. No illustration: a line
  /// of type and a button beats clip art.
  const NexusStateView.empty({
    required String title,
    String? description,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) : this._(
         kind: _StateKind.empty,
         title: title,
         description: description,
         icon: icon,
         actionLabel: actionLabel,
         onAction: onAction,
       );

  /// Names the cause and the next step. Never surfaces a raw exception.
  const NexusStateView.error({
    required String message,
    String title = 'Something went wrong',
    VoidCallback? onRetry,
    String retryLabel = 'Try again',
  }) : this._(
         kind: _StateKind.error,
         title: title,
         description: message,
         icon: Icons.cloud_off_outlined,
         actionLabel: retryLabel,
         onAction: onRetry,
       );

  final _StateKind _kind;
  final String? title;
  final String? description;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int skeletonRows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_kind == _StateKind.loading) {
      return Semantics(
        label: 'Loading',
        liveRegion: true,
        child: NexusSkeletonList(rows: skeletonRows),
      );
    }

    final isError = _kind == _StateKind.error;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.xl,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.brLg,
        // Dashed is not available on a BoxDecoration border; a hairline plus the
        // muted icon is enough to read as a placeholder rather than content.
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            size: 32,
            color: isError ? t.statusAbsent : t.inkFaint,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            title!,
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.md),
            NexusButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: NexusButtonVariant.secondary,
              size: NexusButtonSize.small,
            ),
          ],
        ],
      ),
    );
  }
}

enum _StateKind { loading, empty, error }
