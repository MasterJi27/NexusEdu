import 'package:flutter/material.dart';

class SubjectSyllabus {
  const SubjectSyllabus({
    required this.name,
    required this.icon,
    required this.color,
    required this.topics,
  });

  final String name;
  final IconData icon;
  final Color color;
  final List<String> topics;
}

class LearningShort {
  const LearningShort({
    required this.videoId,
    required this.title,
    required this.creator,
    required this.className,
    required this.subject,
    required this.topic,
    required this.takeaway,
    required this.outcomes,
    this.isApiResult = false,
  });

  final String videoId;
  final String title;
  final String creator;
  final String className;
  final String subject;
  final String topic;
  final String takeaway;
  final List<String> outcomes;
  final bool isApiResult;

  String get queryText =>
      '$title $creator $className $subject $topic $takeaway ${outcomes.join(' ')}'
          .toLowerCase();

  LearningShort copyWith({
    String? videoId,
    String? title,
    String? creator,
    String? className,
    String? subject,
    String? topic,
    String? takeaway,
    List<String>? outcomes,
    bool? isApiResult,
  }) {
    return LearningShort(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      creator: creator ?? this.creator,
      className: className ?? this.className,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      takeaway: takeaway ?? this.takeaway,
      outcomes: outcomes ?? this.outcomes,
      isApiResult: isApiResult ?? this.isApiResult,
    );
  }
}

