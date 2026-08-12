import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

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
            NexusTextField(
              controller: workController,
              keyboardType: TextInputType.number,
              label: 'Work (minutes)',
              icon: Icons.work,
            ),
            const SizedBox(height: AppSpace.sm),
            NexusTextField(
              controller: breakController,
              keyboardType: TextInputType.number,
              label: 'Break (minutes)',
              icon: Icons.coffee,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          NexusButton(
            label: 'Save',
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
    final t = context.tokens;
    final accentColor = _isBreak ? t.statusPresent : t.primary;

    return NexusScreen(
      title: 'Focus Room',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: _showSettingsDialog,
        ),
      ],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brPill,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _isBreak ? 'BREAK TIME' : 'WORK SESSION',
                  style: context.text.labelLarge?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
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
                      backgroundColor: t.surfaceAlt,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeString,
                        style: context.typeExtras.figureLg.copyWith(
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Remaining',
                        style: context.text.bodyMedium?.copyWith(
                          color: t.inkMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: _reset,
                    backgroundColor: t.surfaceAlt,
                    heroTag: 'reset',
                    child: Icon(Icons.replay, color: t.inkMuted),
                  ),
                  const SizedBox(width: AppSpace.lg),
                  FloatingActionButton.large(
                    onPressed: _toggleTimer,
                    backgroundColor: accentColor,
                    heroTag: 'play',
                    child: Icon(
                      _isRunning ? Icons.pause : Icons.play_arrow,
                      color: t.onPrimary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: AppSpace.lg),
                  FloatingActionButton(
                    onPressed: () {
                      _timer?.cancel();
                      setState(() {
                        _isRunning = false;
                        _isBreak = false;
                        _timeLeft = _workMinutes * 60;
                      });
                    },
                    backgroundColor: t.surfaceAlt,
                    heroTag: 'skip',
                    child: Icon(Icons.skip_next, color: t.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              _buildSessionTracker(t),
              const SizedBox(height: AppSpace.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTracker(AppTokens t) {
    final goal = AppSettings.instance.dailyMinutesGoal;
    final done = _completedSessions * _workMinutes;
    final goalReached = done >= goal;
    return Column(
      children: [
        NexusCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$_completedSessions',
                    style: context.typeExtras.figureLg.copyWith(color: t.primary),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    'Sessions',
                    style: context.text.labelSmall?.copyWith(color: t.inkMuted),
                  ),
                ],
              ),
              Container(width: 1, height: 40, color: t.border),
              Column(
                children: [
                  Text(
                    '$done',
                    style: context.typeExtras.figureLg.copyWith(
                      color: t.statusPresent,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    'Minutes',
                    style: context.text.labelSmall?.copyWith(color: t.inkMuted),
                  ),
                ],
              ),
              Container(width: 1, height: 40, color: t.border),
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
                          color: t.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    'Today',
                    style: context.text.labelSmall?.copyWith(color: t.inkMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        InkWell(
          onTap: _cycleDailyGoal,
          borderRadius: AppRadius.brMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  goalReached ? Icons.check_circle : Icons.flag_outlined,
                  size: 16,
                  color: goalReached ? t.statusPresent : t.inkMuted,
                ),
                const SizedBox(width: AppSpace.xxs),
                Text(
                  goalReached
                      ? 'Daily goal of $goal min reached — great job!'
                      : 'Daily goal: $goal min · $done so far · tap to change',
                  style: context.text.labelMedium?.copyWith(
                    color: goalReached ? t.statusPresent : t.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _cycleDailyGoal() {
    const presets = [15, 30, 45, 60, 90];
    final current = AppSettings.instance.dailyMinutesGoal;
    final next = presets[(presets.indexOf(current) + 1) % presets.length];
    AppSettings.instance.setDailyMinutesGoal(next);
    setState(() {});
  }

}
