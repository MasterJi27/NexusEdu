import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectGuideScreen extends StatefulWidget {
  const ProjectGuideScreen({super.key});

  @override
  State<ProjectGuideScreen> createState() => _ProjectGuideScreenState();
}

class _ProjectGuideScreenState extends State<ProjectGuideScreen> {
  String _selectedType = 'Science Fair';
  String _selectedSubject = 'Physics';
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  bool _isLoading = false;
  bool _planGenerated = false;

  String _projectPlan = '';
  String _resources = '';
  String _progressUpdate = '';
  List<Map<String, dynamic>> _pastPlans = [];

  final List<String> _projectTypes = [
    'Science Fair',
    'Assignment',
    'Research Paper',
  ];
  final List<String> _subjects = [
    'Physics',
    'Chemistry',
    'Biology',
    'Mathematics',
    'Computer Science',
    'History',
    'Geography',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _deadlineController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('project_plans') ?? [];
    setState(() {
      _pastPlans = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _savePlan() async {
    final prefs = await SharedPreferences.getInstance();
    final plans = prefs.getStringList('project_plans') ?? [];
    plans.add(json.encode({
      'type': _selectedType,
      'subject': _selectedSubject,
      'topic': _topicController.text.trim(),
      'deadline': _deadlineController.text.trim(),
      'plan': _projectPlan,
      'resources': _resources,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (plans.length > 20) plans.removeAt(0);
    await prefs.setStringList('project_plans', plans);
    _loadPlans();
  }

  Future<void> _generatePlan() async {
    final topic = _topicController.text.trim();
    final deadline = _deadlineController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _isLoading = true;
      _planGenerated = false;
    });

    try {
      final result = await AiAgentService.callAgent(
        'custom',
        {
          'prompt':
              'Create a $_selectedType project plan for $_selectedSubject on "$topic". '
              'Deadline: ${deadline.isNotEmpty ? deadline : "flexible"}. '
              'Include step-by-step plan with timeline, resources needed, and tips.',
        },
      );
      _parsePlan(result);
    } catch (_) {
      _projectPlan = 'Phase 1: Research (Days 1-3)\n'
          '- Gather information\n'
          '- Review literature\n\n'
          'Phase 2: Execution (Days 4-7)\n'
          '- Conduct experiments\n'
          '- Collect data\n\n'
          'Phase 3: Documentation (Days 8-9)\n'
          '- Write report\n'
          '- Create visuals\n\n'
          'Phase 4: Presentation (Day 10)\n'
          '- Prepare presentation\n';
      _resources = '- Textbook references\n- Internet access\n'
          '- Stationery materials\n- Lab equipment (if applicable)';
    }

    setState(() {
      _isLoading = false;
      _planGenerated = true;
    });

    _savePlan();
  }

  void _parsePlan(String response) {
    _projectPlan = _extractSection(response, 'PLAN:');
    _resources = _extractSection(response, 'RESOURCES:');

    if (_projectPlan.isEmpty) {
      _projectPlan = response;
      _resources = '';
    }
  }

  String _extractSection(String text, String header) {
    final idx = text.indexOf(header);
    if (idx == -1) return '';
    final start = idx + header.length;
    final sections = ['PLAN:', 'RESOURCES:'];
    int end = text.length;
    for (final s in sections) {
      if (s == header) continue;
      final sIdx = text.indexOf(s, start);
      if (sIdx != -1 && sIdx < end) end = sIdx;
    }
    return text.substring(start, end).trim();
  }

  Future<void> _checkProgress() async {
    setState(() => _isLoading = true);

    try {
      _progressUpdate = await AiAgentService.callAgent(
        'custom',
        {
          'prompt':
              'A student is working on a $_selectedType project about '
              '${_topicController.text.trim()} in $_selectedSubject. '
              'Give a brief motivational progress check and one tip to stay on track. '
              'Keep it under 50 words.',
        },
      );
    } catch (_) {
      _progressUpdate = 'Keep up the good progress! Stay focused on your deadlines.';
    }

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_progressUpdate),
          backgroundColor: Colors.deepPurpleAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _resetGuide() {
    setState(() {
      _planGenerated = false;
      _projectPlan = '';
      _resources = '';
      _progressUpdate = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Project Guide Agent',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_planGenerated)
            IconButton(
              onPressed: _resetGuide,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _planGenerated ? _buildPlanView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.assignment,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Plan Your Project',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get a step-by-step project plan with deadlines and resources.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildTypeSelector(),
          const SizedBox(height: 16),
          _buildSubjectSelector(),
          const SizedBox(height: 16),
          _buildTextField('Project Topic', _topicController,
              'e.g., Solar Energy Systems'),
          const SizedBox(height: 12),
          _buildTextField('Deadline (optional)', _deadlineController,
              'e.g., 2 weeks, January 15'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading || _topicController.text.trim().isEmpty
                  ? null
                  : _generatePlan,
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
                _isLoading ? 'Generating Plan...' : 'Generate Plan',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastPlans.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Projects',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_pastPlans.length.clamp(0, 5), (i) {
              final p = _pastPlans[i];
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
                      child: const Icon(Icons.assignment,
                          color: Colors.deepPurpleAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['topic'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${p['type']} • ${p['subject']}',
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

  Widget _buildTypeSelector() {
    return _buildChipSelector(
      'Project Type',
      _projectTypes,
      _selectedType,
      (val) => setState(() => _selectedType = val!),
    );
  }

  Widget _buildSubjectSelector() {
    return _buildChipSelector(
      'Subject',
      _subjects,
      _selectedSubject,
      (val) => setState(() => _selectedSubject = val!),
    );
  }

  Widget _buildChipSelector(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onChanged(opt),
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
                    opt,
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

  Widget _buildTextField(
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

  Widget _buildPlanView() {
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
                const Icon(Icons.assignment,
                    color: Colors.deepPurpleAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _topicController.text.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$_selectedType • $_selectedSubject',
                        style: TextStyle(
                          color: Colors.white.withAlpha(120),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_projectPlan.isNotEmpty)
            _buildContentCard(
              'Project Plan',
              _projectPlan,
              Icons.map,
              Colors.deepPurpleAccent,
            ),
          if (_resources.isNotEmpty)
            _buildContentCard(
              'Resources Needed',
              _resources,
              Icons.inventory_2,
              Colors.tealAccent,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _checkProgress,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.deepPurpleAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.deepPurpleAccent),
                    )
                  : const Icon(Icons.trending_up,
                      color: Colors.deepPurpleAccent),
              label: const Text(
                'Check Progress',
                style: TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                'New Project',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(
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
