import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyAbroadScreen extends StatefulWidget {
  const StudyAbroadScreen({super.key});

  @override
  State<StudyAbroadScreen> createState() => _StudyAbroadScreenState();
}

class _StudyAbroadScreenState extends State<StudyAbroadScreen> {
  String _selectedCountry = 'USA';
  final TextEditingController _satController = TextEditingController();
  final TextEditingController _greController = TextEditingController();
  final TextEditingController _ieltsController = TextEditingController();
  final TextEditingController _toeflController = TextEditingController();
  bool _isLoading = false;
  bool _guided = false;

  String _universityRecs = '';
  String _timeline = '';
  String _scholarships = '';
  String _sopTips = '';
  List<Map<String, dynamic>> _pastGuidance = [];

  final List<String> _countries = ['USA', 'UK', 'Canada', 'Australia', 'Germany'];

  @override
  void initState() {
    super.initState();
    _loadGuidance();
  }

  @override
  void dispose() {
    _satController.dispose();
    _greController.dispose();
    _ieltsController.dispose();
    _toeflController.dispose();
    super.dispose();
  }

  Future<void> _loadGuidance() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('study_abroad_data') ?? [];
    setState(() {
      _pastGuidance = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveGuidance() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('study_abroad_data') ?? [];
    data.add(json.encode({
      'country': _selectedCountry,
      'scores': {
        'sat': _satController.text.trim(),
        'gre': _greController.text.trim(),
        'ielts': _ieltsController.text.trim(),
        'toefl': _toeflController.text.trim(),
      },
      'universityRecs': _universityRecs,
      'timeline': _timeline,
      'scholarships': _scholarships,
      'sopTips': _sopTips,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (data.length > 20) data.removeAt(0);
    await prefs.setStringList('study_abroad_data', data);
    _loadGuidance();
  }

  Future<void> _getGuidance() async {
    setState(() {
      _isLoading = true;
      _guided = false;
    });

    final scores = <String, String>{};
    if (_satController.text.trim().isNotEmpty) {
      scores['SAT'] = _satController.text.trim();
    }
    if (_greController.text.trim().isNotEmpty) {
      scores['GRE'] = _greController.text.trim();
    }
    if (_ieltsController.text.trim().isNotEmpty) {
      scores['IELTS'] = _ieltsController.text.trim();
    }
    if (_toeflController.text.trim().isNotEmpty) {
      scores['TOEFL'] = _toeflController.text.trim();
    }

    final scoresStr = scores.entries.map((e) => '${e.key}: ${e.value}').join(', ');

    try {
      final result = await AiAgentService.callAgent(
        'career_guidance',
        {
          'interests': 'Study in $_selectedCountry',
          'subjects': scoresStr.isNotEmpty ? scoresStr : 'General',
        },
      );
      _parseGuidance(result);
    } catch (_) {
      _universityRecs = '1. Top University in $_selectedCountry - 85% match\n'
          '2. State University - 75% match\n'
          '3. Technical Institute - 70% match';
      _timeline = 'September: Start applications\n'
          'December: Early deadlines\n'
          'January: Regular deadlines\n'
          'March-April: Decisions';
      _scholarships = '1. Merit Scholarship - Based on academic performance\n'
          '2. Need-based Aid - Financial assistance\n'
          '3. Research Assistantships';
      _sopTips = '1. Start with a compelling hook\n'
          '2. Show research about the university\n'
          '3. Connect past experiences to future goals\n'
          '4. Be specific about why this country\n'
          '5. Proofread multiple times';
    }

    setState(() {
      _isLoading = false;
      _guided = true;
    });

    _saveGuidance();
  }

  void _parseGuidance(String response) {
    _universityRecs = _extractSection(response, 'UNIVERSITIES:');
    _timeline = _extractSection(response, 'TIMELINE:');
    _scholarships = _extractSection(response, 'SCHOLARSHIPS:');
    _sopTips = _extractSection(response, 'SOP_TIPS:');

    if (_universityRecs.isEmpty) {
      _universityRecs = response;
      _timeline = '';
      _scholarships = '';
      _sopTips = '';
    }
  }

  String _extractSection(String text, String header) {
    final idx = text.indexOf(header);
    if (idx == -1) return '';
    final start = idx + header.length;
    final sections = [
      'UNIVERSITIES:',
      'TIMELINE:',
      'SCHOLARSHIPS:',
      'SOP_TIPS:',
    ];
    int end = text.length;
    for (final s in sections) {
      if (s == header) continue;
      final sIdx = text.indexOf(s, start);
      if (sIdx != -1 && sIdx < end) end = sIdx;
    }
    return text.substring(start, end).trim();
  }

  void _resetGuide() {
    setState(() {
      _guided = false;
      _universityRecs = '';
      _timeline = '';
      _scholarships = '';
      _sopTips = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Study Abroad Counselor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_guided)
            IconButton(
              onPressed: _resetGuide,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _guided ? _buildResultView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flight,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Plan Your Journey',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get university recommendations, timelines, and scholarship info.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildCountrySelector(),
          const SizedBox(height: 16),
          _buildTestScoresSection(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _getGuidance,
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
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading ? 'Getting Guidance...' : 'Get Guidance',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastGuidance.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Guidance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_pastGuidance.length.clamp(0, 5), (i) {
              final g = _pastGuidance[i];
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
                        color: Colors.tealAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.flight,
                          color: Colors.tealAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g['country'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${g['universityRecs']?.toString().split('\n').length ?? 0} universities recommended',
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

  Widget _buildCountrySelector() {
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
            'Target Country',
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
            children: _countries.map((c) {
              final isSelected = c == _selectedCountry;
              return GestureDetector(
                onTap: () => setState(() => _selectedCountry = c),
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
                    c,
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

  Widget _buildTestScoresSection() {
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
            'Test Scores (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScoreField('SAT', _satController, '1200+'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScoreField('GRE', _greController, '310+'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildScoreField('IELTS', _ieltsController, '7.0+'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScoreField('TOEFL', _toeflController, '100+'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildScoreField(
      String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withAlpha(150),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withAlpha(20)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withAlpha(20)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.deepPurpleAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flight,
                    color: Colors.deepPurpleAccent, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Study in $_selectedCountry',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_universityRecs.isNotEmpty)
            _buildResultCard(
              'University Recommendations',
              _universityRecs,
              Icons.account_balance,
              Colors.deepPurpleAccent,
            ),
          if (_timeline.isNotEmpty)
            _buildResultCard(
              'Application Timeline',
              _timeline,
              Icons.calendar_today,
              Colors.tealAccent,
            ),
          if (_scholarships.isNotEmpty)
            _buildResultCard(
              'Scholarship Suggestions',
              _scholarships,
              Icons.attach_money,
              Colors.amberAccent,
            ),
          if (_sopTips.isNotEmpty)
            _buildResultCard(
              'SOP Tips',
              _sopTips,
              Icons.lightbulb,
              Colors.greenAccent,
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetGuide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'New Guidance',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
      String title, String content, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }
}
