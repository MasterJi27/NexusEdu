import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

class ChatMessage {
  final bool isBot;
  final String text;

  /// When the message was created. Null for seeded demo messages.
  final DateTime? timestamp;

  const ChatMessage({
    required this.isBot,
    required this.text,
    this.timestamp,
  });
}

class TutorState {
  final List<ChatMessage> messages;
  final bool isDebateMode;
  final bool isTyping;
  final bool isListening;
  final bool isVoiceConversation;
  final bool showXpPopup;
  final String? selectedClass;

  TutorState({
    this.messages = const [],
    this.isDebateMode = false,
    this.isTyping = false,
    this.isListening = false,
    this.isVoiceConversation = false,
    this.showXpPopup = false,
    this.selectedClass,
  });

  TutorState copyWith({
    List<ChatMessage>? messages,
    bool? isDebateMode,
    bool? isTyping,
    bool? isListening,
    bool? isVoiceConversation,
    bool? showXpPopup,
    String? selectedClass,
  }) {
    return TutorState(
      messages: messages ?? this.messages,
      isDebateMode: isDebateMode ?? this.isDebateMode,
      isTyping: isTyping ?? this.isTyping,
      isListening: isListening ?? this.isListening,
      isVoiceConversation: isVoiceConversation ?? this.isVoiceConversation,
      showXpPopup: showXpPopup ?? this.showXpPopup,
      selectedClass: selectedClass ?? this.selectedClass,
    );
  }
}

class TutorNotifier extends Notifier<TutorState> {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  @override
  TutorState build() {
    _initServices();
    return TutorState(
      messages: const [
        ChatMessage(
          isBot: true,
          text:
              'Hi! I am Nexus, your AI Tutor. I see you are struggling with Big O Notation. Would you like a simple analogy?',
        ),
      ],
    );
  }

  Future<void> _initServices() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    state = state.copyWith(selectedClass: selectedClass);

    try {
      await _speechToText.initialize();
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS/STT init error: $e');
    }
  }

  void toggleDebateMode(bool isEnabled) {
    var newMessages = List<ChatMessage>.from(state.messages);
    if (isEnabled) {
      newMessages.insert(
        0,
        const ChatMessage(
          isBot: true,
          text:
              'Debate Mode Activated. Prove to me that you understand the concept by challenging my statements!',
        ),
      );
    }
    state = state.copyWith(isDebateMode: isEnabled, messages: newMessages);
  }

  Future<void> stopAudio() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
    if (state.isVoiceConversation) {
      toggleVoiceConversation(false);
    }
  }

  /// Hands-free conversation: speak → auto-send → hear the reply → listen
  /// again, until the user turns the mode off. Built on the same STT/TTS
  /// primitives as the tap-to-talk button, no extra services.
  Future<void> toggleVoiceConversation(bool on) async {
    state = state.copyWith(isVoiceConversation: on, isListening: false);
    try {
      await _flutterTts.stop();
      await _speechToText.stop();
    } catch (e) {
      debugPrint('Voice stop error: $e');
    }
    if (on) {
      await listen((_) {}, autoSend: true);
    }
  }

  Future<void> listen(void Function(String) onResult, {bool autoSend = false}) async {
    if (!state.isListening) {
      try {
        bool available = await _speechToText.initialize();
        if (available) {
          state = state.copyWith(isListening: true);
          _speechToText.listen(
            listenOptions: stt.SpeechListenOptions(
              listenFor: const Duration(minutes: 2),
            ),
            onResult: (val) {
              final text = val.recognizedWords.trim();
              if (text.isNotEmpty) onResult(text);
              if (autoSend && val.finalResult && text.isNotEmpty) {
                _speechToText.stop();
                state = state.copyWith(isListening: false);
                sendMessage(text);
              }
            },
          );
        }
      } catch (e) {
        debugPrint('Speech init error: $e');
      }
    } else {
      state = state.copyWith(isListening: false);
      _speechToText.stop();
    }
  }

  void hideXpPopup() {
    state = state.copyWith(showXpPopup: false);
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty) return;

    var newMessages = List<ChatMessage>.from(state.messages);
    newMessages.insert(
      0,
      ChatMessage(isBot: false, text: text, timestamp: DateTime.now()),
    );

    state = state.copyWith(messages: newMessages, isTyping: true);

    String fullReply = "";
    var updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages.insert(
      0,
      ChatMessage(isBot: true, text: "", timestamp: DateTime.now()),
    );
    state = state.copyWith(messages: updatedMessages);

    try {
      final responseStream = AiService.sendMessageStreamToTutor(text);

      await for (final chunk in responseStream) {
        fullReply += chunk;
        var streamingMessages = List<ChatMessage>.from(state.messages);
        streamingMessages[0] = ChatMessage(
          isBot: true,
          text: fullReply,
          timestamp: streamingMessages[0].timestamp,
        );
        state = state.copyWith(messages: streamingMessages, isTyping: false);
      }
    } catch (e) {
      fullReply = 'Sorry, I encountered an error. Please try again.';
      var errorMessages = List<ChatMessage>.from(state.messages);
      errorMessages[0] = ChatMessage(
        isBot: true,
        text: fullReply,
        timestamp: errorMessages[0].timestamp,
      );
      state = state.copyWith(isTyping: false, messages: errorMessages);
    }

    bool showPopup =
        state.isDebateMode && fullReply.toLowerCase().contains('concede');

    state = state.copyWith(
      isTyping: false,
      showXpPopup: showPopup,
    );

    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.speak(fullReply);
      if (state.isVoiceConversation) {
        await listen((_) {}, autoSend: true);
      }
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }
}

final tutorProvider = NotifierProvider<TutorNotifier, TutorState>(
  TutorNotifier.new,
);
