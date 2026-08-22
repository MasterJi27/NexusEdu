import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// App-bar brand mark: organization logo + name when the account has
/// branding set, otherwise a fallback title text. Used by the teacher
/// surfaces (Home, Notes studio) so the school identity travels with the
/// app bar instead of sitting in one screen.
class OrgBrandMark extends StatelessWidget {
  const OrgBrandMark({
    super.key,
    required this.fallbackTitle,
    this.name,
    this.logoUrl,
    this.subtitle,
  });

  final String fallbackTitle;
  final String? name;
  final String? logoUrl;

  /// Optional subtitle shown beneath the org name when branding is present.
  /// When null and branding is present, [fallbackTitle] is reused as subtitle
  /// so the screen context ("Teacher home", "Notes studio", "Institute") is
  /// not lost once the org name takes over the title slot.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasLogo = logoUrl?.isNotEmpty == true;
    final hasName = name?.isNotEmpty == true;
    if (!hasName && !hasLogo) {
      return Text(
        fallbackTitle,
        style: context.text.headlineSmall?.copyWith(color: t.ink),
      );
    }
    final displayName = hasName ? name! : fallbackTitle;
    // When branding is shown, keep screen context visible as subtitle.
    // Explicit subtitle wins; otherwise fallbackTitle becomes the subtitle
    // when it differs from the displayed name.
    String? effectiveSubtitle = subtitle;
    if (effectiveSubtitle == null &&
        hasName &&
        fallbackTitle.isNotEmpty &&
        fallbackTitle != displayName) {
      effectiveSubtitle = fallbackTitle;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLogo)
          ClipRRect(
            borderRadius: AppRadius.brSm,
            child: CachedNetworkImage(
              imageUrl: logoUrl!,
              width: 26,
              height: 26,
              memCacheWidth: 52,
              fit: BoxFit.cover,
              placeholder: (c, u) => const SizedBox(width: 26, height: 26),
              errorWidget: (c, u, e) => Icon(
                Icons.business_outlined,
                size: 22,
                color: t.inkMuted,
              ),
            ),
          ),
        if (hasLogo) const SizedBox(width: AppSpace.xs),
        Flexible(
          child: effectiveSubtitle == null
              ? Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineSmall?.copyWith(color: t.ink),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      effectiveSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: t.inkMuted),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}