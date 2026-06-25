import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _selectedPeriod = 'This Week';
  final _gamification = GamificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text('Leaderboard', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<String>(
              value: _selectedPeriod,
              dropdownColor: const Color(0xFF1E1E1E),
              underline: const SizedBox(),
              isDense: true,
              items: ['This Week', 'This Month', 'All Time'].map((p) {
                return DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 12)));
              }).toList(),
              onChanged: (v) => setState(() => _selectedPeriod = v!),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPodium(1, 'Priya S.', '4,850 XP', Colors.amber, 80),
                _buildPodium(2, 'You', '2,450 XP', Colors.deepPurpleAccent, 70),
                _buildPodium(3, 'Aarav M.', '4,200 XP', Colors.grey, 60),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: GamificationService.leaderboard.length,
              itemBuilder: (context, index) {
                final entry = GamificationService.leaderboard[index];
                final isUser = entry['isUser'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.deepPurpleAccent.withOpacity(0.15) : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: isUser ? Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)) : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${entry['rank']}',
                          style: TextStyle(
                            color: entry['rank'] <= 3 ? Colors.deepPurpleAccent : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isUser ? Colors.deepPurpleAccent : Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            entry['name'][0],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry['name'],
                              style: TextStyle(
                                color: isUser ? Colors.deepPurpleAccent : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '🔥 ${entry['streak']} day streak',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${entry['xp']} XP',
                        style: TextStyle(
                          color: isUser ? Colors.deepPurpleAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(int rank, String name, String xp, Color color, double height) {
    final isUser = name == 'You';
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isUser ? Colors.deepPurpleAccent : color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: TextStyle(color: isUser ? Colors.deepPurpleAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(xp, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: isUser ? Colors.deepPurpleAccent.withOpacity(0.3) : color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text('#$rank', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
