import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/features/tutor/presentation/providers/tutor_provider.dart';

class TutorChatScreen extends ConsumerStatefulWidget {
  const TutorChatScreen({super.key});

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _xpDismissTimer;

  @override
  void dispose() {
    _xpDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleXpDismiss() {
    _xpDismissTimer?.cancel();
    _xpDismissTimer = Timer(const Duration(milliseconds: 2000), () {
      _xpDismissTimer = null;
      if (mounted) ref.read(tutorProvider.notifier).hideXpPopup();
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(tutorProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(tutorProvider);
    final notifier = ref.read(tutorProvider.notifier);
    final t = context.tokens;

    ref.listen(tutorProvider, (previous, next) {
      if (next.showXpPopup && (previous?.showXpPopup ?? false) == false) {
        _scheduleXpDismiss();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: t.primary,
              radius: 16,
              child: Icon(
                Icons.record_voice_over,
                color: t.onPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text('Nexus AI Tutor', style: context.text.titleMedium),
          ],
        ),
        actions: [
          Row(
            children: [
              Text('Voice', style: context.text.labelSmall),
              Switch(
                value: tutorState.isVoiceConversation,
                onChanged: (val) => notifier.toggleVoiceConversation(val),
                activeThumbColor: t.primary,
              ),
            ],
          ),
          Row(
            children: [
              Text('Debate', style: context.text.labelSmall),
              Switch(
                value: tutorState.isDebateMode,
                onChanged: (val) {
                  notifier.toggleDebateMode(val);
                },
                activeThumbColor: t.secondary,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.volume_off),
            onPressed: () => notifier.stopAudio(),
            tooltip: 'Stop Audio',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    AppSpace.sm,
                    AppSpace.md,
                    AppSpace.xs,
                  ),
                  itemCount:
                      tutorState.messages.length +
                      (tutorState.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (tutorState.isTyping && index == 0) {
                      return _buildTypingBubble();
                    }
                    final messageIndex = tutorState.isTyping
                        ? index - 1
                        : index;
                    final msg = tutorState.messages[messageIndex];
                    return _buildMessageBubble(
                      msg.text,
                      msg.isBot,
                      msg.timestamp,
                      tutorState.isDebateMode,
                    );
                  },
                ),
              ),
              _buildTutorTools(tutorState.selectedClass),
              _buildInputField(tutorState, notifier),
            ],
          ),
          if (tutorState.showXpPopup)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xl,
                  vertical: AppSpace.lg,
                ),
                decoration: BoxDecoration(
                  color: t.secondaryFill,
                  borderRadius: AppRadius.brLg,
                  boxShadow: AppElevation.e2(t.shadow),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 80,
                      color: t.secondary,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      '+500 XP\nDEBATE WON!',
                      textAlign: TextAlign.center,
                      style: context.text.displaySmall?.copyWith(
                        color: t.secondary,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    String text,
    bool isBot,
    DateTime? timestamp,
    bool isDebateMode,
  ) {
    final t = context.tokens;
    final timeLabel = timestamp == null
        ? null
        : Text(
            _formatTime(timestamp),
            style: context.text.labelSmall?.copyWith(color: t.inkFaint),
          );

    if (!isBot) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              margin: const EdgeInsets.only(bottom: AppSpace.xxs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm,
              ),
              decoration: BoxDecoration(
                color: isDebateMode ? t.secondaryFill : t.primary,
                borderRadius: AppRadius.brLg.copyWith(
                  bottomRight: const Radius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                text,
                style: context.text.bodyLarge?.copyWith(
                  color: isDebateMode ? t.secondary : t.onPrimary,
                  height: 1.35,
                ),
              ),
            ),
            ?timeLabel,
          ],
        ),
      );
    }

    // Bot messages are structured Markdown (headings, bullets, LaTeX-style
    // math blocks) — render them as a proper document, not a text wall.
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: t.primaryTint,
            child: Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: t.primary,
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nexus AI',
                      style: context.text.labelSmall?.copyWith(
                        color: t.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpace.xxs),
                    ?timeLabel,
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: AppRadius.brLg.copyWith(
                      bottomLeft: const Radius.circular(AppRadius.sm),
                    ),
                    border: Border.all(color: t.border),
                  ),
                  child: MarkdownBody(
                    data: text.isEmpty ? '…' : text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: context.text.bodyMedium?.copyWith(height: 1.45),
                      h1: context.text.headlineSmall,
                      h2: context.text.titleLarge,
                      h3: context.text.titleMedium,
                      listBullet: context.text.bodyMedium?.copyWith(
                        color: t.primary,
                      ),
                      strong: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bubbleAction(
                      icon: Icons.copy_outlined,
                      tooltip: 'Copy',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reply copied.')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubbleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: t.inkFaint),
      ),
    );
  }

