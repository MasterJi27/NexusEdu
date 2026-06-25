import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CollegeAppWriterScreen extends StatefulWidget {
  const CollegeAppWriterScreen({super.key});

  @override
  State<CollegeAppWriterScreen> createState() => _CollegeAppWriterScreenState();
}

class _CollegeAppWriterScreenState extends State<CollegeAppWriterScreen> {
  String _selectedCollegeType = 'IIT';
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _activitiesController = TextEditingController();
  final TextEditingController _achievementsController = TextEditingController();
  bool _isLoading = false;
  bool _generated = false;
  bool _generatingLetter = false;

  String _sop = '';
  String _recommendationLetter = '';
  List<Map<String, dynamic>> _pastApps = [];

  final List<String> _collegeTypes = ['IIT', 'NIT', 'IIIT', 'DU', 'State'];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _marksController.dispose();
    _activitiesController.dispose();
    _achievementsController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('college_apps') ?? [];
    setState(() {
      _pastApps = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveApp() async {
    final prefs = await SharedPreferences.getInstance();
    final apps = prefs.getStringList('college_apps') ?? [];
    apps.add(json.encode({
      'collegeType': _selectedCollegeType,
      'marks': _marksController.text.trim(),
      'activities': _activitiesController.text.trim(),
      'achievements': _achievementsController.text.trim(),
      'sop': _sop,
      'recommendationLetter': _recommendationLetter,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (apps.length > 20) apps.removeAt(0);
    await prefs.setStringList('college_apps', apps);
    _loadApps();
  }

  Future<void> _generateSOP() async {
    if (_marksController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _generated = false;
    });

    final marks = _marksController.text.trim();
    final activities = _activitiesController.text.trim();
    final achievements = _achievementsController.text.trim();

    try {
      _sop = await AiAgentService.callAgent(
        'custom',
        {
          'prompt':
              'Write a Statement of Purpose for $_selectedCollegeType admission.\n'
              'Academic marks: $marks\n'
              'Activities: $activities\n'
              'Achievements: $achievements\n\n'
              'Write a compelling, personal SOP in 300-400 words. '
              'Include: introduction, academic background, extracurriculars, '
              'why this college, future goals, and conclusion.',
        },
      );
    } catch (_) {
      _sop = 'Dear Admissions Committee,\n\n'
          'I am writing to express my interest in joining $_selectedCollegeType. '
          'With strong academic background and diverse activities, '
          'I am committed to contributing to the academic community.\n\n'
          'Thank you for considering my application.';
    }

    setState(() {
      _isLoading = false;
      _generated = true;
    });

    _saveApp();
  }

  Future<void> _generateRecommendationLetter() async {
    setState(() => _generatingLetter = true);

    try {
      _recommendationLetter = await AiAgentService.callAgent(
        'custom',
        {
          'prompt':
              'Write a recommendation letter for a student applying to $_selectedCollegeType.\n'
              'Marks: ${_marksController.text.trim()}\n'
              'Activities: ${_activitiesController.text.trim()}\n'
              'Achievements: ${_achievementsController.text.trim()}\n\n'
              'Write from the perspective of a teacher. Keep it professional and supportive.',
        },
      );
    } catch (_) {
      _recommendationLetter = 'To whom it may concern,\n\n'
          'I am pleased to recommend this student for $_selectedCollegeType. '
          'They have demonstrated excellent academic potential.';
    }

    setState(() => _generatingLetter = false);
    _saveApp();
  }

  void _resetWriter() {
    setState(() {
      _generated = false;
      _sop = '';
      _recommendationLetter = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'College Application Writer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_generated)
            IconButton(
              onPressed: _resetWriter,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _generated ? _buildResultView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Craft Your Application',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate SOP and recommendation letters for college applications.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildCollegeTypeSelector(),
          const SizedBox(height: 16),
          _buildInputField('Academic Marks', _marksController,
              'e.g., 95% in 12th, JEE Rank 1500'),
          const SizedBox(height: 12),
          _buildInputField('Activities & Sports', _activitiesController,
              'e.g., Robotics club, Cricket captain'),
          const SizedBox(height: 12),
          _buildInputField('Achievements', _achievementsController,
              'e.g., State science olympiad winner'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading || _marksController.text.trim().isEmpty
                  ? null
                  : _generateSOP,
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
                _isLoading ? 'Generating SOP...' : 'Generate SOP',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastApps.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Applications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_pastApps.length.clamp(0, 5), (i) {
              final a = _pastApps[i];
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
                      child: const Icon(Icons.school,
                          color: Colors.deepPurpleAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['collegeType'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'SOP + ${a['recommendationLetter'].toString().isNotEmpty ? 'Letter' : 'No letter'}',
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

  Widget _buildCollegeTypeSelector() {
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
            'Target College Type',
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
            children: _collegeTypes.map((t) {
              final isSelected = t == _selectedCollegeType;
              return GestureDetector(
                onTap: () => setState(() => _selectedCollegeType = t),
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
                    t,
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

  Widget _buildInputField(
      String label, TextEditingController controller, String hint) {
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
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    ).animate().fade();
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
                const Icon(Icons.school,
                    color: Colors.deepPurpleAccent, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Statement of Purpose - $_selectedCollegeType',
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
            ),
            child: Text(
              _sop,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ).animate().fade().slideY(begin: 0.05),
          const SizedBox(height: 16),
          if (_recommendationLetter.isEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generatingLetter ? null : _generateRecommendationLetter,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.tealAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _generatingLetter
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.tealAccent),
                      )
                    : const Icon(Icons.person_add, color: Colors.tealAccent),
                label: const Text(
                  'Generate Recommendation Letter',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_recommendationLetter.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
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
                      Icon(Icons.person_add,
                          color: Colors.tealAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Recommendation Letter',
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
                    _recommendationLetter,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: 0.05),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetWriter,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'New Application',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
