import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:nexus_edu/core/theme/app_theme.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

class TopicLearningScreen extends StatefulWidget {
  const TopicLearningScreen({super.key});

  @override
  State<TopicLearningScreen> createState() => _TopicLearningScreenState();
}

class _TopicLearningScreenState extends State<TopicLearningScreen> {
  late YoutubePlayerController _controller;
  final TextEditingController _doubtController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  
  String _aiResponse = '';
  bool _isTyping = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeechAndTts();
    // Video: Newton's Laws of Motion
    _controller = YoutubePlayerController.fromVideoId(
      videoId: 'kKKM8Y-u7ds', 
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  Future<void> _initSpeechAndTts() async {
    await _speechToText.initialize();
    await _flutterTts.setLanguage("hi-IN"); // Hindi for Bharat Bridge
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    _controller.close();
    _doubtController.dispose();
    super.dispose();
  }

  void _openAiDoubtSolver() {
    _controller.pauseVideo();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDoubtSheet(),
    ).then((_) => _flutterTts.stop());
  }

  Widget _buildDoubtSheet() {
    return Theme(
      data: AppTheme.darkTheme,
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final t = context.tokens;
          
          void listen() async {
            if (!_isListening) {
              bool available = await _speechToText.initialize();
              if (available) {
                setSheetState(() => _isListening = true);
                _speechToText.listen(onResult: (val) {
                  setSheetState(() {
                    _doubtController.text = val.recognizedWords;
                  });
                });
              }
            } else {
              setSheetState(() => _isListening = false);
              _speechToText.stop();
            }
          }
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              border: Border.all(color: t.primaryTintBorder),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.borderStrong,
                    borderRadius: AppRadius.brSm,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Bharat AI Voice Tutor 🇮🇳',
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    IconButton(
                      icon: Icon(Icons.volume_up, color: t.primary),
                      onPressed: () {
                        if (_aiResponse.isNotEmpty) _flutterTts.speak(_aiResponse);
                      },
                    )
                  ],
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  'Speaks Hindi/English. Context: Newton\'s First Law',
                  style: context.text.bodySmall?.copyWith(color: t.inkMuted),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpace.md),
                    children: [
                      if (_aiResponse.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppSpace.md),
                          decoration: BoxDecoration(
                            color: t.primaryTint,
                            borderRadius: AppRadius.brMd,
                          ),
                          child: Text(
                            _aiResponse,
                            style: context.text.bodyLarge?.copyWith(height: 1.5),
                          ),
                        )
                      else if (!_isTyping)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.xl),
                            child: Text(
                              'Tap the mic and speak in Hindi or English! I will explain it out loud.',
                              textAlign: TextAlign.center,
                              style: context.text.bodyMedium?.copyWith(
                                color: t.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      if (_isTyping)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpace.xl),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: listen,
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: _isListening
                              ? t.statusAbsent
                              : t.primaryTint,
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? t.onPrimary : t.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: NexusTextField(
                          controller: _doubtController,
                          hint: _isListening ? 'Listening...' : 'Type or speak...',
                        ),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      FloatingActionButton(
                        onPressed: () async {
                          if (_doubtController.text.isEmpty) return;
                          final q = _doubtController.text;
                          _doubtController.clear();
                          setSheetState(() { _isTyping = true; _aiResponse = ''; });
                          
                          // Send contextual prompt for Hindi/Hinglish
                          final prompt = "The student is watching an English video about Newton's First Law (Inertia). Explain their doubt concisely in Hinglish (Hindi + English): $q";
                          String ans;
                          try {
                            ans = await AiService.sendMessageToTutor(prompt);
                          } catch (_) {
                            ans = "Sorry, I couldn't reach the server. Check your connection and try again.";
                          }

                          if (!mounted) return;
                          setSheetState(() { _isTyping = false; _aiResponse = ans; });
                          await _flutterTts.speak(ans);
                        },
                        backgroundColor: t.primary,
                        foregroundColor: t.onPrimary,
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (context) {
          final t = context.tokens;
          return Scaffold(
            backgroundColor: t.page,
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: t.page,
                  flexibleSpace: FlexibleSpaceBar(
                    background: YoutubePlayer(
                      controller: _controller,
                      backgroundColor: t.page,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laws of Motion: Newton\'s First Law',
                          style: context.text.headlineMedium?.copyWith(
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: t.surfaceAlt,
                              backgroundImage: const CachedNetworkImageProvider(
                                'https://i.pravatar.cc/100?img=3',
                                maxWidth: 100,
                                maxHeight: 100,
                              ),
                              onBackgroundImageError: (_, _) {},
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Text(
                              'Dr. HC Verma',
                              style: context.text.labelLarge?.copyWith(
                                color: t.inkMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            NexusButton(
                              label: 'Ask AI Tutor',
                              icon: Icons.smart_toy,
                              onPressed: _openAiDoubtSolver,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.xl),
                        Text(
                          'Chapter Notes',
                          style: context.text.titleMedium?.copyWith(color: t.ink),
                        ),
                        const SizedBox(height: AppSpace.md),
                        Text(
                          'An object at rest stays at rest and an object in motion stays in motion with the same speed and in the same direction unless acted upon by an unbalanced force.\n\nThis is also known as the law of inertia.',
                          style: context.text.bodyLarge?.copyWith(
                            color: t.inkMuted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xl),
                        Container(
                          padding: const EdgeInsets.all(AppSpace.md),
                          decoration: BoxDecoration(
                            color: t.primaryTint,
                            borderRadius: AppRadius.brMd,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb, color: t.secondaryFill),
                              const SizedBox(width: AppSpace.md),
                              Expanded(
                                child: Text(
                                  'Pro Tip: Inertia is directly proportional to the mass of the object.',
                                  style: context.text.bodyMedium?.copyWith(
                                    color: t.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
