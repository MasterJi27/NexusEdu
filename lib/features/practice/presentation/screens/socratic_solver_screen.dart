import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class SocraticSolverScreen extends StatefulWidget {
  const SocraticSolverScreen({super.key});

  @override
  State<SocraticSolverScreen> createState() => _SocraticSolverScreenState();
}

class _SocraticSolverScreenState extends State<SocraticSolverScreen> {
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hi! I am your Socratic Math Tutor. I am here to help you solve math problems step-by-step. What problem are we working on today?', 'isUser': false},
  ];
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    AiService.resetSocraticSession();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _isTyping = true;
    });
    _controller.clear();

    final reply = await AiService.sendMessageToSocraticTutor(text);

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add({'text': reply, 'isUser': false});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology_alt, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Socratic Math Tutor', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: isUser ? null : Border.all(color: Colors.blueAccent.withAlpha(50)),
                    ),
                    child: isUser
                        ? Text(
                            msg['text'],
                            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                          )
                        : MarkdownBody(
                            data: msg['text'],
                            selectable: true,
                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                              p: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, height: 1.4),
                            ),
                          ),
                  ).animate().fade().slideY(begin: 0.1),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const Text('AI is thinking...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                    .animate(onPlay: (c) => c.repeat(reverse: true)).fade(),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Answer the question...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  child: const Icon(Icons.send),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
