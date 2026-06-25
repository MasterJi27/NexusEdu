import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/app_settings.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  late int _workMinutes;
  late int _breakMinutes;
  int _timeLeft = 0;
  bool _isRunning = false;
  bool _isBreak = false;
  int _completedSessions = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final settings = AppSettings.instance;
    _workMinutes = settings.pomodoroWork;
    _breakMinutes = settings.pomodoroBreak;
    _timeLeft = _workMinutes * 60;
    _completedSessions = settings.pomodoroSessionsToday;
  }

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
            if (!_isBreak) {
              _completedSessions++;
              AppSettings.instance.incrementPomodoroSessions();
              _startBreak();
            } else {
              _isBreak = false;
              _timeLeft = _workMinutes * 60;
            }
          }
        });
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  void _startBreak() {
    _isBreak = true;
    _timeLeft = _breakMinutes * 60;
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _timeLeft = _workMinutes * 60;
    });
  }

  void _showSettingsDialog() async {
    final workController = TextEditingController(text: '$_workMinutes');
    final breakController = TextEditingController(text: '$_breakMinutes');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pomodoro Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: workController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Work (minutes)', prefixIcon: Icon(Icons.work)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: breakController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Break (minutes)', prefixIcon: Icon(Icons.coffee)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final w = int.tryParse(workController.text) ?? 25;
              final b = int.tryParse(breakController.text) ?? 5;
              AppSettings.instance.setPomodoroSettings(w, b);
              setState(() {
                _workMinutes = w;
                _breakMinutes = b;
                _timeLeft = w * 60;
                _isBreak = false;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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

  double get _progress {
    final total = _isBreak ? _breakMinutes * 60 : _workMinutes * 60;
    return _timeLeft / total;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isBreak ? Colors.tealAccent : Colors.deepPurpleAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Focus Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: accentColor.withAlpha(50)),
                ),
                child: Text(
                  _isBreak ? 'BREAK TIME' : 'WORK SESSION',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 14,
                  ),
                ),
              ).animate().fade().slideY(begin: -0.1),
              const SizedBox(height: 40),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 16,
                      color: accentColor,
                      backgroundColor: Colors.white.withAlpha(20),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeString,
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'Remaining',
                        style: TextStyle(color: Colors.white54, fontSize: 16, letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ],
              ).animate().fade(delay: 100.ms).scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: _reset,
                    backgroundColor: Colors.white.withAlpha(20),
                    heroTag: 'reset',
                    child: const Icon(Icons.replay, color: Colors.white70),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton.large(
                    onPressed: _toggleTimer,
                    backgroundColor: accentColor,
                    elevation: 10,
                    heroTag: 'play',
                    child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 48),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton(
                    onPressed: () {
                      _timer?.cancel();
                      setState(() {
                        _isRunning = false;
                        _isBreak = false;
                        _timeLeft = _workMinutes * 60;
                      });
                    },
                    backgroundColor: Colors.white.withAlpha(20),
                    heroTag: 'skip',
                    child: const Icon(Icons.skip_next, color: Colors.white70),
                  ),
                ],
              ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
              const SizedBox(height: 48),
              _buildSessionTracker(),
              const SizedBox(height: 40),
              const Text(
                'Ambient Study Sounds',
                style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTracker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '$_completedSessions',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
              ),
              const SizedBox(height: 4),
              const Text('Sessions', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Container(width: 1, height: 40, color: Colors.white.withAlpha(20)),
          Column(
            children: [
              Text(
                '${_completedSessions * _workMinutes}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.tealAccent),
              ),
              const SizedBox(height: 4),
              const Text('Minutes', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Container(width: 1, height: 40, color: Colors.white.withAlpha(20)),
          Column(
            children: [
              Row(
                children: List.generate(
                  _completedSessions.clamp(0, 8),
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Today', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: 300.ms);
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
        Text(label, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
