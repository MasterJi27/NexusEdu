import 'dart:async';
import 'package:flutter/material.dart';

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isRunning = false;
  bool _isBreak = false;
  int _studyMinutes = 25;
  int _breakMinutes = 5;
  int _currentSeconds = 25 * 60;
  int _totalSeconds = 25 * 60;
  int _sessionsCompleted = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        setState(() => _currentSeconds--);
      } else {
        timer.cancel();
        _onSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _currentSeconds = _studyMinutes * 60;
      _totalSeconds = _studyMinutes * 60;
    });
  }

  void _onSessionComplete() {
    setState(() => _isRunning = false);
    if (!_isBreak) {
      _sessionsCompleted++;
      _isBreak = true;
      _currentSeconds = _breakMinutes * 60;
      _totalSeconds = _breakMinutes * 60;
      _showSnackBar('🎉 Study session complete! Take a break.');
    } else {
      _isBreak = false;
      _currentSeconds = _studyMinutes * 60;
      _totalSeconds = _studyMinutes * 60;
      _showSnackBar('⏰ Break over! Ready to study?');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.deepPurpleAccent, duration: const Duration(seconds: 2)),
    );
  }

  String get _timeDisplay {
    final m = _currentSeconds ~/ 60;
    final s = _currentSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => _totalSeconds > 0 ? 1 - (_currentSeconds / _totalSeconds) : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text('Study Timer', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isBreak ? '☕ Break Time' : '📚 Study Time',
                style: TextStyle(
                  fontSize: 20,
                  color: _isBreak ? Colors.greenAccent : Colors.deepPurpleAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(
                          _isBreak ? Colors.greenAccent : Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                    Text(
                      _timeDisplay,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Session ${_sessionsCompleted + 1} of 4',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _sessionsCompleted ? Colors.deepPurpleAccent : Colors.white12,
                  ),
                )),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white54, size: 32),
                    onPressed: _resetTimer,
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _isRunning ? _pauseTimer : _startTimer,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRunning ? Colors.orangeAccent : Colors.deepPurpleAccent,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRunning ? Colors.orangeAccent : Colors.deepPurpleAccent).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white54, size: 32),
                    onPressed: _onSessionComplete,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat('Sessions', '$_sessionsCompleted', Icons.timer),
                  _buildStat('Focus', '${_sessionsCompleted * _studyMinutes}m', Icons.center_focus_strong),
                  _buildStat('Total', '${_sessionsCompleted * 25} XP', Icons.star),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurpleAccent, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
