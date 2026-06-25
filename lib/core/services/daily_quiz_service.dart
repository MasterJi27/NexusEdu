import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DailyQuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String subject;
  final String explanation;

  const DailyQuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.subject,
    required this.explanation,
  });
}

class DailyQuizService {
  static final DailyQuizService _instance = DailyQuizService._();
  factory DailyQuizService() => _instance;
  DailyQuizService._();

  DateTime? _lastQuizDate;
  int _todayScore = 0;
  int _todayAttempted = 0;
  bool _todayCompleted = false;

  bool get todayCompleted => _todayCompleted;
  int get todayScore => _todayScore;
  int get todayAttempted => _todayAttempted;

  static const List<DailyQuizQuestion> _allQuestions = [
    DailyQuizQuestion(
      question: 'What is the SI unit of force?',
      options: ['Joule', 'Newton', 'Watt', 'Pascal'],
      correctIndex: 1,
      subject: 'Physics',
      explanation: 'Force is measured in Newtons (N). 1 Newton = 1 kg⋅m/s²',
    ),
    DailyQuizQuestion(
      question: 'Which planet is known as the Red Planet?',
      options: ['Venus', 'Jupiter', 'Mars', 'Saturn'],
      correctIndex: 2,
      subject: 'Science',
      explanation: 'Mars appears red due to iron oxide (rust) on its surface.',
    ),
    DailyQuizQuestion(
      question: 'What is the chemical formula for water?',
      options: ['CO2', 'H2O', 'NaCl', 'O2'],
      correctIndex: 1,
      subject: 'Chemistry',
      explanation: 'Water = 2 Hydrogen atoms + 1 Oxygen atom = H₂O',
    ),
    DailyQuizQuestion(
      question: 'What is the derivative of x²?',
      options: ['x', '2x', 'x²', '2x²'],
      correctIndex: 1,
      subject: 'Mathematics',
      explanation: 'Using power rule: d/dx(xⁿ) = nxⁿ⁻¹, so d/dx(x²) = 2x',
    ),
    DailyQuizQuestion(
      question: 'Which gas do plants absorb during photosynthesis?',
      options: ['Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Hydrogen'],
      correctIndex: 2,
      subject: 'Biology',
      explanation: 'Plants absorb CO₂ and release O₂ during photosynthesis.',
    ),
    DailyQuizQuestion(
      question: 'What is the speed of light?',
      options: ['3×10⁶ m/s', '3×10⁸ m/s', '3×10¹⁰ m/s', '3×10⁴ m/s'],
      correctIndex: 1,
      subject: 'Physics',
      explanation: 'Speed of light in vacuum ≈ 3×10⁸ m/s (300,000 km/s).',
    ),
    DailyQuizQuestion(
      question: 'What is the atomic number of Carbon?',
      options: ['4', '6', '8', '12'],
      correctIndex: 1,
      subject: 'Chemistry',
      explanation: 'Carbon has 6 protons, so its atomic number is 6.',
    ),
    DailyQuizQuestion(
      question: 'Solve: √144 = ?',
      options: ['11', '12', '13', '14'],
      correctIndex: 1,
      subject: 'Mathematics',
      explanation: '12 × 12 = 144, so √144 = 12',
    ),
    DailyQuizQuestion(
      question: 'What is the powerhouse of the cell?',
      options: ['Nucleus', 'Ribosome', 'Mitochondria', 'Golgi Body'],
      correctIndex: 2,
      subject: 'Biology',
      explanation: 'Mitochondria produce ATP (energy) through cellular respiration.',
    ),
    DailyQuizQuestion(
      question: 'What is Ohm\'s Law?',
      options: ['V = IR', 'V = I/R', 'V = I+R', 'V = I×R²'],
      correctIndex: 0,
      subject: 'Physics',
      explanation: 'Ohm\'s Law: Voltage (V) = Current (I) × Resistance (R)',
    ),
    DailyQuizQuestion(
      question: 'Which acid is found in vinegar?',
      options: ['Citric acid', 'Acetic acid', 'Lactic acid', 'Malic acid'],
      correctIndex: 1,
      subject: 'Chemistry',
      explanation: 'Vinegar contains 5-8% acetic acid (CH₃COOH).',
    ),
    DailyQuizQuestion(
      question: 'What is the value of π (pi) to 2 decimal places?',
      options: ['3.12', '3.14', '3.16', '3.18'],
      correctIndex: 1,
      subject: 'Mathematics',
      explanation: 'π ≈ 3.14159... ≈ 3.14 (to 2 decimal places).',
    ),
    DailyQuizQuestion(
      question: 'What is the pH of pure water?',
      options: ['5', '7', '9', '14'],
      correctIndex: 1,
      subject: 'Chemistry',
      explanation: 'Pure water is neutral with pH = 7.',
    ),
    DailyQuizQuestion(
      question: 'Who proposed the law of gravity?',
      options: ['Einstein', 'Newton', 'Galileo', 'Kepler'],
      correctIndex: 1,
      subject: 'Physics',
      explanation: 'Isaac Newton formulated the law of universal gravitation in 1687.',
    ),
    DailyQuizQuestion(
      question: 'What is the largest organ of the human body?',
      options: ['Heart', 'Liver', 'Brain', 'Skin'],
      correctIndex: 3,
      subject: 'Biology',
      explanation: 'Skin is the largest organ, covering about 20 sq ft in adults.',
    ),
    DailyQuizQuestion(
      question: 'Solve: 2x + 5 = 15, x = ?',
      options: ['3', '5', '7', '10'],
      correctIndex: 1,
      subject: 'Mathematics',
      explanation: '2x + 5 = 15 → 2x = 10 → x = 5',
    ),
    DailyQuizQuestion(
      question: 'What is the boiling point of water?',
      options: ['90°C', '100°C', '110°C', '120°C'],
      correctIndex: 1,
      subject: 'Science',
      explanation: 'Water boils at 100°C (212°F) at standard atmospheric pressure.',
    ),
    DailyQuizQuestion(
      question: 'Which blood group is the universal donor?',
      options: ['A+', 'B+', 'AB+', 'O-'],
      correctIndex: 3,
      subject: 'Biology',
      explanation: 'O- blood can be given to any blood group (universal donor).',
    ),
    DailyQuizQuestion(
      question: 'What is the unit of electric current?',
      options: ['Volt', 'Watt', 'Ampere', 'Ohm'],
      correctIndex: 2,
      subject: 'Physics',
      explanation: 'Electric current is measured in Amperes (A).',
    ),
    DailyQuizQuestion(
      question: 'What is 15% of 200?',
      options: ['15', '25', '30', '35'],
      correctIndex: 2,
      subject: 'Mathematics',
      explanation: '15% of 200 = (15/100) × 200 = 30',
    ),
  ];

