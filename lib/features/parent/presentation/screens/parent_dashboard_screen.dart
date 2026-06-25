import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/app_settings.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildChildProfileCard().animate().fade().slideY(begin: -0.05),
          const SizedBox(height: 20),
          _buildStreakCard(settings).animate().fade(delay: 80.ms),
          const SizedBox(height: 16),
          _buildWeeklyProgress().animate().fade(delay: 160.ms),
          const SizedBox(height: 16),
          _buildSubjectPerformance().animate().fade(delay: 240.ms),
          const SizedBox(height: 16),
          _buildScreenTimeCard().animate().fade(delay: 320.ms),
          const SizedBox(height: 16),
          _buildWeakSubjectsCard().animate().fade(delay: 400.ms),
          const SizedBox(height: 16),
          _buildExamReadiness(settings).animate().fade(delay: 480.ms),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildChildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.deepPurple.withAlpha(40), Colors.blueAccent.withAlpha(20)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.deepPurple.withAlpha(60)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alex Learner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Class 12 • Science', style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 4),
                Text('Last active: 2 hours ago', style: TextStyle(color: Colors.tealAccent, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Active', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(AppSettings settings) {
    final streak = settings.streak;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.orange, size: 36),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study Streak: $streak days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                streak >= 7 ? 'Excellent consistency!' : streak >= 3 ? 'Good progress.' : 'Needs improvement.',
                style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgress() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hours = [2.5, 1.8, 3.2, 2.1, 1.5, 4.0, 2.8];
    final maxHour = hours.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Study Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final h = hours[i] / maxHour;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${hours[i]}h', style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(140))),
                        const SizedBox(height: 4),
                        Container(
                          height: 100 * h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.tealAccent, Colors.teal.withAlpha(100)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(days[i], style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(160))),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformance() {
    final subjects = [
      ('Physics', 0.78, Colors.blueAccent),
      ('Chemistry', 0.65, Colors.greenAccent),
      ('Mathematics', 0.82, Colors.purpleAccent),
      ('Biology', 0.91, Colors.tealAccent),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subject Mastery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          for (final (name, progress, color) in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                      Text('${(progress * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(20),
                    backgroundColor: color.withAlpha(30),
                    color: color,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScreenTimeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.screen_lock_portrait, color: Colors.blueAccent, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Screen Time', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('2h 15m on Nexus Edu', style: TextStyle(color: Colors.tealAccent, fontSize: 13)),
              ],
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('18%', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              Text('vs yesterday', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeakSubjectsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 20),
              SizedBox(width: 8),
              Text('Areas Needing Attention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          _buildWeakItem('Organic Chemistry', 'Only 45% mastery'),
          _buildWeakItem('Electromagnetic Waves', 'Low quiz scores'),
        ],
      ),
    );
  }

  Widget _buildWeakItem(String topic, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orangeAccent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(detail, style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamReadiness(AppSettings settings) {
    final examDate = settings.examDate;
    final daysLeft = examDate != null ? examDate.difference(DateTime.now()).inDays : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purpleAccent.withAlpha(30), Colors.deepPurple.withAlpha(20)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school, color: Colors.purpleAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exam Readiness', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  daysLeft != null ? '$daysLeft days to ${settings.examName}' : 'No exam set',
                  style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            daysLeft != null ? '${(daysLeft * 0.6).round()}%' : '--',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
          ),
        ],
      ),
    );
  }
}
