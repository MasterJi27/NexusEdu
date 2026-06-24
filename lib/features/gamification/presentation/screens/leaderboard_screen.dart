import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedSegment = 0; // 0: Global, 1: Campus

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildSegmentBtn('Global', 0)),
                  Expanded(child: _buildSegmentBtn('Campus', 1)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Column(
          key: ValueKey<int>(_selectedSegment),
          children: [
            const SizedBox(height: 32),
            _buildPodium(context),
            const SizedBox(height: 32),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, -5))
                  ],
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    final rank = index + 4;
                    final xp = _selectedSegment == 0 ? 1500 - (index * 50) : 900 - (index * 30);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text('Student $rank', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('$xp XP', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                    ).animate().fade(delay: (50 * index).ms).slideY(begin: 0.1);
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentBtn(String title, int index) {
    final isSelected = _selectedSegment == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedSegment = index),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(100), blurRadius: 10)] : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildPodiumSpot(context, 2, _selectedSegment == 0 ? 'Sarah' : 'Mia', _selectedSegment == 0 ? 2000 : 1200, Colors.grey.shade400, 100),
        _buildPodiumSpot(context, 1, _selectedSegment == 0 ? 'Alex' : 'Leo', _selectedSegment == 0 ? 2500 : 1500, Colors.amber, 150),
        _buildPodiumSpot(context, 3, _selectedSegment == 0 ? 'John' : 'Zoe', _selectedSegment == 0 ? 1800 : 1000, Colors.brown.shade300, 70),
      ],
    );
  }

  Widget _buildPodiumSpot(BuildContext context, int rank, String name, int xp, Color color, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: rank == 1 ? 80 : 60,
              height: rank == 1 ? 80 : 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(30),
              ),
            ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1,1), end: const Offset(1.2,1.2)).fade(begin: 1, end: 0),
            CircleAvatar(
              radius: rank == 1 ? 35 : 28, 
              backgroundColor: color, 
              child: const Icon(Icons.person, color: Colors.white, size: 32)
            ),
            if (rank == 1)
              const Positioned(
                top: -10,
                child: Icon(Icons.star, color: Colors.amberAccent, size: 28),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.3,1.3)),
          ],
        ).animate().scale(curve: Curves.easeOutBack, delay: 300.ms),
        const SizedBox(height: 12),
        Text(name, style: TextStyle(fontWeight: rank == 1 ? FontWeight.bold : FontWeight.normal, fontSize: rank == 1 ? 18 : 16)),
        Text('$xp XP', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: rank == 1 ? 100 : 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withAlpha(150)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
               BoxShadow(color: color.withAlpha(100), blurRadius: 20, spreadRadius: 5)
            ]
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 12),
          child: Text('$rank', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
        ).animate().scaleY(alignment: Alignment.bottomCenter, duration: 600.ms, curve: Curves.easeOutQuart),
      ],
    );
  }
}
