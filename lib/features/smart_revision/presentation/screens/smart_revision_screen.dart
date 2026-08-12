import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/local_history_store.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_chip_group.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';

class SmartRevisionScreen extends StatefulWidget {
  const SmartRevisionScreen({super.key});

  @override
  State<SmartRevisionScreen> createState() => _SmartRevisionScreenState();
}

class _SmartRevisionScreenState extends State<SmartRevisionScreen> {
  String _revisionMode = '3-hour';
  String _selectedSubject = 'Physics';
  bool _isGenerating = false;
  List<Map<String, dynamic>> _keyPoints = [];
  int _currentCardIndex = 0;
  bool _showAnswer = false;
  int _reviewedCount = 0;
  List<Map<String, dynamic>> _revisionHistory = [];
  String? _error;
  static const _historyStore = LocalHistoryStore('revision_history');

  static const List<String> _subjects = [
    'Physics',
    'Chemistry',
    'Biology',
    'Maths',
    'English',
    'Hindi',
  ];

  static const Map<String, String> _modeDescriptions = {
    '1-hour': 'Quick 60-minute focused revision',
    '3-hour': 'Comprehensive 3-hour revision session',
    'Overnight': 'Full overnight intensive revision',
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyStore.load();
    setState(() => _revisionHistory = history);
  }

  Future<void> _saveHistory() async {
    await _historyStore.save(_revisionHistory);
  }

