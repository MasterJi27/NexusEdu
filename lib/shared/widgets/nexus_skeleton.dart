import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// A loading placeholder shaped like the content that is coming.
///
/// This is the only place in the app allowed to run a repeating animation, and
/// it stops the moment content arrives. Everything else — pulsing status dots,
/// drifting gradients, particle fields — is banned by `DESIGN.md` section 06.
///
/// Prefer a skeleton over a spinner: a spinner tells the user to wait, a
/// skeleton tells them what they are waiting for.
class NexusSkeleton extends StatefulWidget {
  const NexusSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  /// A single text line.
  const NexusSkeleton.line({Key? key, double? width})
    : this(key: key, width: width, height: 14);

  /// A leading avatar or icon tile.
  const NexusSkeleton.avatar({Key? key, double size = 40})
    : this(key: key, width: size, height: size);

  /// A whole block, such as a result card body.
  const NexusSkeleton.block({Key? key, double height = 96})
    : this(key: key, height: height, radius: AppRadius.md);

  final double? width;
  final double height;
  final double radius;

  @override
  State<NexusSkeleton> createState() => _NexusSkeletonState();
}

class _NexusSkeletonState extends State<NexusSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the platform reduce-motion setting: a static block, not a slower
    // pulse.
    if (context.reduceMotion) {
      _controller?.stop();
    } else if (!_controller!.isAnimating) {
      _controller!.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final block = SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.border,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );

    if (context.reduceMotion) {
      return Opacity(opacity: 0.7, child: block);
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      ),
      child: block,
    );
  }
}

/// A skeleton shaped like a list of rows — the shape most loading states in
/// this app actually need.
class NexusSkeletonList extends StatelessWidget {
  const NexusSkeletonList({super.key, this.rows = 3, this.showAvatar = true});

  final int rows;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: List.generate(rows, (i) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          decoration: BoxDecoration(
            border: i == rows - 1
                ? null
                : Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatar) ...[
                const NexusSkeleton.avatar(),
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NexusSkeleton.line(),
                    const SizedBox(height: AppSpace.xs),
                    // Second line is short, the way real text wraps.
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      alignment: Alignment.centerLeft,
                      child: const NexusSkeleton.line(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
