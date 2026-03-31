import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/config/env_config.dart';
import '../models/risk_forecast_model.dart';
import 'firebase_service.dart';

/// Service responsible for fetching user historical data and generating
/// a 7-day future mental wellness risk forecast using Gemini 2.5 Flash.
class FutureRiskPredictor {
  final FirebaseService _firebaseService;
  late final GenerativeModel _model;

  FutureRiskPredictor(this._firebaseService) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: EnvConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2, // Low temperature for consistent clinical-style prediction
        maxOutputTokens: 512,
      ),
    );
  }

  /// Gathers historical records, formats them into a timeline, and prompts the AI
  /// for a 7-day trajectory prediction.
  Future<RiskForecastModel> generate7DayForecast() async {
    if (!EnvConfig.hasGeminiKey) {
      throw Exception('Gemini API Key missing for risk forecasting.');
    }

    try {
      // 1. Fetch raw historical data (Last 14 days)
      final rawMoods = await _firebaseService.getMoodHistory(limit: 14);
      
      // We also could fetch "getAssessmentsHistory()" and "getRecentRiskAlerts" 
      // if those endpoints existed for the user. We will use moods as the primary data point.

      // 2. Format timeline into a prompt string
      final sb = StringBuffer();
      sb.writeln('Recent User Mental Health Logs (Latest First):');

      if (rawMoods.isEmpty) {
        // Provide mock data if the account is brand new so the feature can be tested visually
        sb.writeln('- Yesterday: Mood [Tough] Note: "Stressed about work and couldn\'t sleep."');
        sb.writeln('- 2 Days Ago: Mood [Low] Note: "Feeling overwhelmed."');
        sb.writeln('- 3 Days Ago: Mood [Okay] Note: "A bit better but tired."');
        sb.writeln('- 4 Days Ago: Mood [Tough] Note: "Anxiety was high today."');
      } else {
        int index = 0;
        for (var doc in rawMoods) {
          final moodLabel = doc['mood'] ?? 'Unknown';
          final note = doc['note'] ?? 'No context provided';
          sb.writeln('- Entry ${index + 1}: Mood: [$moodLabel], Note: "$note"');
          index++;
        }
      }

      final historicalContext = sb.toString();

      // 3. Prompt Gemini
      final prompt = '''
You are a mental health trajectory analyst. A user has logged their mood and stress over the last several days.
Based on the chronological timeline below, predict their risk of burnout, severe stress, or depressive decline over the NEXT 7 DAYS.

TIMELINE:
$historicalContext

Evaluate the trend: are they improving, stable, or declining?
Consider patterns of "Tough", "Low", or mentions of "sleep", "overwhelmed", "anxiety".

Return ONLY a raw JSON object (no markdown formatting, no code blocks):
{
  "level": "low" | "medium" | "high",
  "trajectory": "improving" | "stable" | "declining",
  "analysis": "A single compassionate paragraph explaining why you predict this trajectory based on their logs.",
  "preventativeTips": ["take a 20 min walk", "try 4-4-4 breathing tonight", etc... (provide 2-3 specific actions)]
}

CLASSIFICATION RULES:
- HIGH / DECLINING: Consistent negative moods, unresolved stress, mentions of lack of sleep or feeling overwhelmed repeatedly.
- MEDIUM / STABLE (or Declining): A mix of okay and tough days, manageable but persistent stress.
- LOW / IMPROVING: Mostly positive moods, resolving stress, optimistic notes.

JSON response only.
''';

      final response = await _model.generateContent([Content.text(prompt)]).timeout(
        const Duration(seconds: 15),
      );

      String jsonStr = response.text?.trim() ?? '';

      // Strip markdown code fences if present
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll('```', '').trim();
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      return RiskForecastModel.fromJson(parsed);

    } catch (e) {
      // Return a safe fallback on error or timeout
      return RiskForecastModel(
        level: FutureRiskLevel.medium,
        trajectory: RiskForecastTrajectory.stable,
        analysisText: 'Could not generate an AI forecast right now. Remember to prioritize self-care and take things one step at a time.',
        preventativeTips: ['Practice deep breathing', 'Disconnect from screens earlier tonight'],
        generatedAt: DateTime.now(),
      );
    }
  }
}
