import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_filter_chips.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

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
    {
      'label': 'Stressed',
      'icon': Icons.sentiment_dissatisfied,
      'value': 'stressed',
    },
    {
      'label': 'Energetic',
      'icon': Icons.energy_savings_leaf,
      'value': 'energetic',
    },
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

      final contextMatch =
          item['context'] == 'Anywhere' || item['context'] == _selectedContext;
      final moodMatch = item['mood'] == 'neutral' || item['mood'] == _mood;
      return contextMatch && moodMatch;
    }).toList();
  }

  Future<void> _addReviewItem() async {
    final text = _newItemCtrl.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final intervals = [0, 1, 3, 7, 14, 30];
    final newItems = intervals
        .map(
          (days) => {
            'id': '${DateTime.now().millisecondsSinceEpoch}_$days',
            'content': text,
            'interval': days,
            'dueDate': now.add(Duration(days: days)).toIso8601String(),
            'context': _selectedContext,
            'mood': _mood,
            'reviews': 0,
            'streak': 0,
          },
        )
        .toList();

    final updated = [...newItems, ..._items];
    await AppSettings.instance.saveReviewSchedule(updated);
    if (!mounted) return;
    _newItemCtrl.clear();
    _refresh();
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
    item['dueDate'] = DateTime.now()
        .add(Duration(days: nextInterval))
        .toIso8601String();

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
    final t = context.tokens;
    final dueItems = _getDueItems();

    return NexusScreen(
      title: '4D Spaced Repetition',
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: AppRadius.brMd,
              border: Border.all(color: t.primaryTintBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _dimensionChip(
                  context,
                  Icons.schedule,
                  'Time',
                  '${dueItems.length} due',
                  t.primary,
                ),
                _dimensionChip(
                  context,
                  Icons.location_on,
                  'Context',
                  _selectedContext,
                  t.statusPresent,
                ),
                _dimensionChip(
                  context,
                  Icons.mood,
                  'Mood',
                  _mood,
                  t.statusLate,
                ),
                _dimensionChip(
                  context,
                  Icons.people,
                  'Social',
                  '${_items.where((i) => (i['streak'] as int? ?? 0) > 0).length} active',
                  t.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text('Due Now (${dueItems.length})', style: context.text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          if (dueItems.isEmpty)
            const NexusStateView.empty(
              title: 'All caught up!',
              description: 'Add items below to start reviewing',
              icon: Icons.check_circle_outline,
            )
          else
            ...dueItems.map(
              (item) => NexusCard(
                margin: const EdgeInsets.only(bottom: AppSpace.xs),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                child: ListTile(
                  leading: Icon(
                    Icons.autorenew,
                    color: t.primary,
                    size: 20,
                  ),
                  title: Text(
                    item['content'] ?? '',
                    style: context.text.bodyMedium,
                  ),
                  subtitle: Text(
                    'Interval: ${item['interval']}d | Reviews: ${item['reviews']} | Streak: ${item['streak']}',
                    style: context.text.bodySmall,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.check_circle, color: t.statusPresent),
                    onPressed: () => _markReviewed(item['id'] as String),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          Text('Add New Review Item', style: context.text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: NexusTextField(
                  controller: _newItemCtrl,
                  hint: 'What do you want to remember?',
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: _addReviewItem,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          NexusFilterChips<String>(
            options: _contexts,
            selected: _selectedContext,
            onSelected: (c) => setState(() => _selectedContext = c),
          ),
          const SizedBox(height: AppSpace.xs),
          NexusFilterChips<String>(
            options: _moods.map((m) => m['value'] as String).toList(),
            selected: _mood,
            onSelected: (v) => setState(() => _mood = v),
            labelBuilder: (v) => _moods.firstWhere((m) => m['value'] == v)['label'] as String,
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Schedule Overview', style: context.text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [1, 3, 7, 14, 30, 60].map((day) {
                final count = _items.where((i) => i['interval'] == day).length;
                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: AppSpace.xs),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: context.typeExtras.figure.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'd',
                        style: context.text.labelSmall?.copyWith(
                          color: t.inkMuted,
                        ),
                      ),
                      Text(
                        '$count items',
                        style: context.text.labelSmall?.copyWith(
                          color: t.inkFaint,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }

  Widget _dimensionChip(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final t = context.tokens;
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: AppSpace.xxs),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(color: t.inkMuted),
        ),
        Text(
          value,
          style: context.text.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
