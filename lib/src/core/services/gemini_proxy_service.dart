import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

/// Calls the secure server-side Gemini proxy (Cloud Functions `geminiGenerate`
/// and `geminiChat`).
///
/// The Gemini API key lives ONLY on the server (functions env / Secret Manager).
/// It is never shipped to, stored in, or read by the client — this is the whole
/// point of routing AI calls through Cloud Functions.
class GeminiProxy {
  static FirebaseFunctions get _functions => FirebaseFunctions.instance;

  /// One-shot generation. [fileBytes] is optional (image / PDF / short video).
  /// Set [jsonOnly] to ask the model to return strict JSON.
  static Future<String> generate({
    required String prompt,
    Uint8List? fileBytes,
    String? mimeType,
    String? model,
    bool jsonOnly = false,
  }) async {
    final callable = _functions.httpsCallable(
      'geminiGenerate',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final res = await callable.call(<String, dynamic>{
      'prompt': prompt,
      if (fileBytes != null && mimeType != null)
        'fileBase64': base64Encode(fileBytes),
      if (mimeType != null) 'mimeType': mimeType,
      if (model != null && model.isNotEmpty) 'model': model,
      'jsonOnly': jsonOnly,
    });
    return _readText(res.data);
  }

  /// Multi-turn chat. Each [history] entry is
  /// `{'role': 'user' | 'model', 'text': '...'}`.
  static Future<String> chat({
    required String message,
    String? systemInstruction,
    List<Map<String, String>> history = const [],
    String? model,
  }) async {
    final callable = _functions.httpsCallable(
      'geminiChat',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final res = await callable.call(<String, dynamic>{
      'message': message,
      if (systemInstruction != null && systemInstruction.isNotEmpty)
        'systemInstruction': systemInstruction,
      'history': history,
      if (model != null && model.isNotEmpty) 'model': model,
    });
    return _readText(res.data);
  }

  static String _readText(dynamic data) {
    if (data is Map && data['text'] != null) return data['text'].toString();
    return '';
  }
}
