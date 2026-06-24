import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LiveTranslationScreen extends StatefulWidget {
  const LiveTranslationScreen({super.key});

  @override
  State<LiveTranslationScreen> createState() => _LiveTranslationScreenState();
}

class _LiveTranslationScreenState extends State<LiveTranslationScreen> {
  final List<String> _transcripts = [
    "So today we'll be discussing cellular respiration.",
  ];
  final List<String> _translations = [
    "Hoy discutiremos la respiración celular.",
  ];

  @override
  void initState() {
    super.initState();
    _simulateLiveAudio();
  }

  void _simulateLiveAudio() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _transcripts.add("It consists of three main stages: Glycolysis, the Krebs Cycle, and the Electron Transport Chain.");
        _translations.add("Consta de tres etapas principales: la glucólisis, el ciclo de Krebs y la cadena de transporte de electrones.");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Lecture Translation', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            height: 100,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                30, 
                (index) => Container(
                  width: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleY(begin: 0.1, end: (index % 5 + 1) * 0.2, duration: Duration(milliseconds: 300 + (index * 50))),
              ),
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _transcripts.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_transcripts[index], style: const TextStyle(color: Colors.grey, fontSize: 18, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      Text(_translations[index], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ).animate().fadeIn().slideX(begin: 0.1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
