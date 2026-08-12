import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// One number, one label, one optional delta. Tabular figures throughout so a
/// row of tiles lines up.
///
/// Replaces hero-metric grids of invented numbers with no basis — per
/// `DESIGN.md` §08, a number on screen must trace back to real activity or a
/// backend response. This widget only renders what it's given; it never
/// computes a percentile or a rank on its own.
class NexusStatTile extends StatelessWidget {
  const NexusStatTile({
    super.key,
    required this.value,
    required this.label,
    this.delta,
    this.deltaPositive,
    this.icon,
    this.iconColor,
    this.bordered = true,
    this.centered = false,
  });

  /// The headline figure, already formatted (e.g. "82%", "14").
  final String value;

  final String label;

  /// Optional trailing figure (e.g. "+3 today"). Coloured by [deltaPositive]
  /// when set; neutral (inkMuted) otherwise. Ignored when [centered].
  final String? delta;

  /// `true` colours [delta] with [AppTokens.statusPresent], `false` with
  /// [AppTokens.statusAbsent]. Leave null for a neutral delta.
  final bool? deltaPositive;

  final IconData? icon;

  /// Overrides the icon's default `inkMuted` — some overview rows use a
  /// distinct colour per metric (XP, streak, children count).
  final Color? iconColor;

  /// Set false to render just the icon/value/label content with no card
  /// chrome, for embedding inside a row of metrics that already sits inside
  /// one enclosing card — cards must never nest.
  final bool bordered;

  /// Centers icon/value/label instead of the default left alignment, for a
  /// compact metric sitting in an `Expanded` column of a `Row`.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final deltaColor = switch (deltaPositive) {
      true => t.statusPresent,
      false => t.statusAbsent,
      null => t.inkMuted,
    };

    final content = Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: iconColor ?? t.inkMuted),
          const SizedBox(height: AppSpace.xs),
        ],
        Text(value, style: context.typeExtras.figureLg.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.xxs),
        if (centered)
          Text(
            label,
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: context.text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (delta != null) ...[
                const SizedBox(width: AppSpace.xs),
                Text(
                  delta!,
                  style: context.typeExtras.figure.copyWith(
                    color: deltaColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
      ],
    );

    if (!bordered) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: t.border),
        boxShadow: AppElevation.e0(t.shadow),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: content,
      ),
    );
  }
}
