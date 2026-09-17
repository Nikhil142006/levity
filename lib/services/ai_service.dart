import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

final aiServiceProvider = Provider((ref) {
  return AiService(); 
});

class AiService {
  Future<String> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key') ?? const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }
  
  Future<GenerativeModel> _getModel() async {
    final key = await _getApiKey();
    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: key,
      systemInstruction: Content.system("You are a personalized health and fitness AI coach. Be concise, actionable, and warm.")
    );
  }

  Future<List<String>> getSuggestions(String uid) async {
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      return [
        "How can I improve my sleep tonight?",
        "Analyze my step count trend this week.",
        "What's a good post-workout meal?",
      ];
    }
    try {
      final prompt = "Generate exactly 3 short, actionable, and engaging questions or prompt suggestions that the user can tap to ask you. Return them as a simple JSON array of strings. For example: [\"How can I increase my daily steps?\", \"Analyze my calorie deficit.\", \"Tips for better sleep.\"]";
      
      final content = [Content.text(prompt)];
      final model = await _getModel();
      final response = await model.generateContent(
        content,
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );
      
      if (response.text != null) {
        final List<dynamic> data = jsonDecode(response.text!);
        return List<String>.from(data);
      }
      return [];
    } catch (e) {
      print('Failed to get AI suggestions: $e');
      return [
        "How can I improve my sleep tonight?",
        "Analyze my step count trend this week.",
        "What's a good post-workout meal?",
      ];
    }
  }

  Future<String> sendChatMessage(String uid, List<Map<String, String>> history, String message) async {
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      return "I'm currently running in offline mock mode. Please tap the Settings icon in the top right to paste your Gemini API Key!";
    }
    try {
      List<Content> contents = [];
      for (var msg in history) {
        if (msg['role'] == 'user') {
          contents.add(Content.text(msg['text'] ?? ''));
        } else {
          contents.add(Content.model([TextPart(msg['text'] ?? '')]));
        }
      }
      contents.add(Content.text(message));

      final model = await _getModel();
      final response = await model.generateContent(contents);
      return response.text ?? 'No response';
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }
}
