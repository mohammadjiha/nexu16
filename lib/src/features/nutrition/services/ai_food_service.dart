import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gemini_proxy_service.dart';

final aiFoodServiceProvider = Provider<AIFoodService>((ref) {
  return AIFoodService();
});

/// Analyzes food images via the secure server-side Gemini proxy. The API key
/// never reaches the client.
class AIFoodService {
  Future<Map<String, dynamic>?> analyzeFoodImage(Uint8List imageBytes) async {
    const prompt = '''
You are an expert nutritionist. Analyze this image of food.
Identify the food and estimate its nutritional values.
If there are reference objects in the image, use them to estimate the total weight in grams.
Provide the output strictly in the following JSON format without markdown wrapping:
{
  "food_name": "Name of the food in English",
  "estimated_weight_g": 250,
  "per_100g": {
    "calories": 150,
    "protein_g": 10.5,
    "carbs_g": 20.0,
    "fat_g": 5.0
  },
  "total_estimated": {
    "calories": 375,
    "protein_g": 26.25,
    "carbs_g": 50.0,
    "fat_g": 12.5
  }
}
If it is not food, return an error JSON: {"error": "No food detected"}
''';

    try {
      final text = await GeminiProxy.generate(
        prompt: prompt,
        fileBytes: imageBytes,
        mimeType: 'image/jpeg',
        jsonOnly: true,
      );
      if (text.isNotEmpty) {
        final cleaned =
            text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleaned) as Map<String, dynamic>;
      }
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
    return null;
  }
}
