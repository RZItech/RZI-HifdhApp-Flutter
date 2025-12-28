import 'dart:async';
import 'package:vosk_flutter/vosk_flutter.dart';

abstract class SpeechRecognitionService {
  Future<void> initialize();
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onFinalResult,
    required Function(String) onError,
  });
  Future<void> stopListening();
  void dispose();
}

class VoskSpeechRecognitionService implements SpeechRecognitionService {
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  final ModelLoader _modelLoader = ModelLoader();

  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _isListening = false;

  late Function(String) _onResult;
  late Function(String) _onFinalResult;
  late Function(String) _onError;

  @override
  Future<void> initialize() async {
    // Load Arabic model from assets (use a zipped model folder)
    // Download e.g. vosk-model-ar-mgb2-0.4.zip and place in assets/models/vosk_arabic/
    final modelPath = await _modelLoader.loadFromAssets(
      'assets/models/vosk_arabic/vosk-model-ar-mgb2-0.4.zip',
    );

    _model = await _vosk.createModel(modelPath);
    _recognizer = await _vosk.createRecognizer(
      model: _model!,
      sampleRate: 16000,
    );
  }

  @override
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onFinalResult,
    required Function(String) onError,
  }) async {
    if (_recognizer == null) {
      throw Exception('Vosk not initialized. Call initialize() first.');
    }

    if (_isListening) return;

    _isListening = true;
    _onResult = onResult;
    _onFinalResult = onFinalResult;
    _onError = onError;

    _speechService = await _vosk.initSpeechService(_recognizer!);

    // Partial results (realtime as you speak)
    _speechService!.onPartial().listen((partial) {
      final text = partial.trim();
      if (text.isNotEmpty && text != 'nun') { // 'nun' is Vosk's empty filler
        _onResult(text);
      }
    });

    // Final results (on pauses/sentence end)
    _speechService!.onResult().listen((result) {
      final text = result.trim();
      if (text.isNotEmpty) {
        _onFinalResult(text);
      }
    });

    await _speechService!.start();
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;

    await _speechService?.stop();
    await _speechService?.cancel();
    _speechService = null;
  }

  @override
  void dispose() {
    stopListening();
    _recognizer?.dispose();
    _model?.dispose();
  }
}