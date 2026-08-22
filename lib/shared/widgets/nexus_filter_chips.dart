import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// Reusable horizontal chip group — replaces 8 duplicated ChoiceChip blocks.
class NexusFilterChips<T> extends StatelessWidget {
  const NexusFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelBuilder,
    this.multiSelected,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String Function(T)? labelBuilder;
  /// Optional set for multi-select use cases (e.g. onboarding subjects).
  final Set<T>? multiSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: options.map((o) {
        final isSelected = multiSelected != null ? multiSelected!.contains(o) : o == selected;
        final label = labelBuilder?.call(o) ?? o.toString();
        return ChoiceChip(
          label: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: isSelected ? t.page : t.ink,
            ),
          ),
          selected: isSelected,
          selectedColor: t.ink,
          backgroundColor: t.surfaceAlt,
          onSelected: (v) {
            if (multiSelected != null) {
              onSelected(o);
            } else if (v) {
              onSelected(o);
            }
          },
        );
      }).toList(),
    );
  }
}
