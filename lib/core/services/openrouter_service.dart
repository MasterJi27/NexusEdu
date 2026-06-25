import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  static final OpenRouterService _instance = OpenRouterService._();
  factory OpenRouterService() => _instance;
  OpenRouterService._();

  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'nvidia/nemotron-3-ultra-550b-a55b:free';
  String? _apiKey;

  bool get isReady => _apiKey != null && _apiKey!.isNotEmpty;

  Future<void> init() async {
    _apiKey = dotenv.env['GEMINI_API_KEY'];
  }

  Future<String> chat(String prompt, {String systemPrompt = ''}) async {
    if (!isReady) return 'API key not configured.';

    try {
      final messages = <Map<String, String>>[];
      if (systemPrompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      messages.add({'role': 'user', 'content': prompt});

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://nexusedu.app',
          'X-Title': 'NexusEdu',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 2048,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().isNotEmpty) {
          return content.toString();
        }
      }

      return _getLocalFallback(prompt);
    } catch (e) {
      return _getLocalFallback(prompt);
    }
  }

  Future<String> solveDoubt(String question, String subject) async {
    return chat(
      question,
      systemPrompt: 'You are a helpful tutor for $subject. '
          'Explain step by step in simple language. '
          'Use examples where possible. '
          'Keep the explanation clear and concise.',
    );
  }

  Future<String> explainConcept(String concept, String subject) async {
    return chat(
      'Explain the concept of $concept in $subject in detail. '
      'Use real-life examples and analogies. '
      'Make it easy to understand for a student.',
      systemPrompt: 'You are an expert $subject teacher. '
          'Explain concepts in a simple, engaging way.',
    );
  }

  Future<String> generateQuiz(String topic, String subject, {int count = 5}) async {
    return chat(
      'Generate $count quiz questions on $topic in $subject. '
      'Each question should have 4 options (A, B, C, D) with the correct answer marked. '
      'Format: Question, Options, Correct Answer, Brief Explanation.',
      systemPrompt: 'You are a quiz generator for $subject. '
          'Create clear, educational questions.',
    );
  }

  Future<String> generateNotes(String topic, String subject) async {
    return chat(
      'Create comprehensive study notes on $topic in $subject. '
      'Include key points, formulas, diagrams descriptions, and summary. '
      'Format with headings and bullet points.',
      systemPrompt: 'You are a study material creator. '
          'Create well-organized, easy to revise notes.',
    );
  }

  Future<String> solveMath(String problem) async {
    return chat(
      'Solve this math problem step by step: $problem '
      'Show all working clearly.',
      systemPrompt: 'You are a math tutor. '
          'Solve problems step by step with clear explanations.',
    );
  }

  Future<String> generateFlashcards(String topic, String subject, {int count = 10}) async {
    return chat(
      'Create $count flashcards on $topic in $subject. '
      'Format: Front (Question/Concept) | Back (Answer/Definition). '
      'Make them concise and exam-focused.',
      systemPrompt: 'You are a flashcard creator for exam preparation.',
    );
  }

  Future<String> evaluateEssay(String essay, String topic) async {
    return chat(
      'Evaluate this essay on "$topic":\n\n$essay\n\n'
      'Provide: 1) Score out of 10, 2) Strengths, 3) Weaknesses, '
      '4) Suggestions for improvement, 5) Grammar issues if any.',
      systemPrompt: 'You are an essay evaluator. '
          'Provide constructive, detailed feedback.',
    );
  }

  Future<String> generateStudyPlan(String exam, int daysLeft, List<String> subjects) async {
    return chat(
      'Create a $daysLeft-day study plan for $exam. '
      'Subjects: ${subjects.join(", ")}. '
      'Include daily tasks, revision schedule, and break times.',
      systemPrompt: 'You are a study planner. '
          'Create realistic, effective study schedules.',
    );
  }

  Future<String> translate(String text, String targetLanguage) async {
    return chat(
      'Translate the following to $targetLanguage:\n$text',
      systemPrompt: 'You are a translator. '
          'Provide accurate, natural translations.',
    );
  }

  String _getLocalFallback(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('solve') || lower.contains('calculate') || lower.contains('math')) {
      return 'Math Problem Solving:\n\n'
          'I can help solve this problem. Here\'s the approach:\n'
          '1. Identify the given values\n'
          '2. Determine what needs to be found\n'
          '3. Apply the relevant formula\n'
          '4. Calculate step by step\n\n'
          'Please provide the specific problem for a detailed solution.';
    }

    if (lower.contains('explain') || lower.contains('what is')) {
      return 'Concept Explanation:\n\n'
          'This is an important concept in the subject. '
          'Key points to understand:\n'
          '- Definition and basic principle\n'
          '- How it relates to other concepts\n'
          '- Real-world applications\n'
          '- Common examples\n\n'
          'Try asking for a specific topic for a detailed explanation.';
    }

    if (lower.contains('quiz') || lower.contains('question')) {
      return 'Quiz Generation:\n\n'
          'I can generate practice questions on any topic. '
          'The questions will include:\n'
          '- Multiple choice options\n'
          '- Correct answer marked\n'
          '- Brief explanation\n\n'
          'Specify the topic and number of questions needed.';
    }

    if (lower.contains('note') || lower.contains('summary')) {
      return 'Note Generation:\n\n'
          'I can create comprehensive study notes including:\n'
          '- Key points and definitions\n'
          '- Important formulas\n'
          '- Diagrams and examples\n'
          '- Summary for quick revision\n\n'
          'Specify the topic for detailed notes.';
    }

    return 'I can help with:\n'
        '- Solving doubts and explaining concepts\n'
        '- Generating quizzes and practice questions\n'
        '- Creating study notes and summaries\n'
        '- Solving math problems step by step\n'
        '- Translating content\n'
        '- Evaluating essays\n\n'
        'Ask me anything about your studies!';
  }
}
