import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
    return StatefulBuilder(
      builder: (context, setSheetState) {
        
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
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.purpleAccent.withAlpha(50)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Bharat AI Voice Tutor 🇮🇳', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.purpleAccent),
                    onPressed: () {
                      if (_aiResponse.isNotEmpty) _flutterTts.speak(_aiResponse);
                    },
                  )
                ],
              ),
              const SizedBox(height: 4),
              const Text('Speaks Hindi/English. Context: Newton\'s First Law', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_aiResponse.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.purple.withAlpha(20), borderRadius: BorderRadius.circular(16)),
                        child: Text(_aiResponse, style: const TextStyle(fontSize: 16, height: 1.5)),
                      ).animate().fade().slideY()
                    else if (!_isTyping)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('Tap the mic and speak in Hindi or English! I will explain it out loud.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    if (_isTyping)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Colors.purpleAccent))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: listen,
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: _isListening ? Colors.redAccent : Colors.purpleAccent.withAlpha(50),
                        child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.white : Colors.purpleAccent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _doubtController,
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Listening...' : 'Type or speak...',
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: () async {
                        if (_doubtController.text.isEmpty) return;
                        final q = _doubtController.text;
                        _doubtController.clear();
                        setSheetState(() { _isTyping = true; _aiResponse = ''; });
                        
                        // Send contextual prompt for Hindi/Hinglish
                        final prompt = "The student is watching an English video about Newton's First Law (Inertia). Explain their doubt concisely in Hinglish (Hindi + English): $q";
                        final ans = await AiService.sendMessageToTutor(prompt);
                        
                        if (!mounted) return;
                        setSheetState(() { _isTyping = false; _aiResponse = ans; });
                        await _flutterTts.speak(ans);
                      },
                      backgroundColor: Colors.purpleAccent,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: YoutubePlayer(
                controller: _controller,
                backgroundColor: Colors.black,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      const Text('Laws of Motion: Newton\'s First Law', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const CircleAvatar(backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=3')),
                          const SizedBox(width: 12),
                          const Text('Dr. HC Verma', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _openAiDoubtSolver,
                            icon: const Icon(Icons.smart_toy),
                            label: const Text('Ask AI Tutor'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
                          )
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Chapter Notes', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('An object at rest stays at rest and an object in motion stays in motion with the same speed and in the same direction unless acted upon by an unbalanced force.\n\nThis is also known as the law of inertia.', style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.5)),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.purple.withAlpha(30), borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.amber),
                            SizedBox(width: 16),
                            Expanded(child: Text('Pro Tip: Inertia is directly proportional to the mass of the object.', style: TextStyle(color: Colors.white))),
                          ],
                        ),
                      ).animate().slideX()
                    ],
                  ),
                ),
              )
            ],
          ),
        );
  }
}
