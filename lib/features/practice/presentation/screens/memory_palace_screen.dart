import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class MemoryPalaceScreen extends StatefulWidget {
  const MemoryPalaceScreen({super.key});

  @override
  State<MemoryPalaceScreen> createState() => _MemoryPalaceScreenState();
}

class _MemoryPalaceScreenState extends State<MemoryPalaceScreen> {
  bool _isLoading = false;
  String _currentTopic = 'Causes of World War I (MAIN)';

  final List<Map<String, dynamic>> _palaceCards = [
    {
      'title': 'The Lobby: Militarism',
      'icon': Icons.security,
      'color': Colors.redAccent,
      'story': 'Imagine walking into a grand hotel lobby. It is completely filled with soldiers polishing massive, shiny cannons. This represents Militarism—nations building up vast armies.',
    },
    {
      'title': 'The Elevator: Alliances',
      'icon': Icons.handshake,
      'color': Colors.blueAccent,
      'story': 'You step into the elevator, but everyone inside is tied together with thick ropes. If one person falls, everyone is dragged down. This represents the complex web of Alliances.',
    },
    {
      'title': 'The Penthouse: Imperialism',
      'icon': Icons.public,
      'color': Colors.green,
      'story': 'The penthouse is overflowing with stolen gold, spices, and maps. Rich tycoons are fighting over pieces of a globe. This is Imperialism—the scramble for colonies and resources.',
    },
    {
      'title': 'The Roof: Nationalism',
      'icon': Icons.flag,
      'color': Colors.orangeAccent,
      'story': 'On the roof, people are screaming at each other through megaphones, aggressively waving their own country\'s flags and refusing to listen. This is extreme Nationalism.',
    },
  ];

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'security': return Icons.security;
      case 'handshake': return Icons.handshake;
      case 'public': return Icons.public;
      case 'flag': return Icons.flag;
      case 'science': return Icons.science;
      case 'history': return Icons.history;
      case 'auto_stories': return Icons.auto_stories;
      case 'rocket_launch': return Icons.rocket_launch;
      case 'psychology': return Icons.psychology;
      default: return Icons.star;
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'red': return Colors.redAccent;
      case 'blue': return Colors.blueAccent;
      case 'green': return Colors.green;
      case 'orange': return Colors.orangeAccent;
      case 'purple': return Colors.purpleAccent;
      case 'teal': return Colors.teal;
      default: return Colors.indigoAccent;
    }
  }

  void _generateCustomPalace(String topic) async {
    if (topic.isEmpty) return;
    setState(() {
      _isLoading = true;
    });

    final apiCards = await AiService.generateMemoryPalace(topic);

    if (!mounted) return;

    if (apiCards.isNotEmpty) {
      setState(() {
        _currentTopic = topic;
        _palaceCards.clear();
        for (var item in apiCards) {
          _palaceCards.add({
            'title': item['title'] ?? 'Room',
            'icon': _getIconFromString(item['iconName'] ?? ''),
            'color': _getColorFromString(item['colorName'] ?? ''),
            'story': item['story'] ?? '',
          });
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate memory palace. Please check your API key.')),
      );
    }
  }

  void _showCreatePalaceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Custom Memory Palace'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter topic (e.g. Periodic Table, Photosynthesis)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generateCustomPalace(controller.text.trim());
              },
              child: const Text('Generate'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Memory Palace', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showCreatePalaceDialog,
            tooltip: 'Create Custom Palace',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  _currentTopic,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Swipe through the generated rooms to lock this concept into your long-term memory.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().slideY().fade(),
          
          _isLoading
              ? const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.deepPurpleAccent),
                        SizedBox(height: 16),
                        Text('Generating memory palace rooms...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: Swiper(
                    itemBuilder: (BuildContext context, int index) {
                      final card = _palaceCards[index];
                      return _buildPalaceCard(card);
                    },
                    itemCount: _palaceCards.length,
                    itemWidth: 350.0,
                    itemHeight: 500.0,
                    layout: SwiperLayout.STACK,
                  ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
                ),
          
          Padding(
            padding: const EdgeInsets.only(bottom: 48.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swipe_left, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Swipe to explore', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.swipe_right, color: Colors.grey),
              ],
            ).animate(onPlay: (c) => c.repeat(reverse: true)).slideX(begin: -0.1, end: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildPalaceCard(Map<String, dynamic> card) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: card['color'].withAlpha(50),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: card['color'].withAlpha(100), width: 2),
      ),
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: card['color'].withAlpha(30),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Center(
              child: Icon(card['icon'], size: 100, color: card['color'])
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(end: 1.1, duration: 2.seconds),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card['title'],
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: card['color']),
                ),
                const SizedBox(height: 24),
                Text(
                  card['story'],
                  style: const TextStyle(fontSize: 18, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
