import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WritingCoachScreen extends StatefulWidget {
  const WritingCoachScreen({super.key});

  @override
  State<WritingCoachScreen> createState() => _WritingCoachScreenState();
}

class _WritingCoachScreenState extends State<WritingCoachScreen> {
  String _selectedGenre = 'Essay';
  final TextEditingController _writingController = TextEditingController();
  bool _isLoading = false;
  bool _reviewed = false;

  int _structureScore = 0;
  int _grammarScore = 0;
  int _vocabularyScore = 0;
  int _creativityScore = 0;
  int _coherenceScore = 0;
  String _suggestions = '';
  String _rewriteExample = '';
  List<Map<String, dynamic>> _pastReviews = [];

  final List<String> _genres = ['Essay', 'Story', 'Letter', 'Report', 'Debate'];

  int get _totalScore =>
      _structureScore +
      _grammarScore +
      _vocabularyScore +
      _creativityScore +
      _coherenceScore;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _writingController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('writing_reviews') ?? [];
    setState(() {
      _pastReviews = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveReview() async {
    final prefs = await SharedPreferences.getInstance();
    final reviews = prefs.getStringList('writing_reviews') ?? [];
    reviews.add(json.encode({
      'genre': _selectedGenre,
      'text': _writingController.text.trim(),
      'totalScore': _totalScore,
      'structure': _structureScore,
      'grammar': _grammarScore,
      'vocabulary': _vocabularyScore,
      'creativity': _creativityScore,
      'coherence': _coherenceScore,
      'suggestions': _suggestions,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (reviews.length > 20) reviews.removeAt(0);
    await prefs.setStringList('writing_reviews', reviews);
    _loadReviews();
  }

  Future<void> _reviewWriting() async {
    final text = _writingController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _reviewed = false;
    });

    try {
      final result = await AiAgentService.callAgent(
        'essay_helper',
        {'topic': _selectedGenre, 'subject': 'Writing', 'text': text},
      );
      _parseReview(result);
    } catch (_) {
      _structureScore = 12;
      _grammarScore = 13;
      _vocabularyScore = 11;
      _creativityScore = 10;
      _coherenceScore = 12;
      _suggestions = '1. Improve paragraph transitions.\n'
          '2. Use more varied sentence structures.\n'
          '3. Add supporting evidence for claims.';
      _rewriteExample = 'Consider revising your opening to be more engaging and direct.';
    }

    setState(() {
      _isLoading = false;
      _reviewed = true;
    });

    _saveReview();
  }

  void _parseReview(String response) {
    _structureScore = _extractScore(response, 'STRUCTURE:');
    _grammarScore = _extractScore(response, 'GRAMMAR:');
    _vocabularyScore = _extractScore(response, 'VOCABULARY:');
    _creativityScore = _extractScore(response, 'CREATIVITY:');
    _coherenceScore = _extractScore(response, 'COHERENCE:');
    _suggestions = _extractSection(response, 'SUGGESTIONS:');
    _rewriteExample = _extractSection(response, 'REWRITE:');

    if (_structureScore == 0 && _grammarScore == 0) {
      _structureScore = 12;
      _grammarScore = 12;
      _vocabularyScore = 12;
      _creativityScore = 12;
      _coherenceScore = 12;
      _suggestions = response;
      _rewriteExample = '';
    }
  }

  int _extractScore(String text, String header) {
    final idx = text.indexOf(header);
    if (idx == -1) return 0;
    final start = idx + header.length;
    final remaining = text.substring(start, (start + 10).clamp(0, text.length));
    final match = RegExp(r'(\d+)').firstMatch(remaining);
    if (match != null) {
      final score = int.tryParse(match.group(1)!) ?? 0;
      return score.clamp(0, 20);
    }
    return 0;
  }

  String _extractSection(String text, String header) {
    final idx = text.indexOf(header);
    if (idx == -1) return '';
    final start = idx + header.length;
    final sections = ['STRUCTURE:', 'GRAMMAR:', 'VOCABULARY:', 'CREATIVITY:', 'COHERENCE:', 'SUGGESTIONS:', 'REWRITE:'];
    int end = text.length;
    for (final s in sections) {
      if (s == header) continue;
      final sIdx = text.indexOf(s, start);
      if (sIdx != -1 && sIdx < end) end = sIdx;
    }
    return text.substring(start, end).trim();
  }

  void _resetCoach() {
    setState(() {
      _reviewed = false;
      _structureScore = 0;
      _grammarScore = 0;
      _vocabularyScore = 0;
      _creativityScore = 0;
      _coherenceScore = 0;
      _suggestions = '';
      _rewriteExample = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Writing Coach',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_reviewed)
            IconButton(
              onPressed: _resetCoach,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _reviewed ? _buildReviewView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Improve Your Writing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get AI feedback on your writing with detailed scoring.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildGenreSelector(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _writingController,
              style: const TextStyle(color: Colors.white),
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'Paste or type your $_selectedGenre here...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_writingController.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
              style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _isLoading || _writingController.text.trim().isEmpty
                      ? null
                      : _reviewWriting,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rate_review),
              label: Text(
                _isLoading ? 'Reviewing...' : 'Review',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastReviews.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_pastReviews.length.clamp(0, 5), (i) {
              final r = _pastReviews[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${r['totalScore'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['genre'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            (r['text'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(120),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildGenreSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Genre',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genres.map((g) {
              final isSelected = g == _selectedGenre;
              return GestureDetector(
                onTap: () => setState(() => _selectedGenre = g),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurpleAccent.withAlpha(40)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(15),
                    ),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(150),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildReviewView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildScoreCircle(),
          const SizedBox(height: 24),
          _buildScoreBreakdown(),
          const SizedBox(height: 16),
          if (_suggestions.isNotEmpty) _buildSuggestionsCard(),
          if (_rewriteExample.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRewriteCard(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetCoach,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Review Another',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCircle() {
    final color = _totalScore >= 70
        ? Colors.greenAccent
        : _totalScore >= 50
            ? Colors.amberAccent
            : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _totalScore / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_totalScore',
                      style: TextStyle(
                        color: color,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedGenre,
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fade().scale();
  }

  Widget _buildScoreBreakdown() {
    final scores = [
      ('Structure', _structureScore, Colors.blueAccent),
      ('Grammar', _grammarScore, Colors.greenAccent),
      ('Vocabulary', _vocabularyScore, Colors.amberAccent),
      ('Creativity', _creativityScore, Colors.pinkAccent),
      ('Coherence', _coherenceScore, Colors.tealAccent),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ...scores.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.$1,
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${s.$2}/20',
                          style: TextStyle(
                            color: s.$3,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: s.$2 / 20,
                        minHeight: 6,
                        backgroundColor: Colors.white.withAlpha(20),
                        valueColor: AlwaysStoppedAnimation(s.$3),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  Widget _buildSuggestionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amberAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.amberAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Suggestions for Improvement',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _suggestions,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  Widget _buildRewriteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.tealAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_fix_high, color: Colors.tealAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Rewrite Example',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _rewriteExample,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 13,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }
}