  String _formatTime(DateTime ts) {
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildTypingBubble() {
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: t.primaryTint,
            child: Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: t.primary,
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Container(
            margin: const EdgeInsets.only(bottom: AppSpace.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: AppRadius.brLg.copyWith(
                bottomLeft: const Radius.circular(AppRadius.sm),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpace.sm),
                Text(
                  'Nexus is thinking...',
                  style: context.text.bodyMedium?.copyWith(color: t.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorTools(String? selectedClass) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.xs,
        AppSpace.md,
        10,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildToolChip(
                  Icons.lightbulb_outline,
                  'Simple',
                  'Explain this topic with a simple analogy.',
                ),
                _buildToolChip(
                  Icons.child_care,
                  'ELI5',
                  'Explain this concept like I am 5 years old.',
                ),
                _buildToolChip(
                  Icons.summarize_outlined,
                  'Summarize',
                  'Give me a 3-bullet summary of what we just discussed.',
                ),
                _buildToolChip(
                  Icons.quiz_outlined,
                  'Quiz me',
                  'Ask me 3 quick questions and wait for my answers.',
                ),
                _buildToolChip(
                  Icons.document_scanner_outlined,
                  'Scan',
                  null,
                  onTap: () => context.push('/scanner'),
                ),
                _buildToolChip(
                  Icons.smart_display_outlined,
                  'Shorts',
                  null,
                  onTap: () => context.go('/feed'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolChip(
    IconData icon,
    String label,
    String? prompt, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.xs),
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onPressed:
            onTap ??
            () {
              if (prompt == null) return;
              _controller.text = prompt;
              _sendMessage();
            },
      ),
    );
  }

  Widget _buildInputField(TutorState tutorState, TutorNotifier notifier) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: t.surface,
        boxShadow: AppElevation.e1(t.shadow),
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (tutorState.isVoiceConversation) {
                  notifier.toggleVoiceConversation(false);
                  return;
                }
                notifier.listen((text) {
                  _controller.text = text;
                });
                if (tutorState.isListening && _controller.text.isNotEmpty) {
                  _sendMessage();
                }
              },
              child: CircleAvatar(
                backgroundColor: tutorState.isListening
                    ? t.statusAbsent
                    : t.primaryTint,
                child: Icon(
                  tutorState.isListening ? Icons.mic : Icons.mic_none,
                  color: tutorState.isListening
                      ? t.onPrimary
                      : t.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: tutorState.isVoiceConversation
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg,
                        vertical: AppSpace.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tutorState.isListening
                                ? Icons.graphic_eq
                                : Icons.volume_up_outlined,
                            size: 18,
                            color: t.primary,
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Text(
                              tutorState.isListening
                                  ? 'Listening... speak now (tap mic to stop)'
                                  : 'Speaking...',
                              style: context.text.bodyMedium?.copyWith(
                                color: t.inkMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: tutorState.isListening
                            ? 'Listening...'
                            : 'Type or speak...',
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.brPill,
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: t.surfaceAlt.withValues(alpha: 0.9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg,
                          vertical: AppSpace.sm,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