  List<DailyQuizQuestion> get todayQuestions {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    final shuffled = List<DailyQuizQuestion>.from(_allQuestions)..shuffle(random);
    return shuffled.take(10).toList();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lastQuiz = prefs.getString('last_quiz_date');
    if (lastQuiz != null) _lastQuizDate = DateTime.tryParse(lastQuiz);
    _todayScore = prefs.getInt('today_quiz_score') ?? 0;
    _todayAttempted = prefs.getInt('today_quiz_attempted') ?? 0;
    _todayCompleted = prefs.getBool('today_quiz_completed') ?? false;
    _checkReset();
  }

  void _checkReset() {
    if (_lastQuizDate == null) return;
    final now = DateTime.now();
    final lastDay = DateTime(_lastQuizDate!.year, _lastQuizDate!.month, _lastQuizDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    if (today.difference(lastDay).inDays >= 1) {
      _todayScore = 0;
      _todayAttempted = 0;
      _todayCompleted = false;
      _save();
    }
  }

  Future<void> recordAnswer(int score) async {
    _todayScore = score;
    _todayAttempted++;
    if (_todayAttempted >= 10) _todayCompleted = true;
    _lastQuizDate = DateTime.now();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('today_quiz_score', _todayScore);
    await prefs.setInt('today_quiz_attempted', _todayAttempted);
    await prefs.setBool('today_quiz_completed', _todayCompleted);
    if (_lastQuizDate != null) {
      await prefs.setString('last_quiz_date', _lastQuizDate!.toIso8601String());
    }
  }

  String get timeAgo {
    if (_lastQuizDate == null) return 'Never';
    final diff = DateTime.now().difference(_lastQuizDate!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
