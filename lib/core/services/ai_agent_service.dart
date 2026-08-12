import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_chat_service.dart';

class AiAgentService {
  static final AiChatService _ai = AiChatService();

  static Future<String> callAgent(
    String agentType,
    Map<String, dynamic> params,
  ) async {
    try {
      switch (agentType) {
        case 'doubt_solver':
          return await _ai.solveDoubt(
            params['question'] ?? '',
            params['subject'] ?? 'General',
          );

        case 'concept_explainer':
          return await _ai.explainConcept(
            params['concept'] ?? '',
            params['subject'] ?? 'General',
          );

        case 'quiz_generator':
          return await _ai.generateQuiz(
            params['topic'] ?? '',
            params['subject'] ?? 'General',
            count: params['count'] ?? 5,
          );

        case 'note_generator':
          return await _ai.generateNotes(
            params['topic'] ?? '',
            params['subject'] ?? 'General',
          );

        case 'math_solver':
          return await _ai.solveMath(params['problem'] ?? '');

        case 'flashcard_maker':
          return await _ai.generateFlashcards(
            params['topic'] ?? '',
            params['subject'] ?? 'General',
            count: params['count'] ?? 10,
          );

        case 'essay_evaluator':
          return await _ai.evaluateEssay(
            params['essay'] ?? '',
            params['topic'] ?? '',
          );

        case 'study_planner':
          return await _ai.generateStudyPlan(
            params['exam'] ?? '',
            params['daysLeft'] ?? 30,
            List<String>.from(params['subjects'] ?? ['General']),
          );

        case 'translator':
          return await _ai.translate(
            params['text'] ?? '',
            params['targetLanguage'] ?? 'Hindi',
          );

        case 'lab_experiment':
          return _generateLabGuide(params);

        case 'custom':
          return await _ai.chat(params['prompt'] as String? ?? '');

        default:
          return await _ai.chat(_buildPrompt(agentType, params));
      }
    } catch (e) {
      // Used to return canned prose indistinguishable from a real answer on
      // any failure (DESIGN.md §08 calls this out as worse than an error) —
      // callers must now catch this and show a real error state instead.
      throw Exception("Couldn't reach the server. Check your connection and try again.");
    }
  }

  static String _buildPrompt(String agentType, Map<String, dynamic> params) {
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

      case 'summary':
        return 'Summarize the following text concisely:\n${params['text']}';

      case 'prediction':
        final scores = params['scores'] as List<dynamic>? ?? [];
        return 'Based on these scores: $scores, predict future performance '
            'and suggest improvements.';

      default:
        return 'Help me with ${params.toString()}';
    }
  }

  static String _generateLabGuide(Map<String, dynamic> params) {
    final experiment = params['experiment'] as String? ?? 'Unknown Experiment';
    final subject = params['subject'] as String? ?? 'General';

    final guides = {
      'Acid-Base Titration':
          'Aim: Determine concentration of acid using standard alkali.\n\n'
          'Apparatus: Burette, pipette, conical flask, phenolphthalein indicator, HCl, NaOH.\n\n'
          'Procedure:\n1. Fill burette with NaOH solution.\n'
          '2. Pipette 10 mL HCl into flask.\n'
          '3. Add 2-3 drops of phenolphthalein.\n'
          '4. Add NaOH dropwise until pink colour persists.\n'
          '5. Record readings. Repeat 3 times.\n\n'
          'Precautions: Read meniscus at eye level. Wash between trials.',

      'Salt Analysis':
          'Aim: Identify basic and acidic radicals in a salt.\n\n'
          'Apparatus: Test tubes, HCl, NaOH, AgNO3, BaCl2.\n\n'
          'Procedure:\n1. Add dilute HCl to salt.\n'
          '2. Observe gas evolution.\n'
          '3. Add NaOH and warm.\n'
          '4. Use confirmatory tests.\n\n'
          'Precautions: Use small amounts. Heat gently.',

      'Simple Pendulum':
          'Aim: Verify T = 2π√(L/g).\n\n'
          'Apparatus: Bob, string, metre scale, stopwatch.\n\n'
          'Procedure:\n1. Set pendulum at 100 cm.\n'
          '2. Time 20 oscillations.\n'
          '3. Repeat for 80, 60, 40, 20 cm.\n'
          '4. Plot T² vs L graph.\n\n'
          'Result: g = 4π²/slope ≈ 9.8 m/s².',

      'Ohm\'s Law Verification':
          'Aim: Verify V = IR.\n\n'
          'Apparatus: Resistor, ammeter, voltmeter, DC supply, rheostat.\n\n'
          'Procedure:\n1. Set up circuit.\n'
          '2. Record V and I for 6 readings.\n'
          '3. Calculate R = V/I.\n'
          '4. Plot V vs I graph.\n\n'
          'Result: V/I = constant = R.',
    };

    return guides[experiment] ??
        'Aim: Study "$experiment" in $subject.\n\n'
            'Follow standard laboratory procedure from your textbook.\n'
            'Record observations carefully.\n'
            'Take at least 3 readings for accuracy.';
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
    final saved = prefs.getStringList(key) ?? [];
    final results = <Map<String, dynamic>>[];
    for (final entry in saved) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map) {
          results.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Ignore corrupted cache entries so one bad write does not break history.
      }
    }
    return results;
  }
}
