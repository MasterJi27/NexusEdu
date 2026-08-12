import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// Attendance status: present, absent, late, or on leave.
///
/// Reserved status colours per `DESIGN.md` section 02 — these four colours mean
/// this and nothing else in the whole app. Colour is never the only signal:
/// each chip carries its own text label, so the status still reads correctly
/// for a colour-blind teacher marking a register.
enum AttendanceStatus { present, absent, late, leave }

class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip({
    super.key,
    required this.status,
    this.onTap,
    this.dense = false,
  });

  final AttendanceStatus status;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (String label, Color fg, Color bg, IconData icon) = switch (status) {
      AttendanceStatus.present => ('Present', t.statusPresent, t.statusPresent.withValues(alpha: 0.12), Icons.check_circle_outline),
      AttendanceStatus.absent => ('Absent', t.statusAbsent, t.statusAbsent.withValues(alpha: 0.12), Icons.cancel_outlined),
      AttendanceStatus.late => ('Late', t.statusLate, t.statusLate.withValues(alpha: 0.12), Icons.schedule_outlined),
      // Deliberately colourless: leave/holiday competes with nothing.
      AttendanceStatus.leave => ('Leave', t.inkMuted, t.surfaceAlt, Icons.event_busy_outlined),
    };

    final chip = Container(
      constraints: BoxConstraints(minHeight: dense ? 28 : AppSpace.minTapTarget),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpace.xs : AppSpace.sm,
        vertical: dense ? 2 : AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 16, color: fg),
          const SizedBox(width: AppSpace.xxs),
          Text(
            label,
            style: (dense ? context.text.bodySmall : context.text.labelMedium)
                ?.copyWith(color: fg),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: '$label, tap to change',
      excludeSemantics: true,
      child: InkWell(onTap: onTap, borderRadius: AppRadius.brPill, child: chip),
    );
  }
}
