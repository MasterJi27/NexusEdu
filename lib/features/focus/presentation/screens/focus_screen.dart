import 'dart:async';
import 'package:flutter/material.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  int _timeLeft = 25 * 60; // 25 minutes
  bool _isRunning = false;
  Timer? _timer;

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            _timer?.cancel();
            _isRunning = false;
          }
        });
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeString {
    final m = (_timeLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_timeLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Focus Room',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: _timeLeft / (25 * 60),
                    strokeWidth: 16,
                    color: Colors.deepPurpleAccent,
                    backgroundColor: Colors.white.withAlpha(20),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeString,
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const Text(
                      'Remaining',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 64),
            FloatingActionButton.large(
              onPressed: _toggleTimer,
              backgroundColor: Colors.deepPurpleAccent,
              elevation: 10,
              child: Icon(
                _isRunning ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 64),
            const Text(
              'Ambient Study Sounds',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSoundToggle(Icons.water_drop, 'Rain'),
                const SizedBox(width: 32),
                _buildSoundToggle(Icons.local_cafe, 'Cafe'),
                const SizedBox(width: 32),
                _buildSoundToggle(Icons.headphones, 'Lo-Fi'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundToggle(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: Colors.white.withAlpha(20),
          child: Icon(icon, color: Colors.white.withAlpha(150), size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
