import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerformanceTestScreen extends StatefulWidget {
  const PerformanceTestScreen({super.key});

  @override
  State<PerformanceTestScreen> createState() => _PerformanceTestScreenState();
}

class _PerformanceTestScreenState extends State<PerformanceTestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _testResults = [];
  String _selectedSubject = 'All';
  String _selectedFilter = 'All';
  int _selectedExpandedIndex = -1;
  String _aiRecommendation = '';
  bool _isAiLoading = false;

  static const Color _bgColor = Color(0xFF0F0F13);
  static const Color _cardColor = Color(0xFF1E1E1E);
  static const Color _accent = Colors.deepPurpleAccent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadResults();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('self_test_results') ?? [];
    setState(() {
      _testResults = raw
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
      _testResults.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      _isLoading = false;
    });
    _fetchAiRecommendation();
  }

  Map<String, dynamic> _calculateOverallStats() {
    if (_testResults.isEmpty) {
      return {
        'totalTests': 0,
        'avgScore': 0.0,
        'bestScore': 0.0,
        'streak': 0,
      };
    }
    double totalScore = 0;
    double bestScore = 0;
    for (final r in _testResults) {
      final score = (r['score'] as num?)?.toDouble() ?? 0;
      totalScore += score;
      if (score > bestScore) bestScore = score;
    }
    final avgScore = totalScore / _testResults.length;

    int streak = 0;
    final now = DateTime.now();
    DateTime currentDay = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < 365; i++) {
      final checkDay = currentDay.subtract(Duration(days: i));
      final hasTest = _testResults.any((r) {
        final d = DateTime.tryParse(r['date'] ?? '');
        if (d == null) return false;
        return DateTime(d.year, d.month, d.day) == checkDay;
      });
      if (hasTest) {
        streak++;
      } else {
        break;
      }
    }

    return {
      'totalTests': _testResults.length,
      'avgScore': avgScore,
      'bestScore': bestScore,
      'streak': streak,
    };
  }

  Map<String, dynamic> _getSubjectStats(String subject) {
    final filtered = subject == 'All'
        ? _testResults
        : _testResults.where((r) => r['subject'] == subject).toList();
    if (filtered.isEmpty) {
      return {
        'avg': 0.0,
        'best': 0.0,
        'total': 0,
        'chapters': <String, Map<String, dynamic>>{},
        'questionsAttempted': 0,
      };
    }

    double totalScore = 0;
    double bestScore = 0;
    int questionsAttempted = 0;
    final Map<String, List<double>> chapterScores = {};

    for (final r in filtered) {
      final score = (r['score'] as num?)?.toDouble() ?? 0;
      totalScore += score;
      if (score > bestScore) bestScore = score;
      final chapter = r['chapter'] ?? 'Unknown';
      chapterScores.putIfAbsent(chapter, () => []).add(score);
      questionsAttempted += (r['totalQuestions'] as int?) ?? 0;
    }

    final Map<String, Map<String, dynamic>> chapters = {};
    for (final entry in chapterScores.entries) {
      final scores = entry.value;
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      final best = scores.reduce((a, b) => a > b ? a : b);
      chapters[entry.key] = {
        'avg': avg,
        'best': best,
        'attempts': scores.length,
      };
    }

    return {
      'avg': totalScore / filtered.length,
      'best': bestScore,
      'total': filtered.length,
      'chapters': chapters,
      'questionsAttempted': questionsAttempted,
    };
  }

  List<Map<String, dynamic>> _getWeakTopics() {
    final Map<String, List<double>> chapterScores = {};
    for (final r in _testResults) {
      final chapter = r['chapter'] ?? 'Unknown';
      final score = (r['score'] as num?)?.toDouble() ?? 0;
      chapterScores.putIfAbsent(chapter, () => []).add(score);
    }
    final List<Map<String, dynamic>> weak = [];
    for (final entry in chapterScores.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (avg < 60) {
        weak.add({
          'chapter': entry.key,
          'avgScore': avg,
        });
      }
    }
    weak.sort((a, b) => (a['avgScore'] as double).compareTo(b['avgScore'] as double));
    return weak;
  }

  List<Map<String, dynamic>> _getStrongTopics() {
    final Map<String, List<double>> chapterScores = {};
    for (final r in _testResults) {
      final chapter = r['chapter'] ?? 'Unknown';
      final score = (r['score'] as num?)?.toDouble() ?? 0;
      chapterScores.putIfAbsent(chapter, () => []).add(score);
    }
    final List<Map<String, dynamic>> strong = [];
    for (final entry in chapterScores.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (avg > 80) {
        strong.add({
          'chapter': entry.key,
          'avgScore': avg,
        });
      }
    }
    return strong;
  }

  Map<String, dynamic> _getAccuracyTrend(String subject) {
    final filtered = subject == 'All'
        ? _testResults
        : _testResults.where((r) => r['subject'] == subject).toList();
    final List<double> scores = [];
    final List<String> dates = [];
    for (final r in filtered.takeLast(20)) {
      scores.add((r['score'] as num?)?.toDouble() ?? 0);
      dates.add(r['date'] ?? '');
    }
    return {'scores': scores, 'dates': dates};
  }

  Map<String, dynamic> _getAchievements() {
    final stats = _calculateOverallStats();
    final hasFirstTest = stats['totalTests'] >= 1;
    final hasPerfect = _testResults.any((r) => (r['score'] as num?)?.toDouble() == 100);
    final has7DayStreak = stats['streak'] >= 7;

    double firstScore = 0;
    double lastScore = 0;
    if (_testResults.length >= 2) {
      final sorted = List<Map<String, dynamic>>.from(_testResults);
      sorted.sort((a, b) {
        final dA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final dB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dA.compareTo(dB);
      });
      firstScore = (sorted.first['score'] as num?)?.toDouble() ?? 0;
      lastScore = (sorted.last['score'] as num?)?.toDouble() ?? 0;
    }
    final hasImprover = (lastScore - firstScore) >= 20;

    final strongChapters = _getStrongTopics();
    final hasChapterMaster = strongChapters.length >= 5;

    return {
      'First Test': hasFirstTest,
      'Perfect Score': hasPerfect,
      '7-Day Streak': has7DayStreak,
      'Improver': hasImprover,
      'Chapter Master': hasChapterMaster,
    };
  }

  List<Map<String, dynamic>> _getFilteredTests() {
    List<Map<String, dynamic>> filtered = List.from(_testResults);
    if (_selectedSubject != 'All') {
      filtered = filtered.where((r) => r['subject'] == _selectedSubject).toList();
    }
    if (_selectedFilter == 'This Week') {
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));
      filtered = filtered.where((r) {
        final d = DateTime.tryParse(r['date'] ?? '');
        return d != null && d.isAfter(weekAgo);
      }).toList();
    } else if (_selectedFilter == 'This Month') {
      final now = DateTime.now();
      final monthAgo = DateTime(now.year, now.month - 1, now.day);
      filtered = filtered.where((r) {
        final d = DateTime.tryParse(r['date'] ?? '');
        return d != null && d.isAfter(monthAgo);
      }).toList();
    }
    return filtered;
  }

  List<String> _getSubjects() {
    final subjects = _testResults.map((r) => r['subject'] as String? ?? '').toSet().toList();
    subjects.removeWhere((s) => s.isEmpty);
    return ['All', ...subjects];
  }

  Future<void> _fetchAiRecommendation() async {
    if (_testResults.isEmpty) return;
    setState(() => _isAiLoading = true);
    try {
      final weakTopics = _getWeakTopics();
      final strongTopics = _getStrongTopics();
      final stats = _calculateOverallStats();
      final prompt = "Student performance data: "
          "Average score: ${stats['avgScore'].toStringAsFixed(1)}%, "
          "Tests taken: ${stats['totalTests']}, "
          "Weak topics: ${weakTopics.map((t) => '${t['chapter']} (${t['avgScore'].toStringAsFixed(0)}%)').join(', ')}, "
          "Strong topics: ${strongTopics.map((t) => t['chapter']).join(', ')}. "
          "Give 3 specific study recommendations in 2-3 sentences.";
      final response = await _callAiService(prompt);
      if (mounted) {
        setState(() {
          _aiRecommendation = response;
          _isAiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiRecommendation = 'Focus on revising your weak topics regularly.';
          _isAiLoading = false;
        });
      }
    }
  }

  Future<String> _callAiService(String prompt) async {
    try {
      return await AiService.sendMessageToTutor(prompt);
    } catch (_) {
      return 'Based on your performance, focus on improving your weak areas and practice regularly.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined, color: _accent, size: 24),
            SizedBox(width: 8),
            Text(
              'Performance Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tests'),
            Tab(text: 'Subjects'),
            Tab(text: 'Improvement'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _testResults.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildTestsTab(),
                    _buildSubjectsTab(),
                    _buildImprovementTab(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'No tests taken yet!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a test to see your performance.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildOverviewTab() {
    final stats = _calculateOverallStats();
    final weakTopics = _getWeakTopics();
    final recentTests = _testResults.take(10).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCardsRow(stats),
          const SizedBox(height: 20),
          _buildSectionTitle('Recent Tests'),
          const SizedBox(height: 8),
          ...recentTests.map((r) => _buildRecentTestCard(r)),
          const SizedBox(height: 20),
          _buildSectionTitle('Subject Performance'),
          const SizedBox(height: 8),
          _buildSubjectPerformanceBars(),
          if (weakTopics.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionTitle('Weak Topics'),
            const SizedBox(height: 8),
            ...weakTopics.map((t) => _buildWeakTopicCard(t)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCardsRow(Map<String, dynamic> stats) {
    final cards = [
      {'label': 'Total Tests', 'value': '${stats['totalTests']}', 'icon': Icons.assignment},
      {'label': 'Avg Score', 'value': '${(stats['avgScore'] as double).toStringAsFixed(1)}%', 'icon': Icons.trending_up},
      {'label': 'Best Score', 'value': '${(stats['bestScore'] as double).toStringAsFixed(1)}%', 'icon': Icons.emoji_events},
      {'label': 'Streak', 'value': '${stats['streak']} days', 'icon': Icons.local_fire_department},
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final card = cards[index];
          return Container(
            width: 140,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(card['icon'] as IconData, color: _accent, size: 22),
                const SizedBox(height: 8),
                Text(
                  card['value'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card['label'] as String,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (100 * index).ms, duration: 400.ms);
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRecentTestCard(Map<String, dynamic> result) {
    final subject = result['subject'] ?? 'Unknown';
    final chapter = result['chapter'] ?? '';
    final score = (result['score'] as num?)?.toDouble() ?? 0;
    final date = result['date'] ?? '';

    Color badgeColor;
    if (score > 80) {
      badgeColor = Colors.green;
    } else if (score >= 60) {
      badgeColor = Colors.amber;
    } else {
      badgeColor = Colors.red;
    }

    IconData subjectIcon;
    switch (subject.toLowerCase()) {
      case 'physics':
        subjectIcon = Icons.science;
        break;
      case 'chemistry':
        subjectIcon = Icons.bubble_chart;
        break;
      case 'maths':
      case 'math':
        subjectIcon = Icons.calculate;
        break;
      case 'biology':
        subjectIcon = Icons.biotech;
        break;
      default:
        subjectIcon = Icons.book;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(subjectIcon, color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (chapter.isNotEmpty)
                  Text(
                    chapter,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSubjectPerformanceBars() {
    final subjects = _getSubjects().where((s) => s != 'All').toList();
    if (subjects.isEmpty) return const SizedBox.shrink();

    return Column(
      children: subjects.map((subject) {
        final stats = _getSubjectStats(subject);
        final avg = stats['avg'] as double;
        Color barColor;
        if (avg > 80) {
          barColor = Colors.green;
        } else if (avg >= 60) {
          barColor = Colors.amber;
        } else {
          barColor = Colors.red;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subject,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${avg.toStringAsFixed(1)}%',
                    style: TextStyle(color: barColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: avg / 100,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms);
      }).toList(),
    );
  }

  Widget _buildWeakTopicCard(Map<String, dynamic> topic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic['chapter'] as String,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Avg: ${(topic['avgScore'] as double).toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _SmartRevisionPlaceholder(chapter: topic['chapter'] as String),
                ),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Revise', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildTestsTab() {
    final filtered = _getFilteredTests();
    final filters = ['All', 'Chapter', 'Syllabus', 'This Week', 'This Month'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final f = filters[index];
                final isSelected = _selectedFilter == f;
                return ChoiceChip(
                  label: Text(f, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey)),
                  selected: isSelected,
                  selectedColor: _accent,
                  backgroundColor: _cardColor,
                  onSelected: (selected) {
                    setState(() => _selectedFilter = f);
                  },
                );
              },
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No tests found for this filter.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    return _buildTestHistoryCard(r, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTestHistoryCard(Map<String, dynamic> result, int index) {
    final isExpanded = _selectedExpandedIndex == index;
    final subject = result['subject'] ?? 'Unknown';
    final chapter = result['chapter'] ?? '';
    final score = (result['score'] as num?)?.toDouble() ?? 0;
    final accuracy = (result['accuracy'] as num?)?.toDouble() ?? score;
    final date = result['date'] ?? '';
    final type = result['type'] ?? 'Chapter';
    final timeTaken = result['timeTaken'] ?? '';
    final questions = result['questions'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _selectedExpandedIndex = isExpanded ? -1 : index;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(date),
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$subject - $chapter',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          type,
                          style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildMiniStat('Score', '${score.toStringAsFixed(0)}%'),
                      const SizedBox(width: 16),
                      _buildMiniStat('Accuracy', '${accuracy.toStringAsFixed(0)}%'),
                      if (timeTaken.toString().isNotEmpty) ...[
                        const SizedBox(width: 16),
                        _buildMiniStat('Time', '$timeTaken'),
                      ],
                      const Spacer(),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && questions.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.grey, height: 1),
                  const SizedBox(height: 10),
                  Text(
                    'Question Breakdown',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...questions.asMap().entries.map((entry) {
                    final qi = entry.key;
                    final q = Map<String, dynamic>.from(entry.value);
                    final isCorrect = q['isCorrect'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151518),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Q${qi + 1}. ',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                              Expanded(
                                child: Text(
                                  q['question'] ?? '',
                                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                                ),
                              ),
                              Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green : Colors.red,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Your answer: ',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                              Text(
                                q['userAnswer'] ?? 'N/A',
                                style: TextStyle(
                                  color: isCorrect ? Colors.green : Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (!isCorrect && q['correctAnswer'] != null)
                            Row(
                              children: [
                                Text(
                                  'Correct: ',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                ),
                                Text(
                                  q['correctAnswer'] ?? '',
                                  style: const TextStyle(color: Colors.green, fontSize: 11),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: (50 * index).ms, duration: 300.ms);
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _buildSubjectsTab() {
    final subjects = _getSubjects();
    if (!_getSubjects().contains(_selectedSubject)) {
      _selectedSubject = subjects.first;
    }

    final subjectStats = _getSubjectStats(_selectedSubject);
    final chapters = subjectStats['chapters'] as Map<String, Map<String, dynamic>>;
    final avg = subjectStats['avg'] as double;
    final totalQ = subjectStats['questionsAttempted'] as int;
    final accuracyTrend = _getAccuracyTrend(_selectedSubject);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final s = subjects[index];
                final isSelected = _selectedSubject == s;
                return ChoiceChip(
                  label: Text(s, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey)),
                  selected: isSelected,
                  selectedColor: _accent,
                  backgroundColor: _cardColor,
                  onSelected: (selected) {
                    setState(() => _selectedSubject = s);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCircularProgress(avg),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Score',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    Text(
                      '${avg.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalQ questions attempted',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Accuracy Trend'),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: _PerformanceLinePainter(
                scores: accuracyTrend['scores'] ?? [],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Chapter Breakdown'),
          const SizedBox(height: 8),
          ...chapters.entries.map((entry) {
            final chapterAvg = entry.value['avg'] as double;
            final chapterBest = entry.value['best'] as double;
            final attempts = entry.value['attempts'] as int;
            Color barColor;
            if (chapterAvg > 80) {
              barColor = Colors.green;
            } else if (chapterAvg >= 60) {
              barColor = Colors.amber;
            } else {
              barColor = Colors.red;
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      Text(
                        '${attempts} attempts',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Avg: ${chapterAvg.toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      const SizedBox(width: 12),
                      Text('Best: ${chapterBest.toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: chapterAvg / 100,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation(barColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms);
          }),
          if (_getStrongTopics().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('Strong Chapters'),
            const SizedBox(height: 8),
            ..._getStrongTopics().map((t) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t['chapter'] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  Text(
                    '${(t['avgScore'] as double).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
          ],
          if (_getWeakTopics().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('Weak Chapters'),
            const SizedBox(height: 8),
            ..._getWeakTopics().map((t) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t['chapter'] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  Text(
                    '${(t['avgScore'] as double).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _SmartRevisionPlaceholder(chapter: t['chapter'] as String),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Practice', style: TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildImprovementTab() {
    final last10 = _testResults.take(10).toList().reversed.toList();
    final scores = last10.map((r) => (r['score'] as num?)?.toDouble() ?? 0).toList();
    final achievements = _getAchievements();

    double predictedScore = 50;
    if (scores.length >= 2) {
      final trend = (scores.last - scores.first) / scores.length;
      predictedScore = scores.last + trend;
      if (predictedScore > 100) predictedScore = 100;
      if (predictedScore < 0) predictedScore = 0;
    }

    String trendMessage;
    if (scores.length < 2) {
      trendMessage = 'Take more tests to see your trend.';
    } else if (scores.last > scores.first) {
      trendMessage = 'Keep going! You are improving.';
    } else {
      trendMessage = 'Focus on weak areas to improve.';
    }

    final achievementList = [
      {'name': 'First Test', 'icon': Icons.star, 'earned': achievements['First Test'] ?? false},
      {'name': 'Perfect Score', 'icon': Icons.workspace_premium, 'earned': achievements['Perfect Score'] ?? false},
      {'name': '7-Day Streak', 'icon': Icons.local_fire_department, 'earned': achievements['7-Day Streak'] ?? false},
      {'name': 'Improver', 'icon': Icons.trending_up, 'earned': achievements['Improver'] ?? false},
      {'name': 'Chapter Master', 'icon': Icons.school, 'earned': achievements['Chapter Master'] ?? false},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Performance Trend'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _PerformanceLinePainter(
                  scores: scores,
                  showLabels: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent.withOpacity(0.3), _accent.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: _accent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Predicted Next Score',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${predictedScore.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  trendMessage,
                  style: TextStyle(
                    color: trendMessage.contains('improving') ? Colors.greenAccent : Colors.amber,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          _buildSectionTitle('Study Recommendations'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _isAiLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
                    ),
                  )
                : Text(
                    _aiRecommendation.isNotEmpty
                        ? _aiRecommendation
                        : 'Based on your performance, focus on: ${_getWeakTopics().take(3).map((t) => t['chapter']).join(', ')}.',
                    style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.5),
                  ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Achievements'),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: achievementList.length,
            itemBuilder: (context, index) {
              final a = achievementList[index];
              final earned = a['earned'] as bool;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: earned ? _accent.withOpacity(0.15) : _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: earned ? _accent.withOpacity(0.5) : Colors.grey[800]!,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      a['icon'] as IconData,
                      color: earned ? _accent : Colors.grey[700],
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a['name'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: earned ? Colors.white : Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (100 * index).ms, duration: 300.ms);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(double percentage) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 8,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(
                percentage > 80
                    ? Colors.green
                    : percentage >= 60
                        ? Colors.amber
                        : Colors.red,
              ),
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _PerformanceLinePainter extends CustomPainter {
  final List<double> scores;
  final bool showLabels;

  _PerformanceLinePainter({required this.scores, this.showLabels = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final paint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 0.5;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final padding = showLabels ? 30.0 : 10.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    for (int i = 0; i <= 4; i++) {
      final y = padding + (chartHeight / 4) * i;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    final maxScore = 100.0;
    final minScore = 0.0;
    final step = chartWidth / (scores.length > 1 ? scores.length - 1 : 1);

    final path = Path();
    for (int i = 0; i < scores.length; i++) {
      final x = padding + step * i;
      final normalizedScore = (scores[i] - minScore) / (maxScore - minScore);
      final y = padding + chartHeight * (1 - normalizedScore);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);

      if (showLabels && i == scores.length - 1) {
        textPainter.text = TextSpan(
          text: '${scores[i].toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.deepPurpleAccent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 18));
      }
    }

    canvas.drawPath(path, paint);

    if (showLabels) {
      textPainter.text = TextSpan(
        text: '100%',
        style: TextStyle(color: Colors.grey[600], fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, padding - 6));

      textPainter.text = TextSpan(
        text: '0%',
        style: TextStyle(color: Colors.grey[600], fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, size.height - padding - 6));

      if (scores.length > 1) {
        textPainter.text = TextSpan(
          text: '${scores.length} tests',
          style: TextStyle(color: Colors.grey[600], fontSize: 9),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(size.width / 2 - textPainter.width / 2, size.height - 6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PerformanceLinePainter oldDelegate) {
    return oldDelegate.scores != scores;
  }
}

extension _ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) return this;
    return sublist(length - count);
  }
}

class _SmartRevisionPlaceholder extends StatelessWidget {
  final String chapter;
  const _SmartRevisionPlaceholder({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: Text('Revise: $chapter', style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.replay, size: 60, color: Colors.deepPurpleAccent),
            const SizedBox(height: 16),
            Text(
              'Smart Revision for $chapter',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Navigate to Smart Revision to start revising.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
