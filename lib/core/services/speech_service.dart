import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  final ValueNotifier<String> statusNotifier = ValueNotifier('');
  final ValueNotifier<SpeechRecognitionError?> errorNotifier = ValueNotifier(
    null,
  );
  final ValueNotifier<String> recognizedWordsNotifier = ValueNotifier('');
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _isInitializing = false;

  Future<void> initSpeech() async {
    if (_speechEnabled || _isInitializing) return;

    _isInitializing = true;
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) => statusNotifier.value = status,
      onError: (error) => errorNotifier.value = error,
    );
    _isInitializing = false;
  }

  Future<void> requestPermission() async {
    final microphoneStatus = await Permission.microphone.request();
    final speechStatus = await Permission.speech.request();

    if (microphoneStatus != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }

    if (speechStatus != PermissionStatus.granted) {
      throw Exception('Speech recognition permission not granted');
    }
  }

  Future<void> startListening() async {
    if (!_speechEnabled) {
      await initSpeech();
    }
    if (!_speechEnabled) {
      throw Exception('Speech recognition not available');
    }
    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        _lastWords = result.recognizedWords;
        recognizedWordsNotifier.value = _lastWords;
      },
      localeId: 'ar_SA', // Arabic locale
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  bool isListening() {
    return _speechToText.isListening;
  }
}
