import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeneticLearningScreen extends StatefulWidget {
  const GeneticLearningScreen({super.key});

  @override
  State<GeneticLearningScreen> createState() => _GeneticLearningScreenState();
}

class _GeneticLearningScreenState extends State<GeneticLearningScreen> {
  final List<int?> _answers = List.filled(6, null);
  bool _showProfile = false;
  Map<String, dynamic>? _profile;
  bool _isGenerating = false;

  static const List<_Question> _questions = [
    _Question(
      'How long can you focus before needing a break?',
      ['10 min', '25 min', '45 min', '60 min'],
      Icons.timer,
    ),
    _Question(
      'What motivates you most?',
      ['Rewards', 'Curiosity', 'Competition', 'Deadlines'],
      Icons.emoji_events,
    ),
    _Question(
      'When are you most productive?',
      ['Morning', 'Afternoon', 'Evening', 'Night'],
      Icons.wb_sunny,
    ),
    _Question(
      'How do you learn best?',
      ['Reading', 'Watching', 'Doing', 'Listening'],
      Icons.menu_book,
    ),
    _Question(
      'Do you prefer familiar topics or new challenges?',
      ['Familiar', 'New', 'Balanced'],
      Icons.balance,
    ),
    _Question(
      'How do you handle distractions?',
      ['Easily distracted', 'Moderate', 'Highly focused'],
      Icons.headphones,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('genetic_profile');
    if (saved != null) {
      setState(() {
        _profile = Map<String, dynamic>.from(json.decode(saved));
        _showProfile = true;
      });
    }
  }

  Future<void> _saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('genetic_profile', json.encode(profile));
  }

