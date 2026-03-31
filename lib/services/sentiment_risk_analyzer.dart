import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/config/env_config.dart';
import '../core/utils/app_logger.dart';

/// Risk levels returned by the sentiment analyzer.
enum SentimentRiskLevel { low, medium, high }

/// Result of a sentiment risk analysis.
class SentimentRiskResult {
  final SentimentRiskLevel level;
  final double score; // 0.0–1.0
  final String message;
  final List<String> tips;

  const SentimentRiskResult({
    required this.level,
    required this.score,
    required this.message,
    this.tips = const [],
  });
}

/// AI-powered sentiment risk analyzer.
///
/// Analyzes user text for signs of mental distress and returns
/// a risk level (Low / Medium / High) with supportive messaging.
/// Falls back to keyword-based analysis when the API is unavailable.
class SentimentRiskAnalyzer {
  GenerativeModel? _model;

  SentimentRiskAnalyzer() {
    _initialize();
  }

  void _initialize() {
    if (!EnvConfig.hasGeminiKey) return;

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: EnvConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1, // Low temperature for consistent classification
        maxOutputTokens: 256,
      ),
    );
  }

  /// Analyze a user's text and return a risk assessment.
  Future<SentimentRiskResult> analyze(String userText) async {
    if (_model == null) {
      return _fallbackAnalysis(userText);
    }

    try {
      final prompt = '''
You are a mental health risk classifier. Analyze the following user message for signs of psychological distress.

USER MESSAGE:
"$userText"

Classify the risk level and return ONLY a raw JSON object (no markdown, no code blocks):
{
  "level": "low" | "medium" | "high",
  "score": 0.0 to 1.0,
  "message": "A short, empathetic 1-sentence message appropriate for this risk level",
  "tips": ["tip1", "tip2"] (2-3 actionable tips, empty array for low risk)
}

CLASSIFICATION RULES:
- LOW (0.0-0.3): Neutral, positive, or mildly negative emotions. Normal daily stress.
- MEDIUM (0.31-0.7): Notable stress, anxiety, burnout, sleep issues, feeling overwhelmed, loneliness.
- HIGH (0.71-1.0): Severe distress, hopelessness, mentions of self-harm, suicidal ideation, feeling like a burden, wanting to give up on life.

Return ONLY the JSON object. No other text.
''';

      final response = await _model!
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 8));

      String jsonStr = response.text?.trim() ?? '';
      
      // Strip markdown code fences if present
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll('```', '').trim();
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final levelStr = (parsed['level'] as String? ?? 'low').toLowerCase();
      final score = (parsed['score'] as num?)?.toDouble() ?? 0.0;
      final message = parsed['message'] as String? ?? '';
      final tips = (parsed['tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      SentimentRiskLevel level;
      switch (levelStr) {
        case 'high':
          level = SentimentRiskLevel.high;
          break;
        case 'medium':
          level = SentimentRiskLevel.medium;
          break;
        default:
          level = SentimentRiskLevel.low;
      }

      return SentimentRiskResult(
        level: level,
        score: score.clamp(0.0, 1.0),
        message: message.isNotEmpty ? message : _defaultMessage(level),
        tips: tips,
      );
    } catch (e, stack) {
      AppLogger.error(
        'SentimentRiskAnalyzer',
        'AI analysis failed, using fallback',
        e,
        stack,
      );
      return _fallbackAnalysis(userText);
    }
  }

  /// Keyword-based fallback when Gemini is unavailable.
  SentimentRiskResult _fallbackAnalysis(String text) {
    final lower = text.toLowerCase();

    // ─── HIGH RISK keywords ─────────────────────────────
    final highRiskPatterns = [
      'suicide', 'suicidal', 'kill myself', 'end my life', 'end it all',
      'want to die', 'wanna die', 'don\'t want to live', 'no reason to live',
      'better off dead', 'self harm', 'self-harm', 'hurt myself',
      'cutting myself', 'overdose', 'can\'t go on', 'give up on life',
    ];

    for (final pattern in highRiskPatterns) {
      if (lower.contains(pattern)) {
        return const SentimentRiskResult(
          level: SentimentRiskLevel.high,
          score: 0.95,
          message: 'Please reach out to a helpline immediately. You are not alone.',
          tips: [
            'Call or text 988 (Suicide & Crisis Lifeline)',
            'Text HOME to 741741 (Crisis Text Line)',
            'Call 911 for immediate danger',
          ],
        );
      }
    }

    // ─── MEDIUM RISK keywords ───────────────────────────
    final mediumRiskPatterns = [
      'stressed', 'stress', 'can\'t sleep', 'insomnia', 'anxious', 'anxiety',
      'overwhelmed', 'burnout', 'burned out', 'depressed', 'depression',
      'hopeless', 'isolated', 'lonely', 'exhausted', 'can\'t cope',
      'panic', 'crying', 'can\'t stop crying', 'breaking down', 'falling apart',
      'worthless', 'no energy', 'can\'t focus', 'lost motivation',
      'feel empty', 'numb', 'struggling', 'miserable', 'dread',
    ];

    int mediumHits = 0;
    for (final pattern in mediumRiskPatterns) {
      if (lower.contains(pattern)) mediumHits++;
    }

    if (mediumHits >= 2) {
      return SentimentRiskResult(
        level: SentimentRiskLevel.medium,
        score: 0.55,
        message: 'You seem to be going through a tough time. Here are some things that might help.',
        tips: [
          'Try the 4-4-4 breathing exercise below',
          'Reach out to a friend or family member',
          'Consider speaking with a therapist',
        ],
      );
    }

    if (mediumHits == 1) {
      return SentimentRiskResult(
        level: SentimentRiskLevel.medium,
        score: 0.35,
        message: 'You seem stressed. Remember, it\'s okay to take a break.',
        tips: [
          'Take a 5-minute walk or stretch',
          'Practice deep breathing for 2 minutes',
        ],
      );
    }

    // ─── LOW RISK ───────────────────────────────────────
    return const SentimentRiskResult(
      level: SentimentRiskLevel.low,
      score: 0.1,
      message: 'You\'re doing okay. Keep going! 💙',
      tips: [],
    );
  }

  String _defaultMessage(SentimentRiskLevel level) {
    switch (level) {
      case SentimentRiskLevel.high:
        return 'Please reach out to a helpline immediately. You are not alone.';
      case SentimentRiskLevel.medium:
        return 'You seem stressed. Here are some tips to help you feel better.';
      case SentimentRiskLevel.low:
        return 'You\'re doing okay. Keep going! 💙';
    }
  }

  void dispose() {
    _model = null;
  }
}
