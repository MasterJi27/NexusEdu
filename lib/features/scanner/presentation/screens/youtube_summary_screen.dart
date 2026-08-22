import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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

  // 300ms debounce for link parsing so rapid typing doesn't thrash thumbnail
  // fetches / regex on every keystroke (ValueListenableBuilder fires per char).
  Timer? _debounceTimer;
  String _debouncedText = '';
  final ValueNotifier<String> _debouncedNotifier = ValueNotifier<String>('');

  /// Matches the 11-character video id out of the common URL shapes
  /// (watch?v=, youtu.be/, /shorts/); returns null for anything else so the
  /// preview can fall back to a placeholder instead of a broken image.
  static final _youtubeIdPattern =
      RegExp(r'(?:v=|youtu\.be/|/shorts/)([A-Za-z0-9_-]{11})');

  String? _extractYoutubeId(String url) {
    return _youtubeIdPattern.firstMatch(url.trim())?.group(1);
  }

  @override
  void initState() {
    super.initState();
    _debouncedText = _urlController.text;
    _debouncedNotifier.value = _urlController.text;
    _urlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final text = _urlController.text;
      // Keep both for setState-driven and ValueListenableBuilder-driven paths.
      _debouncedText = text;
      _debouncedNotifier.value = text;
      // Trigger rebuild for direct _debouncedText usage (no ValueListenableBuilder needed)
      setState(() {});
    });
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
    _debounceTimer?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _debouncedNotifier.dispose();
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
    // Debounced builder: listens to _debouncedNotifier which only updates 300ms
    // after typing stops, avoiding per-keystroke thumbnail reloads.
    return ValueListenableBuilder<String>(
      valueListenable: _debouncedNotifier,
      builder: (context, debouncedValue, _) {
        final id = _extractYoutubeId(debouncedValue);
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
          child: CachedNetworkImage(
            imageUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            memCacheWidth: 640,
            placeholder: (c, u) => SizedBox(
              height: 200,
              width: double.infinity,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.inkFaint,
                  ),
                ),
              ),
            ),
            errorWidget: (c, u, e) => Container(
              height: 200,
              color: t.surfaceAlt,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image, color: t.inkFaint, size: 40),
            ),
          ),
        );
      },
    );
  }
}
