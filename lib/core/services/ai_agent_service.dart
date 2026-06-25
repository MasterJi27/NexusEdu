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

      case 'lab_experiment':
        return _generateLabGuide(params);

      case 'custom':
        final prompt = params['prompt'] as String? ?? '';
        if (prompt.contains('conclusion') || prompt.contains('experiment')) {
          return _generateLabConclusion(prompt);
        }
        return 'The analysis is complete. Based on your inputs, the results show '
            'promising outcomes. Keep up the good work and continue practicing.';

      default:
        return 'Service is currently offline. Please check your connection '
            'and try again.';
    }
  }

  static String _generateLabGuide(Map<String, dynamic> params) {
    final experiment = params['experiment'] as String? ?? 'Unknown Experiment';
    final subject = params['subject'] as String? ?? 'General';

    final guides = {
      'Acid-Base Titration': '''Aim: To determine the concentration of a given acid solution using a standard alkali solution (NaOH).

Apparatus: Burette, pipette, conical flask, burette stand, phenolphthalein indicator, HCl solution, NaOH solution, wash bottle.

Procedure:
1. Rinse the burette with NaOH solution and fill it up to the zero mark.
2. Pipette out 10 mL of HCl solution into a clean conical flask.
3. Add 2-3 drops of phenolphthalein indicator.
4. Note the initial reading of the burette.
5. Add NaOH solution from the burette to the HCl solution drop by drop while shaking the flask continuously.
6. Stop when the solution turns pink and does not fade within 30 seconds.
7. Note the final reading of the burette.
8. Repeat the titration 2 more times for concordant readings.

Observations:
- Initial burette reading: 0.0 mL
- Final burette reading: Note the value
- Volume of NaOH used = Final - Initial

Precautions:
1. Always add acid to water, never water to acid.
2. Use a funnel while filling the burette.
3. Read the meniscus at eye level.
4. Wash the flask between trials.''',

      'Salt Analysis': '''Aim: To identify the basic and acidic radicals present in a given salt.

Apparatus: Test tubes, test tube holder, burner, dilute HCl, dilute NaOH, AgNO3 solution, BaCl2 solution.

Procedure:
1. Take a small amount of salt in a clean test tube.
2. Add dilute HCl and observe for gas evolution.
3. If gas evolves, note the colour and smell.
4. Add NaOH solution and warm gently.
5. Test for specific ions using confirmatory tests.
6. Record all observations systematically.

Precautions:
1. Use only small amounts of chemicals.
2. Heat test tubes gently at an angle.
3. Do not smell gases directly.
4. Wear safety goggles.''',

      'Electrolysis of Water': '''Aim: To demonstrate the electrolysis of water and identify the gases produced at the electrodes.

Apparatus: Hoffmann voltameter or simple electrolysis setup, dilute H2SO4, DC power supply, test tubes, water.

Procedure:
1. Fill the electrolysis apparatus with acidified water (add dilute H2SO4).
2. Invert small test tubes over each electrode.
3. Connect the DC power supply (6-12V).
4. Observe gas bubbles forming at both electrodes.
5. After sufficient gas collects, test each gas.
6. Test gas at cathode with a burning splint (should burn with a pop - Hydrogen).
7. Test gas at anode with a glowing splint (should relight - Oxygen).
8. Note the volume ratio: H2:O2 = 2:1.

Precautions:
1. Use dilute acid, not concentrated.
2. Do not touch electrodes while current is on.
3. Ensure proper ventilation.''',

      'Rusting of Iron': '''Aim: To study the conditions under which iron rusts.

Apparatus: Test tubes, iron nails, distilled water, oil, anhydrous CaCl2, cotton wool.

Procedure:
1. Take 4 clean iron nails and label them A, B, C, D.
2. Tube A: Place nail in dry air (with CaCl2 to absorb moisture). Seal with cotton.
3. Tube B: Place nail in boiled distilled water (no dissolved oxygen). Add oil layer on top.
4. Tube C: Place nail in ordinary water exposed to air.
5. Tube D: Place nail in salt water exposed to air.
6. Observe after 3-5 days.

Observations:
- Tube A: No rust (no moisture)
- Tube B: No rust (no oxygen)
- Tube C: Moderate rust (water + oxygen)
- Tube D: Heavy rust (salt accelerates corrosion)

Conclusion: Iron rusts when both water and oxygen are present. Salt accelerates rusting.''',

      'pH Testing of Household Items': '''Aim: To determine the pH of various household items using pH paper and universal indicator.

Apparatus: pH paper strips, universal indicator solution, test tubes, dropper, watch glass.

Items to Test:
- Lemon juice
- Vinegar
- Soap solution
- Baking soda solution
- Tap water
- Milk
- Soft drink

Procedure:
1. Place a small amount of each item on a watch glass.
2. Dip pH paper in each item and compare with the colour chart.
3. Add 2-3 drops of universal indicator to each.
4. Record the pH value and classification.

Expected Results:
- Lemon juice: pH 2-3 (Acidic)
- Vinegar: pH 2-3 (Acidic)
- Soap solution: pH 9-10 (Basic)
- Baking soda: pH 8-9 (Basic)
- Tap water: pH 6-8 (Neutral)
- Milk: pH 6-7 (Slightly acidic)
- Soft drink: pH 3-4 (Acidic)''',

      'Simple Pendulum': '''Aim: To verify the relationship between time period and length of a simple pendulum.

Apparatus: Pendulum bob, thin string, metre scale, stopwatch, split cork, stand.

Procedure:
1. Set up the pendulum with a length of 100 cm.
2. Pull the bob slightly to one side and release.
3. Time 20 oscillations using the stopwatch.
4. Calculate time period T = total time / 20.
5. Repeat for lengths: 80 cm, 60 cm, 40 cm, 20 cm.
6. Plot T² vs L graph.

Formula: T = 2π√(L/g)
Therefore T² = (4π²/g) × L

Observations:
| Length (m) | T² (s²) |
|-----------|---------|
| 1.0 | 4.0 |
| 0.8 | 3.2 |
| 0.6 | 2.4 |
| 0.4 | 1.6 |
| 0.2 | 0.8 |

From the graph, g = 4π² / slope ≈ 9.8 m/s²''',

      'Ohm\'s Law Verification': '''Aim: To verify Ohm's Law and determine the resistance of a conductor.

Apparatus: Resistor (known), ammeter, voltmeter, DC power supply, rheostat, connecting wires, switch.

Procedure:
1. Set up the circuit with resistor, ammeter in series, voltmeter in parallel.
2. Start with zero current (rheostat at maximum).
3. Increase current step by step using rheostat.
4. Record voltage (V) and current (I) for 6 readings.
5. Calculate R = V/I for each reading.
6. Plot V vs I graph.

Expected Results:
| V (volts) | I (amps) | R (ohms) |
|-----------|----------|----------|
| 1.0 | 0.1 | 10 |
| 2.0 | 0.2 | 10 |
| 3.0 | 0.3 | 10 |
| 4.0 | 0.4 | 10 |
| 5.0 | 0.5 | 10 |

Conclusion: V/I = constant = R. Ohm's Law is verified.''',
    };

    return guides[experiment] ?? '''Aim: Study the experiment "$experiment" in $subject.

Apparatus: Standard $subject laboratory equipment as per textbook.

Procedure:
1. Read the experiment procedure from your textbook carefully.
2. List all required materials and apparatus.
3. Set up the apparatus as shown in the diagram.
4. Follow the step-by-step procedure.
5. Record all observations in a table.
6. Calculate results using the appropriate formula.
7. Draw necessary diagrams and graphs.

Precautions:
1. Handle all equipment carefully.
2. Follow safety guidelines.
3. Record observations immediately.
4. Take at least 3 readings for accuracy.

Conclusion: Analyze your observations and compare with expected results.''';
  }

  static String _generateLabConclusion(String prompt) {
    String experiment = 'the experiment';
    String subject = 'Science';
    if (prompt.contains('Chemistry') || prompt.contains('Titration') || prompt.contains('pH')) {
      subject = 'Chemistry';
    } else if (prompt.contains('Physics') || prompt.contains('Pendulum') || prompt.contains('Ohm')) {
      subject = 'Physics';
    } else if (prompt.contains('Biology') || prompt.contains('Cell') || prompt.contains('Enzyme')) {
      subject = 'Biology';
    }

    final match = RegExp(r'"([^"]+)"').firstMatch(prompt);
    if (match != null) experiment = match.group(1)!;

    return 'Conclusion for "$experiment":\n\n'
        '1. Observations: The experiment was conducted successfully and '
        'systematic observations were recorded at each stage.\n\n'
        '2. Scientific Explanation: The results demonstrate the fundamental '
        'principles of $subject. The observed phenomena can be explained '
        'using established scientific laws and theories.\n\n'
        '3. Real-World Application: These principles are applied in various '
        'fields including medicine, engineering, and environmental science. '
        'Understanding these concepts helps in practical problem-solving.\n\n'
        '4. Sources of Error: Minor variations may occur due to measurement '
        'precision, environmental conditions, or instrumental limitations.\n\n'
        '5. Further Study: Additional experiments with different parameters '
        'would help validate the results and deepen understanding.';
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
