import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudyStreamScreen extends StatelessWidget {
  const StudyStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mock Video Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1517842645767-c639042777db?auto=format&fit=crop&q=80'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          children: [
                            Icon(Icons.visibility, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('14,204 Studying', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.black.withAlpha(200), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  ),
                  child: ListView(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildChat('Arjun:', 'Finally understood pointers!'),
                      _buildChat('Priya:', 'Lo-fi beats hit different at 2am 🎧'),
                      _buildChat('Rahul:', 'Who else has the Physics exam tomorrow?'),
                      _buildChat('NexusAI:', 'Focus block ends in 15 minutes. Keep going!'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black,
                  child: Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(hintText: 'Chat in silent mode...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: () {})
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChat(String name, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$name ', style: TextStyle(fontWeight: FontWeight.bold, color: name == 'NexusAI:' ? Colors.purpleAccent : Colors.amber)),
            TextSpan(text: message, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    ).animate().slideX(begin: -0.1);
  }
}
