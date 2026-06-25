import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/features/tutor/presentation/providers/tutor_provider.dart';

class TutorChatScreen extends ConsumerStatefulWidget {
  const TutorChatScreen({super.key});

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepPurple,
              radius: 16,
              child: Icon(
                Icons.record_voice_over,
                color: Colors.white,
                size: 18,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Nexus AI Tutor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              const Text(
                'Debate',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: tutorState.isDebateMode,
                onChanged: (val) {
                  notifier.toggleDebateMode(val);
                },
                activeThumbColor: Colors.redAccent,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              child:
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.amber, Colors.orange],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withAlpha(150),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: 80,
                              color: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '+500 XP\nDEBATE WON!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut)
                      .shimmer(duration: 1.seconds, color: Colors.white)
                      .then(delay: 1.5.seconds)
                      .fadeOut(duration: 500.ms)
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(0.5, 0.5),
                      )
                      .callback(callback: (_) => notifier.hideXpPopup()),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isBot, bool isDebateMode) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child:
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            margin: EdgeInsets.only(
              bottom: 12,
              right: isBot ? 48 : 0,
              left: isBot ? 0 : 48,
            ),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isBot
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : (isDebateMode
                        ? Colors.redAccent
                        : Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: isBot
                    ? const Radius.circular(0)
                    : const Radius.circular(20),
                bottomRight: !isBot
                    ? const Radius.circular(0)
                    : const Radius.circular(20),
              ),
              boxShadow: [
                if (!isBot && isDebateMode)
                  BoxShadow(
                    color: Colors.redAccent.withAlpha(100),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isBot
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white,
                fontSize: 16,
              ),
            ),
          ).animate().fade().scale(
            alignment: isBot ? Alignment.bottomLeft : Alignment.bottomRight,
          ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(
            18,
          ).copyWith(bottomLeft: const Radius.circular(0)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withAlpha(40),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.deepPurpleAccent,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.seconds),
            const SizedBox(width: 12),
            const Text(
              'Nexus is thinking...',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
        begin: const Offset(1, 1),
        end: const Offset(1.02, 1.02),
        duration: 1.seconds,
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildTutorTools(String? selectedClass) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.black.withAlpha(8))),
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
                  'Explain this topic with a simple Hinglish analogy.',
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
      padding: const EdgeInsets.only(right: 8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                notifier.listen((text) {
                  _controller.text = text;
                });
                if (tutorState.isListening && _controller.text.isNotEmpty) {
                  _sendMessage();
                }
              },
              child: CircleAvatar(
                backgroundColor: tutorState.isListening
                    ? Colors.redAccent
                    : Colors.deepPurpleAccent.withAlpha(50),
                child: Icon(
                  tutorState.isListening ? Icons.mic : Icons.mic_none,
                  color: tutorState.isListening
                      ? Colors.white
                      : Colors.deepPurpleAccent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: tutorState.isListening
                      ? 'Listening...'
                      : 'Type or speak...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withAlpha(150),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
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