class CertificateProgress {
  const CertificateProgress({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;
}

class LearningCatalog {
  static const List<String> classes = [
    'Class 9',
    'Class 10',
    'Class 11',
    'Class 12',
    'JEE Mains',
    'NEET',
  ];

  static final Map<String, List<SubjectSyllabus>> syllabus = {
    'Class 9': [
      const SubjectSyllabus(
        name: 'Physics',
        icon: Icons.bolt,
        color: Colors.blueAccent,
        topics: [
          'Motion',
          'Force and Laws of Motion',
          'Gravitation',
          'Work and Energy',
        ],
      ),
      const SubjectSyllabus(
        name: 'Biology',
        icon: Icons.biotech,
        color: Colors.green,
        topics: [
          'Cell: Fundamental Unit of Life',
          'Tissues',
          'Diversity in Living Organisms',
          'Why Do We Fall Ill',
        ],
      ),
      const SubjectSyllabus(
        name: 'Mathematics',
        icon: Icons.calculate,
        color: Colors.deepPurpleAccent,
        topics: [
          'Number Systems',
          'Polynomials',
          'Coordinate Geometry',
          'Linear Equations',
        ],
      ),
    ],
    'Class 10': [
      const SubjectSyllabus(
        name: 'Mathematics',
        icon: Icons.functions,
        color: Colors.deepPurpleAccent,
        topics: [
          'Real Numbers',
          'Polynomials',
          'Pair of Linear Equations',
          'Quadratic Equations',
        ],
      ),
      const SubjectSyllabus(
        name: 'Science',
        icon: Icons.science,
        color: Colors.teal,
        topics: [
          'Chemical Reactions',
          'Life Processes',
          'Electricity',
          'Light Reflection and Refraction',
        ],
      ),
      const SubjectSyllabus(
        name: 'Biology',
        icon: Icons.local_florist,
        color: Colors.green,
        topics: [
          'Life Processes',
          'Control and Coordination',
          'Reproduction',
          'Heredity',
        ],
      ),
    ],
    'Class 11': [
      const SubjectSyllabus(
        name: 'Physics',
        icon: Icons.speed,
        color: Colors.blueAccent,
        topics: [
          'Units and Measurements',
          'Motion in a Straight Line',
          'Laws of Motion',
          'Work, Energy and Power',
        ],
      ),
      const SubjectSyllabus(
        name: 'Biology',
        icon: Icons.eco,
        color: Colors.green,
        topics: [
          'The Living World',
          'Biological Classification',
          'Photosynthesis in Higher Plants',
          'Respiration in Plants',
        ],
      ),
      const SubjectSyllabus(
        name: 'Mathematics',
        icon: Icons.timeline,
        color: Colors.deepPurpleAccent,
        topics: [
          'Sets',
          'Relations and Functions',
          'Trigonometric Functions',
          'Limits and Derivatives',
        ],
      ),
    ],
    'Class 12': [
      const SubjectSyllabus(
        name: 'Physics',
        icon: Icons.electrical_services,
        color: Colors.blueAccent,
        topics: [
          'Electric Charges and Fields',
          'Current Electricity',
          'Ray Optics',
          'Atoms and Nuclei',
        ],
      ),
      const SubjectSyllabus(
        name: 'Biology',
        icon: Icons.bubble_chart,
        color: Colors.green,
        topics: [
          'Reproduction in Organisms',
          'Genetics',
          'Biotechnology',
          'Ecology',
        ],
      ),
      const SubjectSyllabus(
        name: 'Mathematics',
        icon: Icons.stacked_line_chart,
        color: Colors.deepPurpleAccent,
        topics: [
          'Relations and Functions',
          'Matrices',
          'Calculus',
          'Probability',
        ],
      ),
    ],
    'JEE Mains': [
      const SubjectSyllabus(
        name: 'Physics',
        icon: Icons.rocket_launch,
        color: Colors.blueAccent,
        topics: [
          'Mechanics',
          'Electrostatics',
          'Modern Physics',
          'Thermodynamics',
        ],
      ),
      const SubjectSyllabus(
        name: 'Chemistry',
        icon: Icons.science,
        color: Colors.orange,
        topics: [
          'Mole Concept',
          'Chemical Bonding',
          'Organic Basics',
          'Coordination Compounds',
        ],
      ),
      const SubjectSyllabus(
        name: 'Mathematics',
        icon: Icons.architecture,
        color: Colors.deepPurpleAccent,
        topics: ['Quadratic Equations', 'Calculus', 'Vectors', 'Probability'],
      ),
    ],
    'NEET': [
      const SubjectSyllabus(
        name: 'Biology',
        icon: Icons.eco,
        color: Colors.green,
        topics: [
          'Cell Biology',
          'Plant Physiology',
          'Human Physiology',
          'Genetics and Evolution',
        ],
      ),
      const SubjectSyllabus(
        name: 'Physics',
        icon: Icons.bolt,
        color: Colors.blueAccent,
        topics: ['Mechanics', 'Electrostatics', 'Optics', 'Modern Physics'],
      ),
      const SubjectSyllabus(
        name: 'Chemistry',
        icon: Icons.science,
        color: Colors.orange,
        topics: [
          'Physical Chemistry',
          'Organic Chemistry',
          'Inorganic Chemistry',
          'Biomolecules',
        ],
      ),
    ],
  };

  static const List<LearningShort> shorts = [
    LearningShort(
      videoId: 'zF_t-eNs9aY',
      title: 'Laws of Motion: important equations',
      creator: '@XylemClass9',
      className: 'Class 9',
      subject: 'Physics',
      topic: 'Force and Laws of Motion',
      takeaway:
          'Revise Newton law equations first, then connect each formula to force, mass, and acceleration.',
      outcomes: [
        'Identify the key motion formulas',
        'Link force with momentum change',
        'Use equations only after reading the situation',
      ],
    ),
    LearningShort(
      videoId: 'S2TRaWcAQJo',
      title: 'Newton first law in simple language',
      creator: '@ScienceShorts',
      className: 'Class 9',
      subject: 'Physics',
      topic: 'Force and Laws of Motion',
      takeaway:
          'Inertia means objects resist change in motion until an external unbalanced force acts.',
      outcomes: [
        'Define inertia',
        'Spot balanced and unbalanced force examples',
        'Explain why seat belts matter',
      ],
    ),
    LearningShort(
      videoId: 'y2mS7FiRXfo',
      title: 'Momentum in under a minute',
      creator: '@PhysicsClass9',
      className: 'Class 9',
      subject: 'Physics',
      topic: 'Motion',
      takeaway:
          'Momentum depends on both mass and velocity, so a heavy slow object can still hit hard.',
      outcomes: [
        'Use p = mv',
        'Compare momentum across objects',
        'Connect momentum to Newton second law',
      ],
    ),
    LearningShort(
      videoId: 'ynyibKfoXBw',
      title: 'Discovery of cell timeline',
      creator: '@JoesConceptVlogs',
      className: 'Class 9',
      subject: 'Biology',
      topic: 'Cell: Fundamental Unit of Life',
      takeaway:
          'Cell theory developed through microscope observations by Hooke, Leeuwenhoek, Schleiden, Schwann, and Virchow.',
      outcomes: [
        'Recall key scientists',
        'Understand why microscopes changed biology',
        'Connect cell theory to living organisms',
      ],
    ),
    LearningShort(
      videoId: '1ow-PgDd9wg',
      title: 'Cell membrane and its role',
      creator: '@InfinityLearn',
      className: 'Class 9',
      subject: 'Biology',
      topic: 'Cell: Fundamental Unit of Life',
      takeaway:
          'The cell membrane controls entry and exit, helping the cell maintain its internal balance.',
      outcomes: [
        'Explain selective permeability',
        'Compare membrane and cell wall',
        'Use diffusion examples',
      ],
    ),
    LearningShort(
      videoId: 'VrwFNFoo-x4',
      title: 'Nature of roots in quadratic equations',
      creator: '@MathPractice',
      className: 'Class 10',
      subject: 'Mathematics',
      topic: 'Quadratic Equations',
      takeaway:
          'The discriminant b squared minus 4ac tells whether roots are real, equal, or imaginary.',
      outcomes: [
        'Calculate discriminant',
        'Predict root type quickly',
        'Avoid solving when only nature is asked',
      ],
    ),
    LearningShort(
      videoId: 'i12SuiiXk1I',
      title: 'Quadratic equations exam fact',
      creator: '@iPrep',
      className: 'Class 10',
      subject: 'Mathematics',
      topic: 'Quadratic Equations',
      takeaway:
          'Convert questions into ax squared plus bx plus c equals zero before choosing a method.',
      outcomes: [
        'Recognize standard form',
        'Pick factorization or formula',
        'Check answers by substitution',
      ],
    ),
    LearningShort(
      videoId: 'tkNdZmPtfGQ',
      title: 'Events of photosynthesis',
      creator: '@Chanakya4IIT',
      className: 'Class 10',
      subject: 'Biology',
      topic: 'Life Processes',
      takeaway:
          'Photosynthesis needs light absorption, water splitting, carbon dioxide reduction, and glucose formation.',
      outcomes: [
        'Recall the main events',
        'Connect chlorophyll to light energy',
        'Separate raw materials from products',
      ],
    ),
    LearningShort(
      videoId: '5UMJTcYEPQo',
      title: 'Photosynthesis definition',
      creator: '@BotanyExamPurpose',
      className: 'Class 11',
      subject: 'Biology',
      topic: 'Photosynthesis in Higher Plants',
      takeaway:
          'Plants convert light energy into chemical energy stored in glucose using chlorophyll.',
      outcomes: [
        'Define photosynthesis',
        'Name raw materials',
        'Remember the role of chloroplasts',
      ],
    ),
    LearningShort(
      videoId: 'E-LfEvsKNKo',
      title: 'Photosynthesis process',
      creator: '@ScienceShorts',
      className: 'NEET',
      subject: 'Biology',
      topic: 'Plant Physiology',
      takeaway:
          'For NEET, focus on where light reaction and Calvin cycle happen and what each produces.',
      outcomes: [
        'Separate light and dark reactions',
        'Track ATP and NADPH',
        'Connect NCERT diagrams to MCQs',
      ],
    ),
    LearningShort(
      videoId: 'aul1z1JiCos',
      title: 'Newton three laws with examples',
      creator: '@JEEPhysics',
      className: 'JEE Mains',
      subject: 'Physics',
      topic: 'Mechanics',
      takeaway:
          'Real-life examples help you decide which Newton law is active before writing equations.',
      outcomes: [
        'Classify law examples',
        'Translate situations into free-body diagrams',
        'Avoid formula-first mistakes',
      ],
    ),
    LearningShort(
      videoId: 'CMiPYHNNg28',
      title: 'Photosynthesis updated explainer',
      creator: '@AmoebaSisters',
      className: 'Class 10',
      subject: 'Biology',
      topic: 'Life Processes',
      takeaway:
          'A full explainer for when a short is not enough: trace carbon dioxide and water into glucose.',
      outcomes: [
        'Understand the full pathway',
        'Connect leaf structures to function',
        'Revise with a diagram',
      ],
    ),
  ];

  static List<SubjectSyllabus> subjectsFor(String? className) {
    if (className == null) return const [];
    return syllabus[className] ?? const [];
  }

  static List<String> topicsFor(String? className, String? subject) {
    if (className == null) return const [];
    final subjects = subjectsFor(className);
    if (subject == null || subject == 'All') {
      return subjects.expand((subject) => subject.topics).toSet().toList();
    }
    return subjects
        .where((item) => item.name == subject)
        .expand((item) => item.topics)
        .toList();
  }

  static List<LearningShort> shortsFor({
    String? className,
    String? subject,
    String? topic,
  }) {
    Iterable<LearningShort> result = shorts;
    if (className != null) {
      result = result.where((item) => item.className == className);
    }
    if (subject != null && subject != 'All') {
      result = result.where((item) => item.subject == subject);
    }
    if (topic != null && topic != 'All') {
      result = result.where((item) => item.topic == topic);
    }
    return result.toList();
  }

  static List<LearningShort> searchShorts(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return shorts.take(6).toList();
    final terms = normalized
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 2)
        .toList();
    final ranked =
        shorts
            .map((item) {
              final score = terms.where(item.queryText.contains).length;
              return MapEntry(item, score);
            })
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) return shorts.take(6).toList();
    return ranked.map((entry) => entry.key).toList();
  }

