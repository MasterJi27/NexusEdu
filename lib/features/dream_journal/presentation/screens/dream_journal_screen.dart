import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class DreamJournalScreen extends StatefulWidget {
  const DreamJournalScreen({super.key});

  @override
  State<DreamJournalScreen> createState() => _DreamJournalScreenState();
}

class _DreamJournalScreenState extends State<DreamJournalScreen>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _incubationCtrl = TextEditingController();
  String _mood = 'neutral';
  String _analysisResult = '';
  bool _isAnalyzing = false;
  int _lucidTimerSeconds = 900;
  Timer? _lucidTimer;
  bool _isSleepPrep = false;
  late AnimationController _starAnim;

  final _moods = [
    {'label': 'Happy', 'icon': Icons.sentiment_satisfied, 'value': 'happy', 'color': Colors.amber},
    {'label': 'Neutral', 'icon': Icons.sentiment_neutral, 'value': 'neutral', 'color': Colors.grey},
    {'label': 'Scary', 'icon': Icons.sentiment_dissatisfied, 'value': 'scary', 'color': Colors.deepPurple},
    {'label': 'Confusing', 'icon': Icons.psychology, 'value': 'confusing', 'color': Colors.cyan},
    {'label': 'Lucid', 'icon': Icons.auto_awesome, 'value': 'lucid', 'color': Colors.amberAccent},
  ];

  List<Map<String, dynamic>> get _dreams => AppSettings.instance.dreamJournal;

  @override
  void initState() {
    super.initState();
    _starAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _incubationCtrl.dispose();
    _lucidTimer?.cancel();
    _starAnim.dispose();
    super.dispose();
  }

  Future<void> _logDream() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final entry = {
      'title': title,
      'description': _descCtrl.text.trim(),
      'mood': _mood,
      'date': DateTime.now().toIso8601String(),
    };
    final dreams = List<Map<String, dynamic>>.from(_dreams);
    dreams.insert(0, entry);
    await AppSettings.instance.saveDreamJournal(dreams);
    _titleCtrl.clear();
    _descCtrl.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dream logged!')),
    );
  }

  Future<void> _analyzeDreams() async {
    if (_dreams.isEmpty) return;
    setState(() => _isAnalyzing = true);
    final dreamText = _dreams
        .map((d) => '${d['title']}: ${d['description']} (${d['mood']})')
        .join('\n');
    final result = await AiService.generateCurriculum(
      'Analyze these dream patterns for recurring themes, symbols, and learning insights:\n$dreamText',
    );
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _analysisResult = result;
    });
  }

  void _startLucidPrep() {
    setState(() => _isSleepPrep = true);
    _lucidTimerSeconds = 900;
    _lucidTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_lucidTimerSeconds <= 0) {
          t.cancel();
          _showDreamPortalMessage();
        } else {
          _lucidTimerSeconds--;
        }
      });
    });
  }

  void _showDreamPortalMessage() {
    final intention = _incubationCtrl.text.trim();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dream Portal Open'),
        content: Text(
          intention.isNotEmpty
              ? 'Your intention: "$intention"\n\nFocus on this as you drift into lucidity.'
              : 'The dream portal is open. Focus on what you want to learn.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I will remember'),
          )
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dream Journal', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_dreams.isNotEmpty)
            IconButton(
              icon: _isAnalyzing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              onPressed: _isAnalyzing ? null : _analyzeDreams,
              tooltip: 'Analyze Dreams',
            ),
        ],
      ),
      body: Stack(
        children: [
          CustomPaint(
            painter: _StarPainter(_starAnim.value, Colors.white.withAlpha(30)),
            size: Size.infinite,
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.withAlpha(80), Colors.deepPurple.withAlpha(60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('Dream Incubation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _incubationCtrl,
                      decoration: InputDecoration(
                        hintText: 'I want to learn about...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.black.withAlpha(60),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_isSleepPrep)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.bedtime),
                        label: const Text('Set Dream Intention'),
                        onPressed: _startLucidPrep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      )
                    else ...[
                      Text(_formatTime(_lucidTimerSeconds),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                      Text('Focus on your intention as you drift off...',
                          style: TextStyle(color: Colors.white.withAlpha(150))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Log a Dream', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: 'Dream title...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe your dream...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _moods.map((m) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(m['icon'] as IconData, size: 16, color: m['color'] as Color),
                      label: Text(m['label'] as String),
                      selected: _mood == m['value'],
                      onSelected: (v) => setState(() => _mood = m['value'] as String),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Log Dream'),
                  onPressed: _logDream,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),
              if (_analysisResult.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Dream Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.deepPurple.withAlpha(60)),
                  ),
                  child: SelectableText(_analysisResult),
                ),
              ],
              const SizedBox(height: 24),
              const Text('Dream History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              ...List.generate(min(_dreams.length, 10), (index) {
                final dream = _dreams[index];
                final moodData = _moods.firstWhere(
                  (m) => m['value'] == dream['mood'],
                  orElse: () => _moods[1],
                );
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(moodData['icon'] as IconData, color: moodData['color'] as Color),
                    title: Text(dream['title'] ?? '', style: const TextStyle(fontSize: 14)),
                    subtitle: Text(dream['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      (dream['date'] as String?)?.substring(0, 10) ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(100)),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 80),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final double phase;
  final Color color;
  _StarPainter(this.phase, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final random = Random(42);
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = (random.nextDouble() * 2 + 0.5) * (0.5 + 0.5 * sin(phase * 2 * pi + i * 0.5));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.phase != phase;
}
