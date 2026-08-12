import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// The app's generic scaffold shell: background, app bar, safe area, and the
/// tablet max-width clamp, all in one place.
///
/// Replaces ~90 copies of `Scaffold(backgroundColor: ..., appBar: AppBar(...),
/// body: SafeArea(child: ...))` scattered across `lib/features/**`, each with
/// its own small drift from the others — some skip `SafeArea` entirely
/// (a status-bar clipping defect waiting to happen), none clamp width on a
/// tablet, and each one hand-rolls the immersive/full-bleed variant
/// differently. [body] is a plain widget, not a forced list, so a screen that
/// switches between loading/empty/error/content bodies keeps doing that
/// itself — this shell only owns the chrome around it.
class NexusScreen extends StatelessWidget {
  const NexusScreen({
    super.key,
    required this.title,
    required this.body,
    this.titleWidget,
    this.actions,
    this.onRefresh,
    this.floatingActionButton,
    this.applyTabletMaxWidth = true,
    this.backgroundColor,
    this.transparentAppBar = false,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  /// Overrides the default `Text(title)` app bar title with a custom widget
  /// (e.g. a logo mark beside the wordmark). [title] is still required and
  /// used for the route's semantic/accessibility label.
  final Widget? titleWidget;

  /// When set, wraps [body] in a [RefreshIndicator].
  final Future<void> Function()? onRefresh;

  final Widget? floatingActionButton;

  /// Clamps [body] to [AppSpace.contentMaxWidth] and centres it, so a
  /// 1024dp-wide tablet does not render one full-bleed column. Full-bleed
  /// screens (video, camera, onboarding) opt out.
  final bool applyTabletMaxWidth;

  /// Overrides the scaffold background. Defaults to [AppTokens.page].
  final Color? backgroundColor;

  /// Immersive screens set this to remove the app bar's background and
  /// elevation so content shows through behind it.
  final bool transparentAppBar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Widget content = body;
    if (applyTabletMaxWidth) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpace.contentMaxWidth),
          child: content,
        ),
      );
    }
    if (onRefresh != null) {
      content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? t.page,
      appBar: AppBar(
        title: titleWidget == null
            ? Text(title)
            : Semantics(label: title, child: titleWidget),
        actions: actions,
        backgroundColor: transparentAppBar ? Colors.transparent : null,
        elevation: transparentAppBar ? 0 : null,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: content),
    );
  }
}
