import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudyBuddyMatchScreen extends StatefulWidget {
  const StudyBuddyMatchScreen({super.key});

  @override
  State<StudyBuddyMatchScreen> createState() => _StudyBuddyMatchScreenState();
}

class _StudyBuddyMatchScreenState extends State<StudyBuddyMatchScreen> {
  final List<Map<String, dynamic>> _profiles = [
    {
      'name': 'Sarah',
      'major': 'Computer Science',
      'weakness': 'Data Structures',
      'hours': 'Night Owl (10PM - 2AM)',
      'color': Colors.purpleAccent,
      'image': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?q=80&w=1000&auto=format&fit=crop',
    },
    {
      'name': 'James',
      'major': 'Pre-Med',
      'weakness': 'Organic Chemistry',
      'hours': 'Early Bird (6AM - 9AM)',
      'color': Colors.blueAccent,
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1000&auto=format&fit=crop',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Study Buddy 🤝', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Swipe right if they match your vibe. Swipe left to pass.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          Expanded(
            child: Swiper(
              itemCount: _profiles.length,
              layout: SwiperLayout.TINDER,
              itemWidth: MediaQuery.of(context).size.width * 0.85,
              itemHeight: MediaQuery.of(context).size.height * 0.6,
              itemBuilder: (context, index) {
                final p = _profiles[index];
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    image: DecorationImage(
                      image: NetworkImage(p['image']),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(p['name'], style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                        Text(p['major'], style: TextStyle(color: p['color'], fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildTag(Icons.warning, 'Struggling with ${p['weakness']}'),
                        const SizedBox(height: 8),
                        _buildTag(Icons.schedule, p['hours']),
                      ],
                    ),
                  ),
                );
              },
            ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 48.0, top: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  heroTag: 'pass',
                  onPressed: () {},
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  child: const Icon(Icons.close, size: 40),
                ).animate().scale(delay: 400.ms),
                const SizedBox(width: 32),
                FloatingActionButton.large(
                  heroTag: 'match',
                  onPressed: () {},
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.greenAccent.shade700,
                  child: const Icon(Icons.favorite, size: 40),
                ).animate().scale(delay: 500.ms),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
