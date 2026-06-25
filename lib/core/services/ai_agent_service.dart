import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AiAgentService {
  static Future<String> callAgent(
    String agentType,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await ApiService.post('/api/agents/$agentType', params);
      if (response['success'] != false && response.containsKey('result')) {
        return response['result'] as String;
      }
      return await _geminiFallback(agentType, params);
    } catch (_) {
      return await _geminiFallback(agentType, params);
    }
  }

  static Future<String> _geminiFallback(
    String agentType,
    Map<String, dynamic> params,
  ) async {
    final prompt = _buildPrompt(agentType, params);
    try {
      final response = await ApiService.post('/api/gemini/generate', {
        'prompt': prompt,
      });
      if (response['success'] != false && response.containsKey('result')) {
        return response['result'] as String;
      }
    } catch (_) {}
    return _generateLocalResponse(agentType, params);
  }

  static String _buildPrompt(
    String agentType,
    Map<String, dynamic> params,
  ) {
    switch (agentType) {
      case 'doubt_solver':
        return 'Solve this doubt: ${params['question']}\n'
            'Subject: ${params['subject'] ?? 'General'}\n'
            'Provide a step-by-step solution in simple language.';

      case 'concept_explainer':
        return 'Explain the concept of ${params['concept']} in detail.\n'
            'Subject: ${params['subject'] ?? 'General'}\n'
            'Use real-life examples and analogies.';

      case 'quiz_generator':
        return 'Generate ${params['count'] ?? 5} quiz questions on '
            '${params['topic']} at difficulty level ${params['difficulty'] ?? 2}.\n'
            'Subject: ${params['subject'] ?? 'General'}\n'
            'Include 4 options each with the correct answer marked.';

      case 'flashcard_maker':
        return 'Create ${params['count'] ?? 10} flashcards on '
            '${params['topic']}.\n'
            'Subject: ${params['subject'] ?? 'General'}\n'
            'Front: key term or question. Back: concise explanation.';

      case 'summary':
        return 'Summarize the following text in key bullet points:\n'
            '${params['text']}\n'
            'Keep it concise and exam-focused.';

      case 'mind_map':
        return 'Create a mind map structure for ${params['topic']}.\n'
            'Subject: ${params['subject'] ?? 'General'}\n'
            'List main branches and sub-branches with key points.';

      case 'study_plan':
        return 'Create a study plan for ${params['subject']}.\n'
            'Exam date: ${params['exam_date']}\n'
            'Available hours per day: ${params['hours'] ?? 2}\n'
            'Topics: ${params['topics']}\n'
            'Include daily schedule with breaks.';

      case 'revision_notes':
        return 'Create concise revision notes for ${params['topic']}.\n'
            'Subject: ${params['subject'] ?? 'General'}\n'
            'Include formulas, key definitions, and important points.';

      case 'formula_sheet':
        return 'List all important formulas for ${params['topic']}.\n'
            'Subject: ${params['subject'] ?? 'General'}\n'
            'Include variables description and units.';

      case 'test_analyzer':
        return 'Analyze this test result:\n'
            'Subject: ${params['subject']}\n'
            'Score: ${params['score']}/${params['total']}\n'
            'Correct: ${params['correct']}, Wrong: ${params['wrong']}, '
            'Skipped: ${params['skipped']}\n'
            'Provide detailed analysis and improvement tips.';

      case 'weak_area_detector':
        return 'Identify weak areas from these results:\n'
            '${jsonEncode(params['results'])}\n'
            'Subject: ${params['subject']}\n'
            'Provide topic-wise strength analysis.';

      case 'difficulty_adjuster':
        return 'Suggest difficulty level for ${params['topic']}.\n'
            'Current accuracy: ${params['accuracy']}%\n'
            'Streak: ${params['streak']}\n'
            'Recommend whether to increase, decrease, or maintain difficulty.';

      case 'prediction':
        return 'Predict exam performance based on:\n'
            'Recent scores: ${params['scores']}\n'
            'Study hours: ${params['hours']}\n'
            'Days left: ${params['days_left']}\n'
            'Provide realistic score prediction and tips.';

      case 'schedule_optimizer':
        return 'Optimize study schedule:\n'
            'Subjects: ${params['subjects']}\n'
            'Exam dates: ${params['exam_dates']}\n'
            'Available hours: ${params['hours']}\n'
            'Priority: ${params['priority']}\n'
            'Create an optimized daily schedule.';

      case 'ncert_solver':
        return 'Solve this NCERT question:\n'
            'Subject: ${params['subject']}\n'
            'Chapter: ${params['chapter']}\n'
            'Question: ${params['question']}\n'
            'Provide step-by-step solution following NCERT methodology.';

      case 'previous_year':
        return 'Explain this previous year question:\n'
            'Year: ${params['year']}\n'
            'Exam: ${params['exam']}\n'
            'Question: ${params['question']}\n'
            'Provide solution with marking scheme hints.';

      case 'essay_helper':
        return 'Help write an essay on: ${params['topic']}\n'
            'Subject: ${params['subject']}\n'
            'Word limit: ${params['word_limit'] ?? 250}\n'
            'Provide outline with key arguments.';

      case 'diagram_explainer':
        return 'Explain the diagram of ${params['topic']}.\n'
            'Subject: ${params['subject']}\n'
            'Describe key parts, their functions, and labeling tips.';

      case 'lab_experiment':
        return 'Explain this experiment:\n'
            '${params['experiment']}\n'
            'Subject: ${params['subject']}\n'
            'Include aim, materials, procedure, observations, and conclusion.';

      case 'career_guidance':
        return 'Provide career guidance for:\n'
            'Interests: ${params['interests']}\n'
            'Subjects liked: ${params['subjects']}\n'
            'Suggest career paths, required courses, and colleges in India.';

      case 'motivation':
        return 'Provide motivation for a student:\n'
            'Current situation: ${params['situation']}\n'
            'Goal: ${params['goal']}\n'
            'Days left: ${params['days_left']}\n'
            'Give practical encouragement.';

      case 'vocabulary':
        return 'Create vocabulary list for ${params['topic']}.\n'
            'Subject: ${params['subject']}\n'
            'Include word, pronunciation, meaning, and usage.';

      case 'error_pattern':
        return 'Analyze error patterns:\n'
            '${jsonEncode(params['errors'])}\n'
            'Identify common mistakes and provide correction strategies.';

      case 'custom':
        return params['prompt'] ?? 'Please provide a question.';

      default:
        return 'I can help with: doubt solving, concept explanation, '
            'quiz generation, study planning, and more. '
            'Please specify what you need help with.';
    }
  }

  static String _generateLocalResponse(
    String agentType,
    Map<String, dynamic> params,
  ) {
    switch (agentType) {
      case 'doubt_solver':
        return 'The answer involves applying the relevant formula and '
            'solving step by step. Please try again when the server is available '
            'for a detailed solution.';

      case 'concept_explainer':
        return 'This concept is fundamental to understanding the subject. '
            'Review your textbook chapter and try practice problems.';

      case 'summary':
        final text = params['text'] as String? ?? '';
        final sentences = text.split(RegExp(r'[.!?]+'));
        final keyPoints = sentences
            .where((s) => s.trim().isNotEmpty)
            .take(5)
            .map((s) => '- ${s.trim()}')
            .join('\n');
        return keyPoints.isEmpty ? 'No content to summarize.' : keyPoints;

      case 'prediction':
        final scores = params['scores'] as List<dynamic>? ?? [];
        if (scores.isEmpty) return 'Insufficient data for prediction.';
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        return 'Based on your average score of ${avg.toStringAsFixed(1)}, '
            'you are performing ${avg >= 70 ? "well" : "average"}. '
            'Keep practicing to improve.';

      default:
        return 'Service is currently offline. Please check your connection '
            'and try again.';
    }
  }

  static Future<void> saveResult(
    String type,
    Map<String, dynamic> result,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_results_$type';
    final existing = prefs.getStringList(key) ?? [];
    existing.add(jsonEncode(result));
    if (existing.length > 100) {
      existing.removeAt(0);
    }
    await prefs.setStringList(key, existing);
  }

  static Future<List<Map<String, dynamic>>> getResults(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_results_$type';
    final existing = prefs.getStringList(key) ?? [];
    return existing
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }
}
