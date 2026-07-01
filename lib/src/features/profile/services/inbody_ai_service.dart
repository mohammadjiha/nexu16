import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gemini_proxy_service.dart';

/// Parses InBody / body-composition scans via the secure server-side Gemini
/// proxy. The API key never reaches the client.
class InBodyAiService {
  Future<Map<String, dynamic>> parseInBodyFile({
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    try {
      const prompt = '''
        Analyze this body composition (InBody/TANITA) scan from an image, PDF, or document file.
        Extract the following data points exactly as numbers (no text, no units).
        If a data point is missing, return 0.0.
        Respond ONLY with a valid JSON object matching this exact format:
        {
          "weight": 0.0,
          "height": 0.0,
          "bodyFat": 0.0,
          "muscleMass": 0.0,
          "fatFreeMass": 0.0,
          "water": 0.0,
          "bmr": 0.0,
          "visceralFat": 0.0,
          "metabolicAge": 0.0
        }
      ''';

      final text = await GeminiProxy.generate(
        prompt: prompt,
        fileBytes: fileBytes,
        mimeType: mimeType,
        jsonOnly: true,
      );

      if (text.isEmpty) {
        throw Exception('AI returned empty response');
      }

      final cleaned =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse InBody scan: $e');
    }
  }

  String mimeTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}

final inbodyAiServiceProvider = Provider<InBodyAiService>((ref) {
  return InBodyAiService();
});
