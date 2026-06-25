import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudyRoomsScreen extends StatefulWidget {
  const StudyRoomsScreen({super.key});

  @override
  State<StudyRoomsScreen> createState() => _StudyRoomsScreenState();
}

class _StudyRoomsScreenState extends State<StudyRoomsScreen> {
  final List<Map<String, dynamic>> _rooms = [
    {
      'name': 'JEE Physics Group',
      'members': 12,
      'subject': 'Physics',
      'color': Colors.blueAccent,
      'active': true,
      'lastMessage': 'Let\'s solve rotation problems',
    },
    {
      'name': 'NEET Biology Hub',
      'members': 8,
      'subject': 'Biology',
      'color': Colors.greenAccent,
      'active': true,
      'lastMessage': 'Cell division notes shared',
    },
    {
      'name': 'Code Warriors',
      'members': 15,
      'subject': 'CS',
      'color': Colors.purpleAccent,
      'active': false,
      'lastMessage': 'DSA session at 4 PM',
    },
    {
      'name': 'Math Problem Solvers',
      'members': 6,
      'subject': 'Mathematics',
      'color': Colors.orangeAccent,
      'active': true,
      'lastMessage': 'Integration by parts examples',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Rooms', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showCreateRoomSheet,
            tooltip: 'Create Room',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLiveBanner().animate().fade().slideY(begin: -0.05),
          const SizedBox(height: 20),
          const Text('Active Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._rooms.where((r) => r['active']).map((r) => _buildRoomCard(r)).toList(),
          const SizedBox(height: 24),
          const Text('Your Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._rooms.map((r) => _buildRoomCard(r)).toList(),
        ],
      ),
    );
  }

  Widget _buildLiveBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.withAlpha(50), Colors.green.withAlpha(30)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.teal.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups, color: Colors.teal, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Real-time Study Rooms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  'Join live rooms, share whiteboard, study together.',
                  style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (room['color'] as Color).withAlpha(50)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _joinRoom(room),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: (room['color'] as Color).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.group, color: room['color'] as Color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room['active'])
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room['lastMessage'],
                    style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${room['members']} online',
              style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _joinRoom(Map<String, dynamic> room) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joining "${room['name']}"... (WebSocket coming soon)')),
    );
  }

  void _showCreateRoomSheet() {
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 4,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Study Room', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Room name', hintText: 'e.g. Physics Study Group'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    setState(() {
                      _rooms.insert(0, {
                        'name': nameController.text,
                        'members': 1,
                        'subject': 'General',
                        'color': Colors.blueAccent,
                        'active': true,
                        'lastMessage': 'Room created',
                      });
                    });
                    Navigator.pop(ctx);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
