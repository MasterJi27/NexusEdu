import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class CareerCounselorScreen extends StatefulWidget {
  const CareerCounselorScreen({super.key});

  @override
  State<CareerCounselorScreen> createState() => _CareerCounselorScreenState();
}

class _CareerCounselorScreenState extends State<CareerCounselorScreen> {
  final TextEditingController _classController = TextEditingController(text: '12');
  final List<String> _selectedInterests = [];
  final Map<String, TextEditingController> _marksControllers = {};
  bool _isLoading = false;
  List<Map<String, dynamic>> _recommendations = [];

  static const List<String> _allInterests = [
    'Technology', 'Medicine', 'Engineering', 'Commerce', 'Arts',
    'Law', 'Design', 'Music', 'Sports', 'Research',
    'Teaching', 'Finance', 'Writing', 'Business', 'Social Work',
  ];

  static const List<String> _coreSubjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English'];

  @override
  void initState() {
    super.initState();
    for (final sub in _coreSubjects) {
      _marksControllers[sub] = TextEditingController();
    }
    _loadRecommendations();
  }

  @override
  void dispose() {
    _classController.dispose();
    for (final c in _marksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('career_recommendations');
    if (saved != null && saved.isNotEmpty) {
      final last = jsonDecode(saved.last) as Map<String, dynamic>;
      _classController.text = last['class'] ?? '12';
    }
    setState(() {});
  }

  Future<void> _saveRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('career_recommendations') ?? [];
    history.add(jsonEncode({
      'class': _classController.text,
      'interests': _selectedInterests,
      'recommendations': _recommendations,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (history.length > 20) history.removeAt(0);
    await prefs.setStringList('career_recommendations', history);
  }

  Future<void> _getRecommendations() async {
    if (_selectedInterests.isEmpty) return;

    setState(() {
      _isLoading = true;
      _recommendations = [];
    });

    final marksStr = _marksControllers.entries
        .where((e) => e.value.text.trim().isNotEmpty)
        .map((e) => '${e.key}: ${e.value.text.trim()}')
        .join(', ');

    final prompt = 'Career recommendations for Class ${_classController.text} student.\n'
        'Interests: ${_selectedInterests.join(", ")}\n'
        'Marks: $marksStr\n\n'
        'Provide 4 career suggestions with: title, match percentage (60-99%), '
        'required qualifications, 2 college suggestions (India), and salary range in India.\n'
        'Format as JSON: {"careers": [{"title":"...", "match":85, "qualifications":"...", '
        '"colleges":["...", "..."], "salary":"..."}]}';

    final response = await AiAgentService.callAgent('custom', {'prompt': prompt});

    final rng = Random();
    try {
      final jsonStr = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _recommendations = (data['careers'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((c) => {
        'title': c['title'] ?? 'Career',
        'match': c['match'] ?? (65 + rng.nextInt(30)),
        'qualifications': c['qualifications'] ?? 'Bachelor\'s degree',
        'colleges': c['colleges'] ?? ['IIT', 'NIT'],
        'salary': c['salary'] ?? '5-10 LPA',
      }).toList();
    } catch (_) {
      _recommendations = [
        {'title': 'Software Engineer', 'match': 85 + rng.nextInt(10), 'qualifications': 'B.Tech CS/IT', 'colleges': ['IIT Bombay', 'NIT Trichy'], 'salary': '6-15 LPA'},
        {'title': 'Data Scientist', 'match': 75 + rng.nextInt(15), 'qualifications': 'B.Tech/BCA + Data Science', 'colleges': ['IISc Bangalore', 'IIIT Hyderabad'], 'salary': '8-20 LPA'},
        {'title': 'Product Manager', 'match': 70 + rng.nextInt(15), 'qualifications': 'MBA/B.Tech + Experience', 'colleges': ['IIM Ahmedabad', 'ISB Hyderabad'], 'salary': '12-30 LPA'},
      ];
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _saveRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Career Counselor AI', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInputSection(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || _selectedInterests.isEmpty) ? null : _getRecommendations,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Get Recommendations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          if (_recommendations.isNotEmpty) ...[
            const SizedBox(height: 24),
            ..._recommendations.asMap().entries.map((entry) => _buildCareerCard(entry.key, entry.value)),
          ],
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          const Text('Class Level', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: _classController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. 12',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              filled: true,
              fillColor: const Color(0xFF0F0F13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Interests (select at least 1)', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allInterests.map((interest) {
              final selected = _selectedInterests.contains(interest);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedInterests.remove(interest);
                    } else {
                      _selectedInterests.add(interest);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? Colors.deepPurpleAccent.withAlpha(50) : const Color(0xFF0F0F13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? Colors.deepPurpleAccent : Colors.white.withAlpha(20),
                    ),
                  ),
                  child: Text(interest, style: TextStyle(
                    color: selected ? Colors.deepPurpleAccent : Colors.white.withAlpha(150),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text('Marks (optional)', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          ..._coreSubjects.map((sub) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(sub, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
                ),
                Expanded(
                  child: TextField(
                    controller: _marksControllers[sub],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '/100',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildCareerCard(int index, Map<String, dynamic> career) {
    final match = career['match'] as int;
    final matchColor = match >= 85 ? Colors.green : match >= 70 ? Colors.amberAccent : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: matchColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(career['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: matchColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$match% Match', style: TextStyle(color: matchColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.school, 'Qualifications', career['qualifications'] ?? ''),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.account_balance, 'Top Colleges',
              (career['collegies'] as List<dynamic>?)?.join(', ') ?? ''),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.currency_rupee, 'Salary Range', career['salary'] ?? ''),
        ],
      ),
    ).animate().fade(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.1);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.deepPurpleAccent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11)),
              Text(value, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
