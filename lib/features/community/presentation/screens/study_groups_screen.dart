import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudyGroupsScreen extends StatelessWidget {
  const StudyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Virtual Study Rooms',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildRoomCard(
            context,
            'Night Owls 🦉',
            'Lo-Fi & Chill',
            45,
            Colors.indigo,
          ),
          _buildRoomCard(
            context,
            'Math Geniuses ➗',
            'Calculus Prep',
            12,
            Colors.teal,
          ),
          _buildRoomCard(
            context,
            'Hackathon Team 💻',
            'Flutter Dev',
            4,
            Colors.blue,
          ),
          _buildRoomCard(
            context,
            'Medical Students 🧬',
            'Anatomy',
            28,
            Colors.redAccent,
          ),
          _buildRoomCard(
            context,
            'Quiet Room 🤫',
            'Silent Study',
            105,
            Colors.blueGrey,
          ),
          _buildRoomCard(
            context,
            'Design Thinkers 🎨',
            'UI/UX Review',
            8,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(
    BuildContext context,
    String title,
    String topic,
    int activeUsers,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Joining $title...')));
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withAlpha(80), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.headset_mic, color: color),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$activeUsers',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                topic,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(delay: 200.ms).fade();
  }
}