  Future<void> _startRevision() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _keyPoints = [];
      _currentCardIndex = 0;
      _showAnswer = false;
      _reviewedCount = 0;
    });

    final prompt = "Generate key points for a $_revisionMode revision of $_selectedSubject. "
        "Return a JSON array of objects. Each object must have: "
        "\"topic\" (string), \"keyPoint\" (string, the main concept to remember), "
        "\"detail\" (string, brief explanation), "
        "\"importance\" (string, one of: Critical/Important/Review). "
        "Generate 15-20 key points covering the most important topics. "
        "No markdown, no code fences. Raw JSON only.";

    try {
      final result = await AiService.generateStructured(prompt);
      if (!mounted) return;

      final List<dynamic> parsed = json.decode(result);
      setState(() {
        _keyPoints = parsed
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isGenerating = false;
      });

      _revisionHistory.insert(0, {
        'subject': _selectedSubject,
        'mode': _revisionMode,
        'count': _keyPoints.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (_revisionHistory.length > 20) _revisionHistory.removeLast();
      _saveHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _error = "Couldn't generate key points. Check your connection and try again.";
      });
    }
  }

  void _nextCard() {
    if (_currentCardIndex < _keyPoints.length - 1) {
      setState(() {
        _currentCardIndex++;
        _showAnswer = false;
        _reviewedCount++;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _showAnswer = false;
      });
    }
  }

  void _showCompletionDialog() {
    final t = context.tokens;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: Column(
          children: [
            Icon(Icons.celebration, color: t.statusPresent, size: 48),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Revision Complete!',
              style: ctx.text.titleMedium?.copyWith(
                color: t.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'You reviewed ${_keyPoints.length} key points in $_selectedSubject.',
          textAlign: TextAlign.center,
          style: ctx.text.bodyMedium?.copyWith(color: t.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _keyPoints.clear());
            },
            child: Text(
              'Done',
              style: ctx.text.labelLarge?.copyWith(color: t.statusPresent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: 'Smart Revision',
      body: _keyPoints.isNotEmpty ? _buildReviewView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeSelector(),
          const SizedBox(height: AppSpace.md),
          NexusChipGroup(
            label: 'Subject',
            options: _subjects,
            selected: {_selectedSubject},
            onChanged: (s) => setState(() => _selectedSubject = s.first),
          ),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            width: double.infinity,
            child: NexusButton(
              label: _isGenerating ? 'Generating Key Points...' : 'Start Revision',
              icon: Icons.replay,
              isLoading: _isGenerating,
              onPressed: _isGenerating ? null : _startRevision,
              fullWidth: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            NexusBanner(
              message: _error!,
              kind: NexusBannerKind.error,
              actionLabel: 'Retry',
              onAction: _startRevision,
            ),
          ],
          if (_revisionHistory.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            const NexusSectionHeader(title: 'Revision History', spaceAbove: 0),
            ...List.generate(_revisionHistory.length.clamp(0, 10), (i) {
              return _buildHistoryItem(_revisionHistory[i], i);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revision Mode',
            style: context.text.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          ...['1-hour', '3-hour', 'Overnight'].map((mode) {
            final isSelected = _revisionMode == mode;
            return GestureDetector(
              onTap: () => setState(() => _revisionMode = mode),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpace.xs),
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: isSelected ? t.primaryTint : t.surfaceAlt,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: isSelected ? t.primaryTintBorder : t.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      mode == '1-hour'
                          ? Icons.timer
                          : mode == '3-hour'
                              ? Icons.hourglass_top
                              : Icons.nightlight_round,
                      color: isSelected ? t.primary : t.inkMuted,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode,
                            style: context.text.labelLarge?.copyWith(
                              color: isSelected ? t.primary : t.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _modeDescriptions[mode] ?? '',
                            style: context.text.labelSmall?.copyWith(
                              color: t.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: t.primary),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewView() {
    final t = context.tokens;
    final point = _keyPoints[_currentCardIndex];
    final importance = point['importance'] ?? 'Review';
    final importanceColor = importance == 'Critical'
        ? t.statusAbsent
        : importance == 'Important'
            ? t.statusLate
            : t.statusPresent;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.md),
          color: t.surface,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentCardIndex + 1}/${_keyPoints.length}',
                    style: context.text.labelLarge?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: importanceColor.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text(
                      importance,
                      style: context.text.labelSmall?.copyWith(
                        color: importanceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Reviewed: $_reviewedCount',
                    style: context.text.labelSmall?.copyWith(
                      color: t.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              LinearProgressIndicator(
                value: (_currentCardIndex + 1) / _keyPoints.length,
                backgroundColor: t.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(t.primary),
                borderRadius: AppRadius.brSm,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: AnimatedSwitcher(
                duration: AppMotion.enter,
                child: Container(
                  key: ValueKey('$_currentCardIndex-$_showAnswer'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: _showAnswer
                        ? t.statusPresent.withValues(alpha: 0.08)
                        : t.surface,
                    borderRadius: AppRadius.brLg,
                    border: Border.all(
                      color: _showAnswer
                          ? t.statusPresent.withValues(alpha: 0.4)
                          : t.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        point['topic'] ?? '',
                        style: context.text.labelSmall?.copyWith(
                          color: t.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        _showAnswer
                            ? (point['detail'] ?? '')
                            : (point['keyPoint'] ?? ''),
                        textAlign: TextAlign.center,
                        style: context.text.titleMedium?.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        _showAnswer
                            ? 'Tap to see question'
                            : 'Tap to reveal explanation',
                        style: context.text.labelSmall?.copyWith(
                          color: t.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: NexusButton(
                  label: 'Previous',
                  icon: Icons.arrow_back,
                  variant: NexusButtonVariant.secondary,
                  onPressed: _currentCardIndex > 0 ? _previousCard : null,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: NexusButton(
                  label: _currentCardIndex < _keyPoints.length - 1
                      ? 'Next'
                      : 'Finish',
                  icon: _currentCardIndex < _keyPoints.length - 1
                      ? Icons.arrow_forward
                      : Icons.check,
                  onPressed: _nextCard,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
    final t = context.tokens;
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.xs),
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Row(
        children: [
          Icon(Icons.history, color: t.inkMuted, size: 18),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['subject']} - ${item['mode']}',
                  style: context.text.labelLarge?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item['count']} key points',
                  style: context.text.labelSmall?.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: t.statusAbsent, size: 18),
            onPressed: () {
              setState(() => _revisionHistory.removeAt(index));
              _saveHistory();
            },
          ),
        ],
      ),
    );
  }
}
