import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// A row of five stars, for display or as an input.
///
/// Replaces duplicated `Row(List.generate(5, ...))` star-rating rows that
/// appeared with their own hardcoded colours in each call site.
class NexusStarRating extends StatelessWidget {
  const NexusStarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 20,
    this.count = 5,
  });

  /// 0..[count]. Fractional values round down to the nearest whole star for
  /// display; input mode always reports whole numbers.
  final double rating;

  /// Null makes this a read-only display. Set to accept taps as input.
  final ValueChanged<int>? onChanged;

  final double size;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filled = rating.floor().clamp(0, count);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isFilled = index < filled;
        final star = Icon(
          isFilled ? Icons.star : Icons.star_border,
          size: size,
          color: isFilled ? t.secondaryFill : t.inkFaint,
        );
        if (onChanged == null) return star;
        return GestureDetector(
          onTap: () => onChanged!(index + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxs / 2),
            child: star,
          ),
        );
      }),
    );
  }
}
