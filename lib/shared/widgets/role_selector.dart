import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

class _RoleOption {
  const _RoleOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

const List<_RoleOption> _roles = [
  _RoleOption(value: 'student', label: 'Student', icon: Icons.school_outlined),
  _RoleOption(
    value: 'parent',
    label: 'Parent',
    icon: Icons.family_restroom_outlined,
  ),
  _RoleOption(
    value: 'teacher',
    label: 'Teacher',
    icon: Icons.co_present_outlined,
  ),
];

/// "I am a…" Student/Parent/Teacher selector used on the login and signup
/// screens. The chosen role decides which dashboard the account lands on.
class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _roles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.xs),
          Expanded(
            child: _RoleCard(
              option: _roles[i],
              selected: value == _roles[i].value,
              onTap: () => onChanged(_roles[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _RoleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.primaryTint : t.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(
          color: selected ? t.primary : t.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 22,
                color: selected ? t.primary : t.inkMuted,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                  color: selected ? t.primary : t.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
