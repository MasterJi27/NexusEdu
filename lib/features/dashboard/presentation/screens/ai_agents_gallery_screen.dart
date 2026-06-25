import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class AiAgentsGalleryScreen extends StatelessWidget {
  const AiAgentsGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      {
        'title': 'AI Tutor Agents',
        'color': Colors.purpleAccent,
        'features': [
          {'icon': Icons.question_answer, 'title': 'Socratic AI', 'route': '/socratic-ai', 'desc': 'Never gives answers — only asks questions'},
          {'icon': Icons.record_voice_over, 'title': 'Debate Agent', 'route': '/debate-agent', 'desc': 'AI argues the opposite side'},
          {'icon': Icons.analytics, 'title': 'Exam Predictor', 'route': '/exam-predictor', 'desc': 'Predicts 90% of exam questions'},
          {'icon': Icons.person, 'title': 'Personalized Tutor', 'route': '/personalized-tutor', 'desc': 'Adapts to your learning style'},
          {'icon': Icons.translate, 'title': 'Multi-Language', 'route': '/multi-lang-tutor', 'desc': 'Hindi/English/Tamil/Telugu/Bengali'},
          {'icon': Icons.psychology, 'title': 'Exam Strategy', 'route': '/exam-strategy', 'desc': 'Max marks in min time'},
          {'icon': Icons.spa, 'title': 'Anxiety Coach', 'route': '/anxiety-coach', 'desc': 'Breathing exercises + calm tips'},
          {'icon': Icons.check_circle, 'title': 'Accountability', 'route': '/accountability-agent', 'desc': 'Tracks your daily study'},
          {'icon': Icons.work, 'title': 'Career Counselor', 'route': '/career-counselor', 'desc': 'Career & college suggestions'},
          {'icon': Icons.family_restroom, 'title': 'Parent Report', 'route': '/parent-report', 'desc': 'Weekly progress reports'},
        ],
      },
      {
        'title': 'Content Generation',
        'color': Colors.tealAccent,
        'features': [
          {'icon': Icons.menu_book, 'title': 'AI Textbook', 'route': '/ai-textbook', 'desc': 'Generates complete chapters'},
          {'icon': Icons.assignment, 'title': 'Question Paper', 'route': '/question-paper-gen', 'desc': 'Creates exam papers with blueprint'},
          {'icon': Icons.science, 'title': 'Lab Manual', 'route': '/lab-manual-gen', 'desc': 'Full experiment writeups'},
          {'icon': Icons.auto_stories, 'title': 'Story Learning', 'route': '/story-learning', 'desc': 'Converts chapters to stories'},
          {'icon': Icons.lightbulb, 'title': 'Mnemonics', 'route': '/mnemonic-gen', 'desc': 'Memory tricks for formulas'},
          {'icon': Icons.headphones, 'title': 'Audio Notes', 'route': '/audio-notes', 'desc': 'AI reads notes aloud'},
          {'icon': Icons.videocam, 'title': 'Video Script', 'route': '/video-script', 'desc': 'YouTube-ready scripts'},
          {'icon': Icons.description, 'title': 'Cheat Sheet', 'route': '/cheat-sheet-gen', 'desc': '1-page revision sheets'},
          {'icon': Icons.account_tree, 'title': 'Mind Map', 'route': '/mind-map-gen', 'desc': 'Visual topic relationships'},
          {'icon': Icons.style, 'title': 'Auto Flashcards', 'route': '/flashcard-auto-gen', 'desc': 'Auto-generates flashcards'},
        ],
      },
      {
        'title': 'Assessment',
        'color': Colors.orangeAccent,
        'features': [
          {'icon': Icons.trending_up, 'title': 'Adaptive Quiz', 'route': '/adaptive-quiz', 'desc': 'Difficulty adapts to you'},
          {'icon': Icons.mic, 'title': 'Voice Viva', 'route': '/voice-viva', 'desc': 'Oral exam practice'},
          {'icon': Icons.rate_review, 'title': 'Essay Evaluator', 'route': '/essay-evaluator', 'desc': 'Rates essays 0-100'},
          {'icon': Icons.speed, 'title': 'Speed Math', 'route': '/speed-math', 'desc': '60s math challenges'},
          {'icon': Icons.draw, 'title': 'Diagram Practice', 'route': '/diagram-practice', 'desc': 'Check diagram accuracy'},
          {'icon': Icons.zoom_out_map, 'title': 'Concept Gap', 'route': '/concept-gap-detector', 'desc': 'Finds missing prerequisites'},
          {'icon': Icons.equalizer, 'title': 'Peer Comparison', 'route': '/peer-comparison', 'desc': 'Anonymous ranking'},
          {'icon': Icons.record_voice_over, 'title': 'Mock Interview', 'route': '/mock-interview', 'desc': 'College admission prep'},
          {'icon': Icons.spellcheck, 'title': 'Spelling & Grammar', 'route': '/spelling-grammar', 'desc': 'Real-time correction'},
          {'icon': Icons.search, 'title': 'Plagiarism Check', 'route': '/plagiarism-checker', 'desc': 'Originality verification'},
        ],
      },
      {
        'title': 'Analytics',
        'color': Colors.cyanAccent,
        'features': [
          {'icon': Icons.biotech, 'title': 'Learning DNA', 'route': '/learning-dna', 'desc': 'How you learn best'},
          {'icon': Icons.insights, 'title': 'Performance Predictor', 'route': '/performance-predictor', 'desc': 'Predicts future scores'},
          {'icon': Icons.access_time, 'title': 'Optimal Study Time', 'route': '/optimal-study-time', 'desc': 'Best hours for studying'},
          {'icon': Icons.warning, 'title': 'Burnout Detector', 'route': '/burnout-detector', 'desc': 'Detects overwork'},
          {'icon': Icons.grid_on, 'title': 'Topic Mastery', 'route': '/topic-mastery', 'desc': 'Visual heatmap tracker'},
          {'icon': Icons.timeline, 'title': 'Forgetting Curve', 'route': '/forgetting-curve-agent', 'desc': 'When to review next'},
          {'icon': Icons.speed, 'title': 'Study Efficiency', 'route': '/study-efficiency', 'desc': 'Hours vs actual learning'},
          {'icon': Icons.compare, 'title': 'Comparative Analytics', 'route': '/comparative-analytics', 'desc': 'vs class average'},
          {'icon': Icons.memory, 'title': 'Long-Term Memory', 'route': '/long-term-memory', 'desc': 'Spaced repetition tests'},
          {'icon': Icons.check_circle, 'title': 'Exam Readiness', 'route': '/exam-readiness', 'desc': 'How ready are you?'},
        ],
      },
      {
        'title': 'Interactive',
        'color': Colors.pinkAccent,
        'features': [
          {'icon': Icons.science, 'title': 'Lab Simulator', 'route': '/lab-simulator', 'desc': 'Virtual experiments'},
          {'icon': Icons.history, 'title': 'Historical Travel', 'route': '/historical-travel', 'desc': 'Talk to historical figures'},
          {'icon': Icons.calculate, 'title': 'Math Solver', 'route': '/math-word-solver', 'desc': 'Step-by-step solutions'},
          {'icon': Icons.eco, 'title': 'Science Explainer', 'route': '/science-explainer', 'desc': 'Science behind anything'},
          {'icon': Icons.edit, 'title': 'Writing Coach', 'route': '/writing-coach', 'desc': 'Improve your writing'},
          {'icon': Icons.language, 'title': 'Language Exchange', 'route': '/language-exchange', 'desc': 'Learn languages together'},
          {'icon': Icons.groups, 'title': 'Group Study', 'route': '/group-study-mod', 'desc': 'AI-moderated sessions'},
          {'icon': Icons.build, 'title': 'Project Guide', 'route': '/project-guide', 'desc': 'Step-by-step projects'},
          {'icon': Icons.school, 'title': 'College Application', 'route': '/college-app-writer', 'desc': 'SOP & recommendation letters'},
          {'icon': Icons.flight, 'title': 'Study Abroad', 'route': '/study-abroad', 'desc': 'University guidance'},
        ],
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('50 AI Agent Features', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F13),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, sectionIndex) {
          final section = sections[sectionIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                section['title'] as String,
                style: TextStyle(
                  color: section['color'] as Color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.3,
                ),
                itemCount: (section['features'] as List).length,
                itemBuilder: (context, index) {
                  final feature = (section['features'] as List)[index] as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => context.push(feature['route'] as String),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (section['color'] as Color).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(feature['icon'] as IconData, color: section['color'] as Color, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            feature['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            feature['desc'] as String,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ).animate().fade(delay: (sectionIndex * 200 + index * 50).ms),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}
