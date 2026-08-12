import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';

/// The shell shared by every "type something, generate, read the result" AI
/// tool screen — roughly sixty of them: solver, notes, flashcards, mnemonics,
/// study plans, essay evaluation, and more. Each one previously hand-rolled the
/// same 300-500 line `Scaffold` + input card + generate button + result card +
/// saved-history list, each with its own hardcoded colours and its own bugs.
///
/// A screen using this shell owns only its domain logic: what the input form
/// asks for, what the AI call returns, and how a saved item renders. Everything
/// structural — the app bar, the loading/empty/error states the design export
/// specified and no screen actually built, the result card chrome, the history
/// list — lives here once.
///
/// ```dart
/// class MnemonicGenScreen extends StatefulWidget {
///   ...
/// }
/// class _State extends State<MnemonicGenScreen> {
///   @override
///   Widget build(BuildContext context) {
///     return AiToolScaffold(
///       title: 'Mnemonic Generator',
///       inputForm: Column(children: [...]),
///       generateLabel: 'Generate tricks',
///       isGenerating: _isLoading,
///       onGenerate: _generateTricks,
///       result: _result,
///       errorText: _error,
///       history: _saved.map((m) => NexusListRow(...)).toList(),
///     );
///   }
/// }
/// ```
class AiToolScaffold extends StatelessWidget {
  const AiToolScaffold({
    super.key,
    required this.title,
    required this.inputForm,
    required this.generateLabel,
    required this.onGenerate,
    this.subtitle,
    this.isGenerating = false,
    this.result,
    this.resultBuilder,
    this.errorText,
    this.onRetry,
    this.historyTitle = 'Saved',
    this.history = const [],
    this.onCopy,
    this.onShare,
    this.actions,
  });

  final String title;
  final String? subtitle;

  /// The screen-specific input controls: text fields, chip groups, selectors.
  final Widget inputForm;

  final String generateLabel;
  final VoidCallback? onGenerate;
  final bool isGenerating;

  /// Plain-text or markdown result. Ignored when [resultBuilder] is set.
  final String? result;

  /// For screens whose result needs custom rendering (e.g. a rendered diagram)
  /// instead of the default selectable-text card.
  final WidgetBuilder? resultBuilder;

  /// Set when the last generate call failed. Shown as a state view with retry,
  /// never as a raw exception string.
  final String? errorText;
  final VoidCallback? onRetry;

  final String historyTitle;
  final List<Widget> history;

  /// Shown as icon actions on the result card when the result is non-empty.
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  /// Extra app-bar actions (e.g. a settings or filter icon).
  final List<Widget>? actions;

  bool get _hasResult =>
      resultBuilder != null || (result != null && result!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: title,
      actions: actions,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          if (subtitle != null) ...[
            Text(subtitle!, style: context.text.bodySmall),
            const SizedBox(height: AppSpace.md),
          ],
          NexusCard(child: inputForm),
          const SizedBox(height: AppSpace.md),
          NexusButton(
            label: generateLabel,
            onPressed: isGenerating ? null : onGenerate,
            isLoading: isGenerating,
            fullWidth: true,
            icon: Icons.auto_awesome,
          ),
          if (isGenerating) ...[
            const SizedBox(height: AppSpace.lg),
            const NexusStateView.loading(rows: 4),
          ] else if (errorText != null) ...[
            const SizedBox(height: AppSpace.lg),
            NexusStateView.error(
              message: errorText!,
              onRetry: onRetry,
            ),
          ] else if (_hasResult) ...[
            const SizedBox(height: AppSpace.lg),
            const NexusSectionHeader(title: 'Result'),
            const SizedBox(height: AppSpace.xs),
            _ResultCard(
              builder: resultBuilder,
              text: result,
              onCopy: onCopy,
              onShare: onShare,
            ),
          ],
          if (history.isNotEmpty) ...[
            NexusSectionHeader(title: historyTitle),
            ...history,
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({this.builder, this.text, this.onCopy, this.onShare});

  final WidgetBuilder? builder;
  final String? text;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onCopy != null || onShare != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCopy != null)
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: 'Copy',
                    onPressed: onCopy,
                  ),
                if (onShare != null)
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    tooltip: 'Share',
                    onPressed: onShare,
                  ),
              ],
            ),
          if (builder != null)
            builder!(context)
          else
            SelectableText(text ?? '', style: context.text.bodyLarge),
        ],
      ),
    );
  }
}
