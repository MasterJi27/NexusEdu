import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudyBuddyTinderScreen extends StatelessWidget {
  const StudyBuddyTinderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(title: const Text('Find Study Buddies', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, 10))],
                  image: const DecorationImage(image: NetworkImage('https://i.pravatar.cc/500?img=12'), fit: BoxFit.cover),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(colors: [Colors.black.withAlpha(200), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.center),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ananya, 19', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                      Text('CS Major @ IIT Delhi • 2 miles away', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Looking for a Python programming buddy!', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ).animate().slideY(begin: 0.1).shake(hz: 1, duration: 1.seconds),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton.large(onPressed: () {}, heroTag: 'nope', backgroundColor: Colors.white, child: const Icon(Icons.close, color: Colors.redAccent, size: 40)),
                  FloatingActionButton.large(onPressed: () {}, heroTag: 'yep', backgroundColor: Colors.white, child: const Icon(Icons.favorite, color: Colors.greenAccent, size: 40)),
                ],
              ).animate().scale(delay: 300.ms)
            ],
          ),
        ),
      ),
    );
  }
}
