import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';

class AiScannerScreen extends StatefulWidget {
  const AiScannerScreen({super.key});

  @override
  State<AiScannerScreen> createState() => _AiScannerScreenState();
}

class _AiScannerScreenState extends State<AiScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _topicController = TextEditingController();

  bool _isProcessing = false;
  String _scanResult = '';
  String? _selectedClass;
  String _scanMode = 'Textbook topic';
  String? _lastImageName;

  final List<String> _scanModes = const [
    'Textbook topic',
    'Handwritten notes',
    'Math problem',
    'Quick flashcards',
  ];

  @override
  void initState() {
    super.initState();
    _loadClass();
  }

  Future<void> _loadClass() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    if (!mounted) return;
    setState(() => _selectedClass = selectedClass);
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _scanImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _scanResult = '';
      _lastImageName = image.name;
    });

    final bytes = await image.readAsBytes();
    final result = await AiService.analyzeImage(bytes, _buildPrompt());

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _scanResult = result;
    });
  }

  String _buildPrompt() {
    final topic = _topicController.text.trim();
    final classContext = _selectedClass == null
        ? 'Class is not selected. Infer level from the page and mention if class selection would improve accuracy.'
        : 'Student class is $_selectedClass. Keep output aligned to this syllabus.';
    final topicContext = topic.isEmpty
        ? 'If possible, identify the chapter/topic from the image.'
        : 'Student says the topic/chapter is "$topic".';

    return '''
Analyze this study image for Nexus Edu.
$classContext
$topicContext
Scan mode: $_scanMode.

Return markdown in this exact structure:
## Detected Topic
Name the subject, chapter, and likely syllabus point.

## Topic Detail Wise
- Break the page into concept-wise bullets.
- Explain each concept in simple student-friendly English/Hinglish.

## Important Lines
- Extract exam-relevant definitions, formulas, or diagrams labels.

## What To Do Next
- Give 3 actions: revise, ask tutor, or watch a related short.

If it is a math problem, solve step-by-step and include the final answer only after the reasoning.
''';
  }

  void _openResultInTutor() {
    context.go('/tutor');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paste copied scan notes into Tutor if needed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Book Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Change class',
            onPressed: () => context.push('/elearning-class'),
            icon: const Icon(Icons.school_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        children: [
          _buildContextCard(context).animate().fade().slideY(begin: -0.06),
          const SizedBox(height: 16),
          _buildModeSelector().animate().fade(delay: 100.ms),
          const SizedBox(height: 16),
          _buildTopicInput().animate().fade(delay: 160.ms),
          const SizedBox(height: 18),
          if (_isProcessing)
            _buildProcessingState().animate().fade()
          else if (_scanResult.isNotEmpty)
            _buildResultCard(context).animate().fade().slideY(begin: 0.08)
          else
            _buildEmptyState(context).animate().fade(delay: 220.ms),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _scanImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _scanImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan Book'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextCard(BuildContext context) {
    final classLabel = _selectedClass ?? 'Guest mode';
    final topics = LearningCatalog.topicsFor(_selectedClass, null);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(35)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(28),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.document_scanner, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedClass == null
                      ? 'Add a topic manually for better scan output.'
                      : '${topics.length} syllabus topics available for matching.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/elearning-class'),
            child: const Text('Class'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _scanModes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = _scanModes[index];
          return ChoiceChip(
            label: Text(mode),
            selected: _scanMode == mode,
            onSelected: (_) => setState(() => _scanMode = mode),
          );
        },
      ),
    );
  }

  Widget _buildTopicInput() {
    return TextField(
      controller: _topicController,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: 'Book topic or chapter',
        hintText: 'Example: Biology cell membrane, Life Processes',
        prefixIcon: Icon(Icons.topic_outlined),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 86,
            color: Colors.deepPurpleAccent.withAlpha(130),
          ),
          const SizedBox(height: 18),
          const Text(
            'Scan a book page',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Nexus will extract the chapter, split it topic-wise, pull important lines, and suggest what to revise next.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.45),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSuggestionChip('Biology cell'),
              _buildSuggestionChip('Newton laws'),
              _buildSuggestionChip('Quadratic equations'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      avatar: const Icon(Icons.auto_awesome, size: 16),
      onPressed: () => setState(() => _topicController.text = text),
    );
  }

  Widget _buildProcessingState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.deepPurpleAccent),
          const SizedBox(height: 22),
          const Text(
            'Nexus AI is reading the page...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_lastImageName != null) ...[
            const SizedBox(height: 8),
            Text(
              _lastImageName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 360),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.deepPurpleAccent.withAlpha(50)),
            boxShadow: [
              BoxShadow(color: Colors.deepPurple.withAlpha(18), blurRadius: 20),
            ],
          ),
          child: MarkdownBody(
            data: _scanResult,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: const TextStyle(fontSize: 15, height: 1.45),
                  h2: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _scanResult));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scan result copied.')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _openResultInTutor,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Ask Tutor'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/feed'),
            icon: const Icon(Icons.smart_display),
            label: const Text('Watch related Shorts'),
          ),
        ),
      ],
    );
  }
}
