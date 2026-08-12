import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// A labelled row of selectable chips.
///
/// This replaces the hand-rolled `_buildSelectorRow` helper that was copied into
/// dozens of feature screens — each one a `Wrap` of `GestureDetector` +
/// `Container` + hardcoded `deepPurpleAccent`, each one slightly different, none
/// of them accessible.
///
/// Single-select:
/// ```dart
/// NexusChipGroup(
///   label: 'Subject',
///   options: subjects,
///   selected: {_subject},
///   onChanged: (s) => setState(() => _subject = s.first),
/// )
/// ```
class NexusChipGroup extends StatelessWidget {
  const NexusChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
    this.multiSelect = false,
    this.allowEmpty = false,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// Field label above the chips. Say it once — do not repeat it as a hint.
  final String? label;

  final bool multiSelect;

  /// Single-select groups normally always keep one selection. Set true to allow
  /// deselecting down to nothing (an "All" filter, for example).
  final bool allowEmpty;

  void _toggle(String option) {
    final isSelected = selected.contains(option);
    if (multiSelect) {
      final next = Set<String>.of(selected);
      if (isSelected) {
        if (next.length > 1 || allowEmpty) next.remove(option);
      } else {
        next.add(option);
      }
      onChanged(next);
      return;
    }
    if (isSelected && allowEmpty) {
      onChanged(const {});
    } else if (!isSelected) {
      onChanged({option});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: context.text.labelMedium),
          const SizedBox(height: AppSpace.xs),
        ],
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return _Chip(
              label: option,
              isSelected: isSelected,
              // Announced as a real control, with its selected state, which the
              // hand-rolled GestureDetector version never was.
              onTap: () => _toggle(option),
              tokens: t,
              multiSelect: multiSelect,
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
    required this.multiSelect,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppTokens tokens;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !multiSelect,
      inMutuallyExclusiveGroup: !multiSelect,
      checked: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? tokens.primaryTint : tokens.surface,
        borderRadius: AppRadius.brSm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brSm,
          child: Container(
            // 36dp tall inside a Wrap keeps chips compact while the row itself
            // stays above the 48dp target with its run spacing.
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brSm,
              border: Border.all(
                color: isSelected ? tokens.primaryTintBorder : tokens.border,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: isSelected ? tokens.primary : tokens.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
