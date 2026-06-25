import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MistakeEntry {
  final String question;
  final String subject;
  final String correctAnswer;
  final String explanation;
  final DateTime date;
  int reviewCount;
  bool mastered;

  MistakeEntry({
    required this.question,
    required this.subject,
    required this.correctAnswer,
    required this.explanation,
    required this.date,
    this.reviewCount = 0,
    this.mastered = false,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'subject': subject,
    'correctAnswer': correctAnswer,
    'explanation': explanation,
    'date': date.toIso8601String(),
    'reviewCount': reviewCount,
    'mastered': mastered,
  };

  factory MistakeEntry.fromJson(Map<String, dynamic> json) => MistakeEntry(
    question: json['question'],
    subject: json['subject'],
    correctAnswer: json['correctAnswer'],
    explanation: json['explanation'],
    date: DateTime.parse(json['date']),
    reviewCount: json['reviewCount'] ?? 0,
    mastered: json['mastered'] ?? false,
  );
}

class MistakeJournalScreen extends StatefulWidget {
  const MistakeJournalScreen({super.key});

  @override
  State<MistakeJournalScreen> createState() => _MistakeJournalScreenState();
}

class _MistakeJournalScreenState extends State<MistakeJournalScreen> {
  List<MistakeEntry> _mistakes = [];
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('mistake_journal');
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      setState(() {
        _mistakes = json.map((j) => MistakeEntry.fromJson(j)).toList();
        _mistakes.sort((a, b) => b.date.compareTo(a.date));
      });
    }
    if (_mistakes.isEmpty) {
      _mistakes = _getSampleMistakes();
      await _saveMistakes();
    }
  }

  List<MistakeEntry> _getSampleMistakes() {
    return [
      MistakeEntry(
        question: 'What is the derivative of sin(x)?',
        subject: 'Mathematics',
        correctAnswer: 'cos(x)',
        explanation: 'd/dx[sin(x)] = cos(x). Remember: sin→cos→-sin→-cos cycle.',
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      MistakeEntry(
        question: 'Newton\'s Third Law states...',
        subject: 'Physics',
        correctAnswer: 'Every action has an equal and opposite reaction',
        explanation: 'For every action force, there is an equal and opposite reaction force.',
        date: DateTime.now().subtract(const Duration(days: 2)),
      ),
      MistakeEntry(
        question: 'What is the pH of a strong acid?',
        subject: 'Chemistry',
        correctAnswer: 'Less than 7',
        explanation: 'Strong acids have pH < 7. The lower the pH, the stronger the acid.',
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
      MistakeEntry(
        question: 'Mitochondria is known as...',
        subject: 'Biology',
        correctAnswer: 'Powerhouse of the cell',
        explanation: 'Mitochondria produce ATP through cellular respiration.',
        date: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ];
  }

  Future<void> _saveMistakes() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _mistakes.map((m) => m.toJson()).toList();
    await prefs.setString('mistake_journal', jsonEncode(json));
  }

  List<MistakeEntry> get _filteredMistakes {
    if (_filter == 'All') return _mistakes;
    if (_filter == 'Mastered') return _mistakes.where((m) => m.mastered).toList();
    if (_filter == 'Review') return _mistakes.where((m) => !m.mastered).toList();
    return _mistakes.where((m) => m.subject == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mastered = _mistakes.where((m) => m.mastered).length;
    final review = _mistakes.where((m) => !m.mastered).length;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text('Mistake Journal', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard('Total', '${_mistakes.length}', Colors.deepPurpleAccent),
                const SizedBox(width: 12),
                _buildStatCard('Mastered', '$mastered', Colors.greenAccent),
                const SizedBox(width: 12),
                _buildStatCard('Review', '$review', Colors.orangeAccent),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['All', 'Review', 'Mastered', 'Physics', 'Chemistry', 'Mathematics', 'Biology'].map((f) {
                final isSelected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12)),
                    selected: isSelected,
                    selectedColor: Colors.deepPurpleAccent,
                    backgroundColor: Colors.white10,
                    onSelected: (v) => setState(() => _filter = f),
                    checkmarkColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredMistakes.isEmpty
                ? const Center(child: Text('No mistakes yet!', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredMistakes.length,
                    itemBuilder: (context, index) {
                      final mistake = _filteredMistakes[index];
                      return _buildMistakeCard(mistake);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMistakeCard(MistakeEntry mistake) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mistake.mastered ? Colors.greenAccent.withOpacity(0.05) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mistake.mastered ? Colors.greenAccent.withOpacity(0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getSubjectColor(mistake.subject).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(mistake.subject, style: TextStyle(color: _getSubjectColor(mistake.subject), fontSize: 10)),
              ),
              const Spacer(),
              if (mistake.mastered)
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
              else
                const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(mistake.question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(mistake.correctAnswer, style: const TextStyle(color: Colors.greenAccent))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(mistake.explanation, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Reviewed ${mistake.reviewCount}x', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              if (!mistake.mastered)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      mistake.reviewCount++;
                      if (mistake.reviewCount >= 3) mistake.mastered = true;
                    });
                    _saveMistakes();
                  },
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Review', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.deepPurpleAccent),
                ),
              if (!mistake.mastered)
                TextButton.icon(
                  onPressed: () {
                    setState(() => mistake.mastered = true);
                    _saveMistakes();
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Mastered', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Physics': return Colors.blueAccent;
      case 'Chemistry': return Colors.greenAccent;
      case 'Mathematics': return Colors.orangeAccent;
      case 'Biology': return Colors.pinkAccent;
      default: return Colors.deepPurpleAccent;
    }
  }
}