  static List<LearningShort> mergeUnique(
    List<LearningShort> primary,
    List<LearningShort> fallback,
  ) {
    final seen = <String>{};
    final merged = <LearningShort>[];
    for (final item in [...primary, ...fallback]) {
      if (seen.add(item.videoId)) merged.add(item);
    }
    return merged;
  }

  static List<CertificateProgress> certificatesFor({
    required String? selectedClass,
    required int completedShorts,
  }) {
    final classLabel = selectedClass ?? 'Guest';
    final baseProgress = (completedShorts / 12).clamp(0.0, 1.0);
    return [
      CertificateProgress(
        title: '$classLabel Micro-Learning',
        subtitle: '${(baseProgress * 100).round()}% complete',
        icon: Icons.workspace_premium,
        color: Colors.amber,
        progress: baseProgress,
      ),
      CertificateProgress(
        title: 'AI Tutor Practice',
        subtitle: '2 of 5 doubt sessions',
        icon: Icons.smart_toy,
        color: Colors.deepPurpleAccent,
        progress: 0.4,
      ),
      CertificateProgress(
        title: 'Scanner Scholar',
        subtitle: 'Topic-wise notes ready',
        icon: Icons.document_scanner,
        color: Colors.teal,
        progress: 0.65,
      ),
    ];
  }
}
