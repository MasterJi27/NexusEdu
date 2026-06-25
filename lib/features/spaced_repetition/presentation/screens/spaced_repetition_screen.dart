import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';

class SpacedRepetitionScreen extends StatefulWidget {
  const SpacedRepetitionScreen({super.key});

  @override
  State<SpacedRepetitionScreen> createState() => _SpacedRepetitionScreenState();
}

class _SpacedRepetitionScreenState extends State<SpacedRepetitionScreen> {
  final _newItemCtrl = TextEditingController();
  String _selectedContext = 'Anywhere';
  String _mood = 'neutral';

  final _contexts = ['Anywhere', 'Library', 'Cafe', 'Outdoors', 'Desk'];
  final _moods = [
    {'label': 'Focused', 'icon': Icons.bolt, 'value': 'focused'},
    {'label': 'Neutral', 'icon': Icons.sentiment_neutral, 'value': 'neutral'},
    {'label': 'Stressed', 'icon': Icons.sentiment_dissatisfied, 'value': 'stressed'},
    {'label': 'Energetic', 'icon': Icons.energy_savings_leaf, 'value': 'energetic'},
    {'label': 'Tired', 'icon': Icons.bedtime, 'value': 'tired'},
  ];

  List<Map<String, dynamic>> get _items => AppSettings.instance.reviewSchedule;

  void _refresh() => setState(() {});

  List<Map<String, dynamic>> _getDueItems() {
    final now = DateTime.now();
    return _items.where((item) {
      final due = DateTime.tryParse(item['dueDate'] as String? ?? '');
      if (due == null) return false;
      if (due.isAfter(now)) return false;

      final contextMatch = item['context'] == 'Anywhere' || item['context'] == _selectedContext;
      final moodMatch = item['mood'] == 'neutral' || item['mood'] == _mood;
      return contextMatch && moodMatch;
    }).toList();
  }

  Future<void> _addReviewItem() async {
    final text = _newItemCtrl.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final intervals = [0, 1, 3, 7, 14, 30];
    final newItems = intervals.map((days) => {
      'id': DateTime.now().millisecondsSinceEpoch.toString() + '_$days',
      'content': text,
      'interval': days,
      'dueDate': now.add(Duration(days: days)).toIso8601String(),
      'context': _selectedContext,
      'mood': _mood,
      'reviews': 0,
      'streak': 0,
    }).toList();

    final updated = [...newItems, ..._items];
    await AppSettings.instance.saveReviewSchedule(updated);
    _newItemCtrl.clear();
    _refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added 6 review slots across time intervals')),
    );
  }

  Future<void> _markReviewed(String id) async {
    final idx = _items.indexWhere((i) => i['id'] == id);
    if (idx == -1) return;

    final item = Map<String, dynamic>.from(_items[idx]);
    final reviews = (item['reviews'] as int? ?? 0) + 1;
    item['reviews'] = reviews;
    item['streak'] = (item['streak'] as int? ?? 0) + 1;

    final nextInterval = [1, 3, 7, 14, 30, 60][reviews.clamp(0, 5)];
    item['interval'] = nextInterval;
    item['dueDate'] = DateTime.now().add(Duration(days: nextInterval)).toIso8601String();

    final updated = List<Map<String, dynamic>>.from(_items);
    updated[idx] = item;
    await AppSettings.instance.saveReviewSchedule(updated);
    _refresh();
  }

  @override
  void dispose() {
    _newItemCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dueItems = _getDueItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('4D Spaced Repetition', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.withAlpha(60), Colors.cyan.withAlpha(40)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _dimensionChip(Icons.schedule, 'Time', '${dueItems.length} due', Colors.blueAccent),
                    _dimensionChip(Icons.location_on, 'Context', _selectedContext, Colors.greenAccent),
                    _dimensionChip(Icons.mood, 'Mood', _mood, Colors.orangeAccent),
                    _dimensionChip(Icons.people, 'Social', '${_items.where((i) => (i['streak'] as int? ?? 0) > 0).length} active', Colors.pinkAccent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Due Now (${dueItems.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (dueItems.isEmpty)
            Card(
              color: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Colors.green.withAlpha(120)),
                    const SizedBox(height: 8),
                    Text('All caught up!', style: TextStyle(color: Colors.white.withAlpha(180))),
                    const SizedBox(height: 4),
                    Text('Add items below to start reviewing',
                        style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...dueItems.map((item) => Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.autorenew,
                      color: Colors.deepPurpleAccent.withAlpha(180),
                      size: 20,
                    ),
                    title: Text(item['content'] ?? '', style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      'Interval: ${item['interval']}d | Reviews: ${item['reviews']} | Streak: ${item['streak']}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(120)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                      onPressed: () => _markReviewed(item['id'] as String),
                    ),
                  ),
                )),
          const SizedBox(height: 24),
          Text('Add New Review Item',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItemCtrl,
                  decoration: InputDecoration(
                    hintText: 'What do you want to remember?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: _addReviewItem,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _contexts.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  selected: _selectedContext == c,
                  onSelected: (v) => setState(() => _selectedContext = c),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _moods.map((m) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(m['icon'] as IconData, size: 16),
                  label: Text(m['label'] as String, style: const TextStyle(fontSize: 12)),
                  selected: _mood == m['value'],
                  onSelected: (v) => setState(() => _mood = m['value'] as String),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Schedule Overview',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [1, 3, 7, 14, 30, 60].map((day) {
                final count = _items.where((i) => i['interval'] == day).length;
                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('d', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11)),
                      Text('$count items', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _dimensionChip(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(150))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
