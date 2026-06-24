import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class VoiceTutorScreen extends StatefulWidget {
  const VoiceTutorScreen({super.key});

  @override
  State<VoiceTutorScreen> createState() => _VoiceTutorScreenState();
}

class _VoiceTutorScreenState extends State<VoiceTutorScreen> {
  bool _isListening = false;
  bool _aiSpeaking = true;
  String _transcript = "Hello Alex. I'm ready to help you prep for your history exam. What topic would you like to discuss?";

  void _toggleListening() {
    setState(() {
      if (_aiSpeaking) {
        _aiSpeaking = false;
        _isListening = true;
        _transcript = "Listening...";
        
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            _transcript = "Tell me about the causes of World War 1.";
            _isListening = false;
            
            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted) return;
              setState(() {
                _aiSpeaking = true;
                _transcript = "Great question! The main causes can be summarized by the acronym MAIN: Militarism, Alliances, Imperialism, and Nationalism. Would you like me to elaborate on one of those?";
              });
            });
          });
        });
      } else if (_isListening) {
        _isListening = false;
        _aiSpeaking = true;
        _transcript = "How else can I help?";
      } else {
        _aiSpeaking = true;
        _transcript = "I'm listening.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark sleek aesthetic
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 32),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Visualizer Glow
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _aiSpeaking 
                        ? Colors.deepPurpleAccent.withAlpha(100) 
                        : (_isListening ? Colors.blueAccent.withAlpha(100) : Colors.transparent),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
              target: _aiSpeaking || _isListening ? 1 : 0,
            ).scaleXY(end: 1.2, duration: 800.ms, curve: Curves.easeInOut),
          ),
          
          // Core Visualizer Orb
          Center(
            child: GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: _aiSpeaking 
                        ? [Colors.white, Colors.deepPurpleAccent] 
                        : [Colors.white, Colors.blueAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withAlpha(50),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _aiSpeaking ? Icons.graphic_eq : (_isListening ? Icons.mic : Icons.mic_none),
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ).animate(
                onPlay: (controller) => controller.repeat(reverse: true),
                target: _aiSpeaking || _isListening ? 1 : 0,
              ).scaleXY(end: 1.1, duration: _aiSpeaking ? 400.ms : 1000.ms).shimmer(duration: 2.seconds),
            ),
          ),

          // Transcript Text
          Positioned(
            bottom: 100,
            left: 32,
            right: 32,
            child: Column(
              children: [
                Text(
                  _aiSpeaking ? "AI Tutor" : (_isListening ? "You" : ""),
                  style: TextStyle(
                    color: _aiSpeaking ? Colors.deepPurpleAccent : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ).animate(key: ValueKey('speaker_$_aiSpeaking')).fadeIn().slideY(begin: 0.5),
                const SizedBox(height: 16),
                Text(
                  _transcript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate(key: ValueKey(_transcript)).fadeIn(duration: 400.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
