import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/ai_tool_scaffold.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NcertSolutionsScreen extends StatefulWidget {
  const NcertSolutionsScreen({super.key});

  @override
  State<NcertSolutionsScreen> createState() => _NcertSolutionsScreenState();
}

/// Offline-first trimming rule: keep the generated text for the newest
/// entries so cached solutions stay viewable without a network, and drop it
/// for older ones instead of growing SharedPreferences without bound.
List<Map<String, dynamic>> capRecentSolutions(
  List<Map<String, dynamic>> entries, {
  int textLimit = 10,
}) {
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (i >= textLimit && (entry['text'] ?? '') != '') {
      entries[i] = {...entry, 'text': ''};
    }
  }
  return entries;
}

/// True when [entry] holds the generated solution text locally.
bool isCachedOffline(Map<String, dynamic> entry) {
  final text = entry['text'];
  return text is String && text.isNotEmpty;
}

class _NcertSolutionsScreenState extends State<NcertSolutionsScreen> {
  String _selectedClass = '10';
  String _selectedSubject = 'Physics';
  String _selectedChapter = '';
  bool _isLoading = false;
  String? _error;
  String _solutions = '';
  List<Map<String, dynamic>> _recentSolutions = [];

  final Map<String, List<String>> _chaptersBySubject = {
    'Physics': [
      'Light - Reflection and Refraction',
      'Human Eye and Colourful World',
      'Electricity',
      'Magnetic Effects of Electric Current',
      'Sources of Energy',
      'Our Environment',
    ],
    'Chemistry': [
      'Chemical Reactions and Equations',
      'Acids, Bases and Salts',
      'Metals and Non-metals',
      'Carbon and its Compounds',
      'Periodic Classification of Elements',
    ],
    'Biology': [
      'Life Processes',
      'Control and Coordination',
      'How do Organisms Reproduce?',
      'Heredity and Evolution',
      'Our Environment',
    ],
    'Maths': [
      'Real Numbers',
      'Polynomials',
      'Pair of Linear Equations in Two Variables',
      'Quadratic Equations',
      'Arithmetic Progressions',
      'Triangles',
      'Coordinate Geometry',
      'Introduction to Trigonometry',
      'Circles',
      'Constructions',
      'Areas Related to Circles',
      'Surface Areas and Volumes',
      'Statistics',
      'Probability',
    ],
    'English': [
      'A Letter to God',
      'Nelson Mandela: Long Walk to Freedom',
      'Two Stories about Flying',
      'From the Diary of Anne Frank',
      'The Hundred Dresses-I',
      'Glimpses of India',
      'Mijbil the Otter',
      'Madam Rides the Bus',
      'The Sermon at Benares',
      'The Proposal',
    ],
    'Hindi': [
      'शुभकामनाओं के प्रसंग',
      'स्मृति',
      'साना - साना हाथ जोड़ना',
      'आत्मकथ्य',
      'उत्साह और सहयोग',
      'राम विलास पाठक - एक जीवन',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedChapter = _chaptersBySubject[_selectedSubject]!.first;
    _loadRecentSolutions();
  }

  Future<void> _loadRecentSolutions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('ncert_solutions') ?? [];
    if (!mounted) return;
    setState(() {
      _recentSolutions = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveRecentSolutions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'ncert_solutions',
      _recentSolutions.map((e) => json.encode(e)).toList(),
    );
  }

  /// True when [entry] holds the generated solution text locally.
  static bool isCachedOffline(Map<String, dynamic> entry) {
    final text = entry['text'];
    return text is String && text.isNotEmpty;
  }

  Future<void> _getSolutions() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _solutions = '';
    });

    final prompt = "Class $_selectedClass $_selectedSubject: $_selectedChapter. "
        "Provide detailed step-by-step NCERT solutions for all questions in this chapter. "
        "Format with question numbers and clear explanations.";

    try {
      final result = await AiService.generateCurriculumContent(prompt);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _solutions = result;
      });

      _recentSolutions.insert(0, {
        'class': _selectedClass,
        'subject': _selectedSubject,
        'chapter': _selectedChapter,
        'timestamp': DateTime.now().toIso8601String(),
        // The generated text is cached locally so the solution stays readable
        // offline and re-opening it costs no tokens.
        'text': result,
      });
      if (_recentSolutions.length > 20) _recentSolutions.removeLast();
      capRecentSolutions(_recentSolutions);
      _saveRecentSolutions();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "Couldn't get solutions. Check your connection and try again.";
      });
    }
  }

  void _deleteSaved(int index) {
    setState(() => _recentSolutions.removeAt(index));
    _saveRecentSolutions();
  }

  void _openSaved(int index) {
    final entry = _recentSolutions[index];
    final cached = isCachedOffline(entry);
    if (!cached) {
      // Legacy entry without cached text: regenerate it (needs network).
      _selectedClass = entry['class'] as String? ?? _selectedClass;
      _selectedSubject = entry['subject'] as String? ?? _selectedSubject;
      _selectedChapter = entry['chapter'] as String? ?? _selectedChapter;
      _getSolutions();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final t = sheetContext.tokens;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.offline_pin_outlined,
                        color: t.statusPresent, size: 20),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        '${entry['subject']} - ${entry['chapter']}',
                        style: sheetContext.text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      entry['text'] as String,
                      style: sheetContext.typeExtras.figure.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AiToolScaffold(
      title: 'NCERT Solutions',
      subtitle: 'Step-by-step solutions for Classes 6-12',
      inputForm: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown(
            context,
            'Class',
            _selectedClass,
            List.generate(7, (i) => (i + 6).toString()),
            (val) {
              setState(() {
                _selectedClass = val!;
              });
            },
          ),
          const SizedBox(height: AppSpace.md),
          _buildDropdown(
            context,
            'Subject',
            _selectedSubject,
            _chaptersBySubject.keys.toList(),
            (val) {
              setState(() {
                _selectedSubject = val!;
                _selectedChapter = _chaptersBySubject[_selectedSubject]!.first;
              });
            },
          ),
          const SizedBox(height: AppSpace.md),
          _buildDropdown(
            context,
            'Chapter',
            _selectedChapter,
            _chaptersBySubject[_selectedSubject]!,
            (val) => setState(() => _selectedChapter = val!),
          ),
        ],
      ),
      generateLabel: 'Get Solutions',
      isGenerating: _isLoading,
      onGenerate: _getSolutions,
      errorText: _error,
      onRetry: _getSolutions,
      resultBuilder: (ctx) => _solutions.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.article, color: ctx.tokens.primary, size: 20),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        '$_selectedSubject - $_selectedChapter',
                        style: ctx.text.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                SelectableText(
                  _solutions,
                  style: ctx.typeExtras.figure.copyWith(height: 1.6),
                ),
              ],
            ),
      historyTitle: 'Recent Solutions',
      history: List.generate(
        _recentSolutions.length,
        (i) => _buildRecentItem(context, _recentSolutions[i], i),
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context,
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelMedium),
        const SizedBox(height: AppSpace.xs),
        Container(
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: t.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            dropdownColor: t.surface,
            underline: const SizedBox(),
            style: context.text.bodyLarge,
            icon: Icon(Icons.arrow_drop_down, color: t.inkMuted),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentItem(
    BuildContext context,
    Map<String, dynamic> sol,
    int index,
  ) {
    final t = context.tokens;
    final cached = isCachedOffline(sol);
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.xs),
      padding: const EdgeInsets.all(AppSpace.sm),
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: () => _openSaved(index),
        child: Row(
          children: [
            Icon(
              cached ? Icons.offline_pin_outlined : Icons.history,
              color: cached ? t.statusPresent : t.inkMuted,
              size: 18,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class ${sol['class']} - ${sol['subject']}',
                    style: context.text.labelMedium?.copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sol['chapter'] ?? '',
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (cached) ...[
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      'Available offline',
                      style: context.text.labelSmall?.copyWith(
                        color: t.statusPresent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: t.statusAbsent, size: 18),
              onPressed: () => _deleteSaved(index),
            ),
          ],
        ),
      ),
    );
  }
}
