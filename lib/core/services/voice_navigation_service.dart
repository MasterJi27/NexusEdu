import 'package:speech_to_text/speech_to_text.dart';

class VoiceNavigationService {
  static final VoiceNavigationService instance = VoiceNavigationService._();
  VoiceNavigationService._();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool get isListening => _isListening;

  final Map<String, String> _commands = {
    'open tutor': '/tutor',
    'start tutor': '/tutor',
    'open notes': '/notes',
    'open notes screen': '/notes',
    'open profile': '/profile',
    'open dashboard': '/dashboard',
    'go home': '/dashboard',
    'open feed': '/feed',
    'open shorts': '/feed',
    'start quiz': '/quiz',
    'open quiz': '/quiz',
    'open scanner': '/scanner',
    'scan book': '/scanner',
    'open focus': '/focus',
    'focus mode': '/focus',
    'open roadmap': '/roadmap',
    'open live': '/live-classes',
    'live classes': '/live-classes',
    'study rooms': '/study-groups',
    'open study rooms': '/study-groups',
    'youtube summary': '/youtube-summary',
    'open settings': '/profile',
  };

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
      onError: (_) => _isListening = false,
    );
    return _isInitialized;
  }

  Future<String?> startListening() async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return null;
    }

    _isListening = true;
    String? recognizedText;

    await _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords.toLowerCase();
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 3),
    );

    await Future.delayed(const Duration(seconds: 6));
    _isListening = false;
    await _speech.stop();

    return recognizedText;
  }

  String? matchCommand(String text) {
    final lower = text.toLowerCase();
    for (final entry in _commands.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;
  }

  Map<String, String> get availableCommands => Map.unmodifiable(_commands);
}
