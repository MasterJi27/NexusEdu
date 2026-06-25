import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class AccountabilityAgentScreen extends StatefulWidget {
  const AccountabilityAgentScreen({super.key});

  @override
  State<AccountabilityAgentScreen> createState() => _AccountabilityAgentScreenState();
}

class _AccountabilityAgentScreenState extends State<AccountabilityAgentScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _topicsController = TextEditingController();
  bool _isLoading = false;
  int _streak = 0;
  List<Map<String, dynamic>> _logs = [];
  List<double> _weeklyHours = [];
  List<String> _badges = [];

  static const List<Map<String, String>> _possibleBadges = [
    {'id': 'first_log', 'name': 'First Step', 'icon': '🌟'},
    {'id': 'streak_3', 'name': '3-Day Streak', 'icon': '🔥'},
    {'id': 'streak_7', 'name': 'Week Warrior', 'icon': '💪'},
    {'id': 'hours_10', 'name': '10h Study', 'icon': '📚'},
    {'id': 'hours_50', 'name': '50h Legend', 'icon': '🏆'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt('study_streak') ?? 0;
    final saved = prefs.getStringList('study_logs');
    if (saved != null) {
      _logs = saved.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      _calculateWeeklyHours();
      _checkBadges();
    }
    setState(() {});
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('study_streak', _streak);
    final encoded = _logs.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('study_logs', encoded);
  }

  void _calculateWeeklyHours() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recent = _logs.where((l) {
      try {
        final date = DateTime.parse(l['date'] ?? '');
        return date.isAfter(weekAgo);
      } catch (_) {
        return false;
      }
    });

    _weeklyHours = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final dayLogs = recent.where((l) {
        try {
          final date = DateTime.parse(l['date'] ?? '');
          return date.day == day.day && date.month == day.month;
        } catch (_) {
          return false;
        }
      });
      return dayLogs.fold<double>(0, (s, l) => s + (double.tryParse(l['hours']?.toString() ?? '0') ?? 0));
    });
  }

  void _checkBadges() {
    _badges = [];
    if (_logs.isNotEmpty) _badges.add('first_log');
    if (_streak >= 3) _badges.add('streak_3');
    if (_streak >= 7) _badges.add('streak_7');
    final totalHours = _logs.fold<double>(0, (s, l) => s + (double.tryParse(l['hours']?.toString() ?? '0') ?? 0));
    if (totalHours >= 10) _badges.add('hours_10');
    if (totalHours >= 50) _badges.add('hours_50');
  }

  Future<void> _logStudy() async {
    final subject = _subjectController.text.trim();
    final hours = _hoursController.text.trim();
    final topics = _topicsController.text.trim();
    if (subject.isEmpty || hours.isEmpty) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastLogDate = _logs.isNotEmpty ? _logs.last['date'] : null;
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    if (lastLogDate == today) {
    } else if (lastLogDate == yesterdayStr) {
      _streak++;
    } else if (lastLogDate != today) {
      _streak = 1;
    }

    _logs.add({
      'subject': subject,
      'hours': hours,
      'topics': topics,
      'date': today,
      'timestamp': now.toIso8601String(),
    });

    _calculateWeeklyHours();
    _checkBadges();
    _saveLogs();

    _subjectController.clear();
    _hoursController.clear();
    _topicsController.clear();

    setState(() => _isLoading = false);
  }

  Future<void> _getNudge() async {
    setState(() => _isLoading = true);

    final prompt = 'Give a short motivational nudge (2-3 sentences) for a student who has studied '
        'for $_streak consecutive days. Be encouraging but push them to keep going.';

    final response = await AiAgentService.callAgent('custom', {'prompt': prompt});

    if (!mounted) return;
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Motivation Nudge', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
        content: Text(response, style: TextStyle(color: Colors.white.withAlpha(200))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Let\'s Go!', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Study Accountability', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStreakHeader(),
          const SizedBox(height: 16),
          _buildLogForm(),
          const SizedBox(height: 16),
          _buildBadges(),
          const SizedBox(height: 16),
          _buildWeeklyChart(),
          const SizedBox(height: 16),
          _buildRecentLogs(),
        ],
      ),
    );
  }

  Widget _buildStreakHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.withAlpha(40), Colors.deepOrange.withAlpha(20)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _streak.toDouble()),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    Text('${value.toInt()}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_streak Day Streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  _streak >= 7 ? 'Amazing consistency!' : _streak >= 3 ? 'Keep the fire burning!' : 'Build your streak!',
                  style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _getNudge,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Nudge', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    ).animate().fade().scale();
  }

  Widget _buildLogForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Log Study Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          TextField(
            controller: _subjectController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Subject',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              filled: true,
              fillColor: const Color(0xFF0F0F13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hoursController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Hours studied',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              filled: true,
              fillColor: const Color(0xFF0F0F13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _topicsController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Topics covered (optional)',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              filled: true,
              fillColor: const Color(0xFF0F0F13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _logStudy,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Log Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildBadges() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Achievements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _possibleBadges.map((badge) {
              final unlocked = _badges.contains(badge['id']);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: unlocked ? Colors.amberAccent.withAlpha(30) : Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: unlocked ? Colors.amberAccent.withAlpha(80) : Colors.white.withAlpha(20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(badge['icon']!, style: TextStyle(fontSize: 18, color: unlocked ? null : Colors.white.withAlpha(50))),
                    const SizedBox(width: 6),
                    Text(badge['name']!,
                        style: TextStyle(
                          color: unlocked ? Colors.amberAccent : Colors.white.withAlpha(80),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _WeeklyChartPainter(_weeklyHours),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Text(d, style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10)))
                .toList(),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildRecentLogs() {
    final recent = _logs.reversed.take(5).toList();
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text('No study sessions logged yet.', style: TextStyle(color: Colors.white.withAlpha(100)))),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Sessions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...recent.map((log) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0F0F13), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.deepPurpleAccent.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.book, color: Colors.deepPurpleAccent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['subject'] ?? '', style: TextStyle(color: Colors.white.withAlpha(200), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('${log['hours']}h • ${log['topics'] ?? ''}',
                          style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text(log['date'] ?? '', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _WeeklyChartPainter extends CustomPainter {
  final List<double> data;
  _WeeklyChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce(max).clamp(0.5, double.infinity);
    final barWidth = size.width / (data.length * 2.5);

    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i] / maxVal) * size.height * 0.85;
      final x = i * (size.width / data.length) + (size.width / data.length - barWidth) / 2;
      final y = size.height - barHeight;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurpleAccent, Colors.deepPurpleAccent.withAlpha(60)],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight), const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
