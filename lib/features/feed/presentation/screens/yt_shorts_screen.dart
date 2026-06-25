import 'package:flutter/material.dart';
import 'package:nexus_edu/features/feed/presentation/screens/ai_feed_screen.dart';

class YtShortsScreen extends StatelessWidget {
  const YtShortsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shorts',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
      ),
      body: const AiFeedScreen(),
    );
  }
}
