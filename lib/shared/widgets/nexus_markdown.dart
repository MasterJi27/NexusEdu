import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// Shared markdown widget — single `MarkdownStyleSheet` so `tutor_chat`,
/// `notes`, `topic_learning` etc. never duplicate 40-line `copyWith`.
class NexusMarkdown extends StatelessWidget {
  const NexusMarkdown(this.data, {super.key, this.selectable = true, this.shrinkWrap = false});

  final String data;
  final bool selectable;
  final bool shrinkWrap;

  static MarkdownStyleSheet styleOf(BuildContext context) {
    final t = context.tokens;
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: context.text.bodyMedium?.copyWith(height: 1.45),
      h1: context.text.headlineSmall,
      h2: context.text.titleLarge,
      h3: context.text.titleMedium,
      listBullet: context.text.bodyMedium?.copyWith(color: t.primary),
      strong: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      code: context.text.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: t.surfaceAlt,
        color: t.ink,
      ),
      codeblockDecoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: t.border),
      ),
      blockquoteDecoration: BoxDecoration(
        color: t.primaryTint,
        borderRadius: AppRadius.brSm,
        border: Border(left: BorderSide(color: t.primary)),
      ),
      blockquote: context.text.bodyMedium?.copyWith(
        color: t.inkMuted,
        fontStyle: FontStyle.italic,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      tableHead: context.text.labelMedium?.copyWith(
        color: t.ink,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final md = MarkdownBody(
      data: data.isEmpty ? '…' : data,
      selectable: selectable,
      styleSheet: styleOf(context),
    );
    if (shrinkWrap) return md;
    return SingleChildScrollView(child: md);
  }
}

/// Extension for callers that already have a SingleChildScrollView.
extension NexusMarkdownStyleX on BuildContext {
  MarkdownStyleSheet get markdownStyle => NexusMarkdown.styleOf(this);
}
