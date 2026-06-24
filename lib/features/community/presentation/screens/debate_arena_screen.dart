import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DebateArenaScreen extends StatelessWidget {
  const DebateArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Debate Arena ⚔️', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orangeAccent.withAlpha(20),
            child: const Row(
              children: [
                Icon(Icons.gavel, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Topic: "Was the Industrial Revolution ultimately beneficial for humanity?"',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ).animate().slideY(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildChatBubble('Alex (Pro)', 'Yes. It drastically increased life expectancy and technological progress.', Colors.blueAccent, true),
                _buildChatBubble('Sam (Con)', 'But it came at the cost of extreme child labor and environmental degradation.', Colors.redAccent, false),
                _buildChatBubble('AI Judge', 'Strong counter-point from Sam. Alex, how do you address the environmental impact?', Colors.purple, true, isSystem: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(decoration: InputDecoration(hintText: 'Type your argument...', border: OutlineInputBorder())),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: () {}),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatBubble(String name, String text, Color color, bool isLeft, {bool isSystem = false}) {
    return Align(
      alignment: isSystem ? Alignment.center : (isLeft ? Alignment.centerLeft : Alignment.centerRight),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isSystem ? Colors.purple.withAlpha(20) : color.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ).animate().fade().slideX(begin: isLeft ? -0.1 : 0.1),
    );
  }
}
