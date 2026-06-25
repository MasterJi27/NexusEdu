import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allPlayers = [];
  bool _isLoading = true;
  final String _currentUserId = 'user_self';

  final List<String> _subjects = [
    'All',
    'Physics',
    'Chemistry',
    'Maths',
    'Biology',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('leaderboard_data');
    if (raw != null) {
      _allPlayers = raw
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    } else {
      _allPlayers = _generateSampleData();
      await _saveLeaderboard();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _allPlayers.map((e) => json.encode(e)).toList();
    await prefs.setStringList('leaderboard_data', encoded);
  }

  List<Map<String, dynamic>> _generateSampleData() {
    final names = [
      'Aarav Mehta',
      'Saanvi Sharma',
      'Aditya Verma',
      'Diya Nair',
      'Vivaan Gupta',
      'Ananya Singh',
      'Reyansh Kumar',
      'Myra Patel',
      'Arjun Reddy',
      'Kiara Joshi',
      'Kabir Das',
      'Sara Khan',
      'Vihaan Rao',
      'Ishita Menon',
      'You',
    ];
    return List.generate(names.length, (i) {
      final isUser = names[i] == 'You';
      return {
        'id': isUser ? _currentUserId : 'player_$i',
        'name': names[i],
        'xp': 5000 - (i * 320) + (isUser ? 120 : 0),
        'rank': i + 1,
        'avatar': names[i][0],
        'subjects': {
          'Physics': 500 + (i * 40),
          'Chemistry': 400 + (i * 35),
          'Maths': 600 + (i * 50),
          'Biology': 350 + (i * 30),
        },
        'rankChange': i % 3 == 0 ? 2 : (i % 3 == 1 ? -1 : 0),
        'isCurrentUser': isUser,
      };
    });
  }

  List<Map<String, dynamic>> _getFilteredPlayers(String subject) {
    final players = List<Map<String, dynamic>>.from(_allPlayers);
    if (subject == 'All') {
      players.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
      return List.generate(players.length, (i) {
        players[i]['rank'] = i + 1;
        return players[i];
      });
    }
    players.sort((a, b) {
      final aXp = ((a['subjects'] as Map<String, dynamic>?) ?? {})[subject] ?? 0;
      final bXp = ((b['subjects'] as Map<String, dynamic>?) ?? {})[subject] ?? 0;
      return (bXp as int).compareTo(aXp as int);
    });
    return List.generate(players.length, (i) {
      players[i]['rank'] = i + 1;
      return players[i];
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Leaderboard',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurpleAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'All-Time'),
            Tab(text: 'Subject'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardTab('All'),
                _buildLeaderboardTab('All'),
                _buildLeaderboardTab('All'),
                _buildSubjectTab(),
              ],
            ),
    );
  }

  Widget _buildLeaderboardTab(String subject) {
    final players = _getFilteredPlayers(subject);
    final top3 = players.take(3).toList();
    final rest = players.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPodium(top3),
        const SizedBox(height: 24),
        ...rest.asMap().entries.map((entry) {
          return _buildPlayerCard(entry.value, entry.key);
        }),
      ],
    );
  }

  Widget _buildSubjectTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._subjects.skip(1).map((subject) {
          final players = _getFilteredPlayers(subject);
          final topPlayer = players.isNotEmpty ? players.first : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      subject[0],
                      style: const TextStyle(
                        color: Colors.deepPurpleAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                      if (topPlayer != null)
                        Text(
                          'Top: ${topPlayer['name']} · ${((topPlayer['subjects'] as Map<String, dynamic>)[subject] ?? 0)} XP',
                          style: TextStyle(
                            color: Colors.white.withAlpha(120),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.white.withAlpha(60)),
              ],
            ),
          ).animate().fade();
        }),
      ],
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3) {
    if (top3.isEmpty) return const SizedBox();
    final order = top3.length >= 3
        ? [top3[1], top3[0], top3[2]]
        : top3.length == 2
            ? [top3[1], top3[0]]
            : [top3[0]];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: order.asMap().entries.map((entry) {
        final player = entry.value;
        final rank = player['rank'] as int;
        final xp = player['xp'] as int;
        final color = rank == 1
            ? Colors.amber
            : rank == 2
                ? Colors.grey.shade400
                : Colors.brown.shade300;
        final height = rank == 1 ? 140.0 : rank == 2 ? 110.0 : 90.0;
        final radius = rank == 1 ? 36.0 : 28.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: radius,
                  backgroundColor: color,
                  child: Text(
                    player['avatar'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (rank == 1)
                  Positioned(
                    top: -8,
                    child: const Icon(Icons.star,
                            color: Colors.amberAccent, size: 24)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3)),
                  ),
              ],
            ).animate().scale(curve: Curves.easeOutBack, delay: 300.ms),
            const SizedBox(height: 8),
            Text(player['name'] ?? '',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: rank == 1 ? FontWeight.bold : FontWeight.normal,
                    fontSize: rank == 1 ? 15 : 13)),
            Text('$xp XP',
                style: const TextStyle(
                    color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              width: rank == 1 ? 90 : 70,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withAlpha(150)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                boxShadow: [
                  BoxShadow(
                      color: color.withAlpha(80),
                      blurRadius: 16,
                      spreadRadius: 4),
                ],
              ),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '$rank',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            )
                .animate()
                .scaleY(
                    alignment: Alignment.bottomCenter,
                    duration: 600.ms,
                    curve: Curves.easeOutQuart),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player, int displayIndex) {
    final rank = player['rank'] as int;
    final xp = player['xp'] as int;
    final change = player['rankChange'] as int;
    final isMe = player['isCurrentUser'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.deepPurpleAccent.withAlpha(25)
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: Colors.deepPurpleAccent.withAlpha(60))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$rank',
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: isMe
                ? Colors.deepPurpleAccent
                : Colors.white.withAlpha(15),
            child: Text(
              player['avatar'] ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${player['name']} (You)' : player['name'] ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$xp XP',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (change != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: change > 0
                    ? Colors.green.withAlpha(30)
                    : Colors.redAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: change > 0 ? Colors.green : Colors.redAccent,
                  ),
                  Text(
                    '${change.abs()}',
                    style: TextStyle(
                      color: change > 0 ? Colors.green : Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fade(delay: (40 * displayIndex).ms).slideX(begin: 0.02);
  }
}