  void _generateProfile() {
    if (_answers.any((a) => a == null)) return;

    setState(() => _isGenerating = true);

    final scores = _computeScores();
    final profile = {
      'comt': scores['comt'],
      'drd2': scores['drd2'],
      'bdnf': scores['bdnf'],
      'recommendations': _generateRecommendations(scores),
      'answers': _answers.toList(),
    };

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _showProfile = true;
        _isGenerating = false;
      });
      _saveProfile(profile);
    });
  }

  Map<String, dynamic> _computeScores() {
    final a = _answers;

    // COMT: Memory retention — derived from focus duration + learning style
    final focusScore = (a[0] ?? 1) * 25;
    final learningStyle = a[3] ?? 1;
    final comtScore = ((focusScore / 60) * 0.6 + (1 - learningStyle / 4) * 0.4);
    final comtLabel = comtScore > 0.7
        ? 'High — Excellent retention'
        : comtScore > 0.4
            ? 'Moderate — Average recall'
            : 'Low — Needs repetition';

    // DRD2: Motivation response — from motivation type + familiarity preference
    final motivationMap = {0: 'Reward-driven', 1: 'Curiosity-driven', 2: 'Competition-driven', 3: 'Deadline-driven'};
    final drd2Type = motivationMap[a[1]] ?? 'Balanced';
    final challengePref = a[4] ?? 1;
    final drd2Score = (a[1] ?? 0) / 3 * 0.5 + (challengePref / 2) * 0.5;

    // BDNF: Neuroplasticity — from distraction handling + learning style variety
    final distractionHandling = a[5] ?? 0;
    final bdnfScore = ((a[3] ?? 0) / 3) * 0.4 + (distractionHandling / 2) * 0.6;
    final bdnfLabel = bdnfScore > 0.6
        ? 'High — Fast adaptation'
        : bdnfScore > 0.3
            ? 'Moderate — Steady growth'
            : 'Low — Needs structured environment';

    return {
      'comt': {'score': (comtScore * 100).round(), 'label': comtLabel, 'type': 'Memory Retention'},
      'drd2': {'score': (drd2Score * 100).round(), 'label': drd2Type, 'type': 'Motivation Response'},
      'bdnf': {'score': (bdnfScore * 100).round(), 'label': bdnfLabel, 'type': 'Neuroplasticity'},
    };
  }

  Map<String, String> _generateRecommendations(Map<String, dynamic> scores) {
    final a = _answers;
    final focusMinutes = [10, 25, 45, 60][a[0] ?? 1];
    final timeOfDay = ['Morning', 'Afternoon', 'Evening', 'Night'][a[2] ?? 0];
    final learningStyle = ['Reading', 'Watching', 'Doing', 'Listening'][a[3] ?? 1];
    final motivationType = ['Rewards', 'Curiosity', 'Competition', 'Deadlines'][a[1] ?? 0];

    String rewardSchedule;
    switch (motivationType) {
      case 'Rewards':
        rewardSchedule = 'Every 15 min — small dopamine rewards';
        break;
      case 'Competition':
        rewardSchedule = 'End of session — score-based badges';
        break;
      case 'Deadlines':
        rewardSchedule = 'Milestone-based — checkpoints every 20 min';
        break;
      default:
        rewardSchedule = 'Variable interval — rewards after each subtopic';
    }

    return {
      'optimalSessionLength': '$focusMinutes minutes',
      'bestTimeOfDay': timeOfDay,
      'idealLearningStyle': learningStyle,
      'rewardSchedule': rewardSchedule,
    };
  }

  void _retakeQuiz() {
    setState(() {
      for (var i = 0; i < _answers.length; i++) _answers[i] = null;
      _showProfile = false;
      _profile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Genetic Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_showProfile)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _retakeQuiz,
              tooltip: 'Retake Questionnaire',
            ),
        ],
      ),
      body: _showProfile && _profile != null
          ? _buildProfileView()
          : _buildQuestionnaire(),
    );
  }

  Widget _buildQuestionnaire() {
    final allAnswered = _answers.every((a) => a != null);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurpleAccent.withAlpha(30),
                  Colors.teal.withAlpha(15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.deepPurpleAccent.withAlpha(50)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withAlpha(35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.biotech,
                    color: Colors.deepPurpleAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Learning DNA Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Answer 6 questions to map your genetic learning profile',
                        style: TextStyle(
                          color: Colors.white.withAlpha(130),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fade().slideY(begin: -0.08),
          const SizedBox(height: 24),
          ...List.generate(_questions.length, (index) {
            return _buildQuestionCard(index).animate().fade(
                  delay: Duration(milliseconds: 60 * index),
                  duration: 300.ms,
                );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: allAnswered && !_isGenerating ? _generateProfile : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGenerating
                    ? 'Analyzing...'
                    : 'Generate My Genetic Profile',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    final selected = _answers[index];
    final hasMoreOptions = question.options.length == 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected != null
              ? Colors.deepPurpleAccent.withAlpha(50)
              : Colors.white.withAlpha(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected != null
                      ? Colors.deepPurpleAccent.withAlpha(35)
                      : Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  question.icon,
                  color: selected != null
                      ? Colors.deepPurpleAccent
                      : Colors.white54,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Q${index + 1}',
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (selected != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Answered',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          if (hasMoreOptions)
            Row(
              children: List.generate(4, (optIndex) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: optIndex == 0 ? 0 : 6,
                      right: optIndex == 3 ? 0 : 6,
                    ),
                    child: _buildOptionChip(index, optIndex),
                  ),
                );
              }),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(3, (optIndex) {
                return _buildOptionChip(index, optIndex);
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionChip(int qIndex, int optIndex) {
    final selected = _answers[qIndex] == optIndex;
    return GestureDetector(
      onTap: () {
        setState(() => _answers[qIndex] = optIndex);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.deepPurpleAccent.withAlpha(40)
              : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.deepPurpleAccent
                : Colors.white.withAlpha(15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          _questions[qIndex].options[optIndex],
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.deepPurpleAccent : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    final comt = _profile!['comt'] as Map<String, dynamic>;
    final drd2 = _profile!['drd2'] as Map<String, dynamic>;
    final bdnf = _profile!['bdnf'] as Map<String, dynamic>;
    final recs = _profile!['recommendations'] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildGeneCard(
            'COMT',
            'Memory Retention',
            comt['score'] as int,
            comt['label'] as String,
            Icons.memory,
            Colors.deepPurpleAccent,
            0,
          ).animate().fade(delay: 100.ms).slideY(begin: 0.05),
          const SizedBox(height: 14),
          _buildGeneCard(
            'DRD2',
            'Motivation Response',
            drd2['score'] as int,
            drd2['label'] as String,
            Icons.emoji_events,
            Colors.tealAccent,
            1,
          ).animate().fade(delay: 200.ms).slideY(begin: 0.05),
          const SizedBox(height: 14),
          _buildGeneCard(
            'BDNF',
            'Neuroplasticity',
            bdnf['score'] as int,
            bdnf['label'] as String,
            Icons.psychology,
            Colors.amberAccent,
            2,
          ).animate().fade(delay: 300.ms).slideY(begin: 0.05),
          const SizedBox(height: 24),
          _buildRecommendationsCard(recs).animate().fade(delay: 400.ms).slideY(begin: 0.05),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _retakeQuiz,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake Questionnaire'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withAlpha(40)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ).animate().fade(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.withAlpha(40),
            Colors.teal.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(50)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Colors.deepPurpleAccent, Colors.teal],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withAlpha(50),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.biotech, color: Colors.white, size: 40),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          const Text(
            'Your Genetic Learning Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Based on your neural and behavioral markers',
            style: TextStyle(
              color: Colors.white.withAlpha(130),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneCard(
    String gene,
    String type,
    int score,
    String label,
    IconData icon,
    Color color,
    int index,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            gene,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type,
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: color.withAlpha(20),
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(170),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(Map<String, dynamic> recs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.withAlpha(25),
            Colors.deepPurple.withAlpha(15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.tealAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Personalized Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildRecommendationRow(
            Icons.timer,
            'Optimal Session Length',
            recs['optimalSessionLength'] ?? '',
            Colors.tealAccent,
          ),
          const SizedBox(height: 12),
          _buildRecommendationRow(
            Icons.wb_sunny,
            'Best Time of Day',
            recs['bestTimeOfDay'] ?? '',
            Colors.orangeAccent,
          ),
          const SizedBox(height: 12),
          _buildRecommendationRow(
            Icons.menu_book,
            'Ideal Learning Style',
            recs['idealLearningStyle'] ?? '',
            Colors.blueAccent,
          ),
          const SizedBox(height: 12),
          _buildRecommendationRow(
            Icons.card_giftcard,
            'Reward Schedule',
            recs['rewardSchedule'] ?? '',
            Colors.pinkAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationRow(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(130),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Question {
  final String text;
  final List<String> options;
  final IconData icon;

  const _Question(this.text, this.options, this.icon);
}
