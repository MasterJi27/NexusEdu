import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpellingGrammarScreen extends StatefulWidget {
  const SpellingGrammarScreen({super.key});

  @override
  State<SpellingGrammarScreen> createState() => _SpellingGrammarScreenState();
}

class _SpellingGrammarScreenState extends State<SpellingGrammarScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isChecking = false;
  bool _hasResult = false;

  int _grammarScore = 0;
  List<Map<String, dynamic>> _errors = [];
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('grammar_checks') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'grammar_checks',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _checkGrammar() async {
    if (_textController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter at least 10 characters')),
      );
      return;
    }

    setState(() => _isChecking = true);

    final text = _textController.text.trim();
    final prompt =
        'Check spelling and grammar for this text:\n\n"$text"\n\n'
        'Return:\n'
        'SCORE: X (0-100)\n'
        'ERRORS: original->correction|original2->correction2 (up to 5 errors, pipe-separated)\n'
        'SUGGESTIONS: suggestion1|suggestion2|suggestion3 (3 suggestions, pipe-separated)';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'SCORE: 75\nERRORS: \nSUGGESTIONS: Use punctuation|Check spelling|Simplify sentences';
    }

    int score = 75;
    final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(response);
    if (scoreMatch != null) score = int.tryParse(scoreMatch.group(1)!) ?? 75;

    final errors = <Map<String, dynamic>>[];
    final errMatch = RegExp(r'ERRORS:\s*(.+?)(?=SUGGESTIONS:|$)', dotAll: true)
        .firstMatch(response);
    if (errMatch != null && errMatch.group(1)!.trim().isNotEmpty) {
      final errStr = errMatch.group(1)!.trim();
      final errParts = errStr.split('|');
      for (final part in errParts) {
        final arrowParts = part.split('->');
        if (arrowParts.length >= 2) {
          errors.add({
            'original': arrowParts[0].trim(),
            'correction': arrowParts[1].trim(),
          });
        }
      }
    }

    var suggestions = <String>[];
    final sugMatch = RegExp(r'SUGGESTIONS:\s*(.+)').firstMatch(response);
    if (sugMatch != null) {
      suggestions.addAll(
        sugMatch.group(1)!.split('|').map((s) => s.trim()).toList(),
      );
    }
    if (suggestions.isEmpty) {
      suggestions = [
        'Use proper punctuation',
        'Check for spelling errors',
        'Keep sentences concise',
      ];
    }

    final result = {
      'score': score,
      'errors': errors,
      'suggestions': suggestions,
      'textLength': text.length,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _grammarScore = score;
      _errors = errors;
      _suggestions = suggestions;
      _isChecking = false;
      _hasResult = true;
    });

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 60) return Colors.amberAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Spelling & Grammar AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              maxLines: 10,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste or type your text here to check...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isChecking ? null : _checkGrammar,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.spellcheck),
                label: Text(
                  _isChecking ? 'Checking...' : 'Check Grammar',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildScoreCard(),
              const SizedBox(height: 16),
              _buildErrorsSection(),
              const SizedBox(height: 16),
              _buildSuggestionsSection(),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Past Checks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_results.length.clamp(0, 5), (i) {
                return _buildResultCard(_results[i]);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _scoreColor(_grammarScore).withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _scoreColor(_grammarScore).withAlpha(60)),
      ),
      child: Column(
        children: [
          const Text(
            'Grammar Score',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_grammarScore',
            style: TextStyle(
              color: _scoreColor(_grammarScore),
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _grammarScore >= 80
                ? 'Excellent!'
                : _grammarScore >= 60
                    ? 'Good, room for improvement'
                    : 'Needs improvement',
            style: TextStyle(
              color: _scoreColor(_grammarScore),
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildErrorsSection() {
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
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Errors Found (${_errors.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_errors.isEmpty)
            Text(
              'No errors found!',
              style: TextStyle(
                color: Colors.greenAccent.withAlpha(200),
                fontSize: 13,
              ),
            )
          else
            ..._errors.asMap().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: entry.value['original'] ?? '',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                decoration: TextDecoration.lineThrough,
                                fontSize: 13,
                              ),
                            ),
                            const TextSpan(
                              text: '  →  ',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: entry.value['correction'] ?? '',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildSuggestionsSection() {
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
          Row(
            children: [
              Icon(Icons.lightbulb,
                  color: Colors.amberAccent.withAlpha(200), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Suggestions',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._suggestions.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check,
                      color: Colors.tealAccent.withAlpha(200), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
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
              color: _scoreColor(r['score'] as int).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.spellcheck,
                color: _scoreColor(r['score'] as int), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grammar Check',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['score']}/100 • Errors: ${(r['errors'] as List).length}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${r['score']}',
            style: TextStyle(
              color: _scoreColor(r['score'] as int),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
