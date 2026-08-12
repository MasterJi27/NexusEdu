import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/ai_tool_scaffold.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

class YoutubeSummaryScreen extends StatefulWidget {
  const YoutubeSummaryScreen({super.key});

  @override
  State<YoutubeSummaryScreen> createState() => _YoutubeSummaryScreenState();
}

class _YoutubeSummaryScreenState extends State<YoutubeSummaryScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String _summary = '';

  /// Matches the 11-character video id out of the common URL shapes
  /// (watch?v=, youtu.be/, /shorts/); returns null for anything else so the
  /// preview can fall back to a placeholder instead of a broken image.
  static final _youtubeIdPattern =
      RegExp(r'(?:v=|youtu\.be/|/shorts/)([A-Za-z0-9_-]{11})');

  String? _extractYoutubeId(String url) {
    return _youtubeIdPattern.firstMatch(url.trim())?.group(1);
  }

  void _generate() async {
    if (_urlController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _summary = '';
    });
    try {
      final result = await AiService.generateYoutubeSummary(_urlController.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _summary = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "Couldn't summarize this video. Check your connection and try again.";
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AiToolScaffold(
      title: 'YouTube Learning Mode',
      subtitle: 'Paste a link and tap Generate to analyze!',
      inputForm: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVideoPreview(context),
          const SizedBox(height: AppSpace.md),
          NexusTextField(
            controller: _urlController,
            hint: 'Paste YouTube URL here...',
          ),
        ],
      ),
      generateLabel: 'Analyze',
      isGenerating: _isLoading,
      onGenerate: _generate,
      errorText: _error,
      onRetry: _generate,
      resultBuilder: _summary.isEmpty
          ? null
          : (ctx) => SelectableText(
                _summary,
                style: ctx.text.bodyLarge?.copyWith(height: 1.5),
              ),
    );
  }

  /// A real thumbnail for the pasted video, not a player — this screen only
  /// summarizes, it never plays anything. Replaces a mockup that showed an
  /// unrelated stock photo with a hardcoded "14:23" duration and a frozen
  /// progress bar regardless of what was pasted.
  Widget _buildVideoPreview(BuildContext context) {
    final t = context.tokens;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _urlController,
      builder: (context, value, _) {
        final id = _extractYoutubeId(value.text);
        if (id == null) {
          return Container(
            width: double.infinity,
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: AppRadius.brMd,
              border: Border.all(color: t.border),
            ),
            child: Text(
              'Paste a YouTube link to preview it here',
              style: context.text.bodySmall?.copyWith(color: t.inkMuted),
            ),
          );
        }
        return ClipRRect(
          borderRadius: AppRadius.brMd,
          child: Image.network(
            'https://img.youtube.com/vi/$id/hqdefault.jpg',
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 200,
              color: t.surfaceAlt,
              alignment: Alignment.center,
              child: Icon(Icons.smart_display_outlined, color: t.inkFaint, size: 40),
            ),
          ),
        );
      },
    );
  }
}
