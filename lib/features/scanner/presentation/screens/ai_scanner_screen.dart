import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/shared/widgets/nexus_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/azure_ai_service.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/ai_tool_scaffold.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_chip_group.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

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
  String? _error;
  String? _selectedClass;
  String _scanMode = 'Textbook topic';

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
      _error = null;
      _scanResult = '';
    });

    try {
      final bytes = await image.readAsBytes();
      final extractedText = await AzureAiService.ocrImage(bytes);

      if (!mounted) return;

      if (extractedText.trim().isEmpty) {
        setState(() {
          _isProcessing = false;
          _scanResult = 'No readable text found in this image.\n'
              'Use a clearer photo with better lighting and make sure the '
              'whole page is in frame.';
        });
        return;
      }

      final result = await AiService.chatRaw(
        _buildPrompt(extractedText.length > 4000
            ? extractedText.substring(0, 4000)
            : extractedText),
        systemPrompt:
            'You are Nexus, an AI study assistant for Indian school students '
            'using CBSE/ICSE/state syllabus. Analyse the OCR extracted text '
            'and respond in clear English with markdown.',
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _scanResult = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = "Couldn't scan this page. Check your connection and try again.";
      });
    }
  }

  String _buildPrompt(String extractedText) {
    final topic = _topicController.text.trim();
    final classContext = _selectedClass == null
        ? 'Class is not selected. Infer level from the page and mention if class selection would improve accuracy.'
        : 'Student class is $_selectedClass. Keep output aligned to this syllabus.';
    final topicContext = topic.isEmpty
        ? 'If possible, identify the chapter/topic from the image.'
        : 'Student says the topic/chapter is "$topic".';

    return '''
Analyze this study page for Nexus Edu. Text was extracted with OCR.
$classContext
$topicContext
Scan mode: $_scanMode.

Here is the extracted text from the page:
---
$extractedText
---

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
    return AiToolScaffold(
      title: 'AI Book Scanner',
      actions: [
        IconButton(
          tooltip: 'Change class',
          onPressed: () => context.push('/elearning-class'),
          icon: const Icon(Icons.school_outlined),
        ),
      ],
      subtitle:
          'Nexus will extract the chapter, split it topic-wise, pull important lines, and suggest what to revise next.',
      inputForm: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContextCard(context),
          const SizedBox(height: AppSpace.md),
          NexusChipGroup(
            label: 'Scan Mode',
            options: _scanModes,
            selected: {_scanMode},
            onChanged: (s) => setState(() => _scanMode = s.first),
          ),
          const SizedBox(height: AppSpace.md),
          NexusTextField(
            controller: _topicController,
            label: 'Book topic or chapter',
            hint: 'Example: Biology cell membrane, Life Processes',
            icon: Icons.topic_outlined,
          ),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: const ['Biology cell', 'Newton laws', 'Quadratic equations']
                .map((text) => ActionChip(
                      label: Text(text),
                      avatar: const Icon(Icons.auto_awesome, size: 16),
                      onPressed: () =>
                          setState(() => _topicController.text = text),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: NexusButton(
                  label: 'Gallery',
                  icon: Icons.photo_library_outlined,
                  variant: NexusButtonVariant.secondary,
                  onPressed: _isProcessing
                      ? null
                      : () => _scanImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: NexusButton(
                  label: 'Scan Book',
                  icon: Icons.camera_alt_outlined,
                  onPressed: _isProcessing
                      ? null
                      : () => _scanImage(ImageSource.camera),
                ),
              ),
            ],
          ),
        ],
      ),
      generateLabel: 'Scan & Analyze',
      isGenerating: _isProcessing,
      onGenerate: () => _scanImage(ImageSource.gallery),
      errorText: _error,
      onRetry: () => _scanImage(ImageSource.gallery),
      onCopy: () {
        Clipboard.setData(ClipboardData(text: _scanResult));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan result copied.')),
        );
      },
      resultBuilder: _scanResult.isEmpty
          ? null
          : (ctx) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NexusMarkdown(_scanResult, shrinkWrap: true),
                  const SizedBox(height: AppSpace.md),
                  NexusButton(
                    label: 'Ask Tutor',
                    icon: Icons.chat_bubble_outline,
                    fullWidth: true,
                    onPressed: _openResultInTutor,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  NexusButton(
                    label: 'Watch related Shorts',
                    icon: Icons.smart_display,
                    variant: NexusButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: () => context.go('/feed'),
                  ),
                ],
              ),
    );
  }

  Widget _buildContextCard(BuildContext context) {
    final t = context.tokens;
    final classLabel = _selectedClass ?? 'Guest mode';
    final topics = LearningCatalog.topicsFor(_selectedClass, null);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(Icons.document_scanner, color: t.primary),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(classLabel, style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  _selectedClass == null
                      ? 'Add a topic manually for better scan output.'
                      : '${topics.length} syllabus topics available for matching.',
                  style: context.text.bodySmall,
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
}
