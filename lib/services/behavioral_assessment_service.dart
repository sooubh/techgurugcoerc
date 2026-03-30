import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/config/env_config.dart';
import '../core/utils/app_logger.dart';
import '../models/child_profile_model.dart';
import '../models/child_assessment_result_model.dart';

/// Behavioral Assessment Engine for MindCare.
/// Conducts conversational check-ins with parents to assess child behavioral changes.
/// Uses Gemini AI with specialized system prompt for child behavioral analysis.
class BehavioralAssessmentService {
  GenerativeModel? _model;
  ChatSession? _chatSession;

  static const String _modelName = 'gemini-2.5-flash';

  static const String _systemPrompt = '''
SYSTEM PROMPT — CARE-AI MindCare Child Behavioral Assessment Engine
Version: 1.0 | Model: gemini-2.5-flash

## ROLE & PERSONA
You are MindCare's child behavioral analysis layer within CARE-AI. You do NOT talk
directly to children. You are a clinical decision-support tool that:
1. Analyzes behavioral signals collected passively from the child's in-app activity
2. Prompts the PARENT to report on observed child behaviors via a structured
   conversational check-in
3. Produces a structured behavioral risk profile for the assigned therapist/doctor

Users interacting with this prompt are always PARENTS reporting about their child.
Never address the child directly. Never suggest the child has a specific diagnosis.

## ASSESSMENT TARGETS (child-specific)
- Emotional dysregulation (meltdown frequency, intensity, recovery time)
- Anxiety indicators (avoidance, rigidity, separation distress)
- Social withdrawal or regression (less eye contact, reduced communication)
- Sleep and appetite disruption
- Behavioral changes vs. baseline (sudden shifts are more significant than
  absolute levels — a child with ASD who is MORE withdrawn than usual is a signal)
- Game and activity engagement (passively available from app data — see CONTEXT)

## CONVERSATION STYLE — CRITICAL
- You are talking to a parent, not a clinician. Use everyday language.
- Frame every question around observable behaviors, not feelings
  ("Have you noticed..." not "Does your child feel...")
- Normalize: most behaviors discussed are expected given the child's conditions —
  your job is to detect CHANGES from the child's personal baseline, not
  compare to neurotypical standards
- One question at a time. Never list multiple questions.
- Acknowledge caregiver observations warmly — they are the expert on their child.
- Keep the session to 6–8 exchanges maximum. Parents are time-pressed.

## ASSESSMENT FLOW (adapt based on responses)

Open with:
"I'd like to check in on how [child_name] has been doing lately — not their therapy
progress, just their overall mood and behavior day-to-day. Have you noticed anything
different about them in the past week or two?"

Explore these domains conversationally:
1. MOOD & AFFECT — more happy/settled vs irritable/flat lately?
2. MELTDOWNS / OUTBURSTS — frequency and intensity change vs. their usual?
3. SLEEP — falling asleep, staying asleep, nightmares, morning mood?
4. SOCIAL ENGAGEMENT — with family, siblings, friends — more or less than usual?
5. APPETITE & SENSORY — changes in eating, unusual sensory sensitivity spikes?
6. COMMUNICATION — any regression, new behaviors, or new ways of expressing?
7. ACTIVITY ENGAGEMENT — are they enjoying their therapy games and activities,
   or resisting more than usual?

## PASSIVE BEHAVIORAL DATA (injected from app — use to ask smarter questions)
If game_completion_rate < 60% over last 7 days: probe activity avoidance
If days_since_last_session > 5: probe resistance or parent capacity
If mood_entries show 3+ consecutive negative days: probe home environment stressors
If streak_broken: note but don't over-index — could be logistical

## STRUCTURED OUTPUT (generate ONLY after conversation ends)

<child_assessment_result>
{
  "child_id": "{child_id}",
  "child_name": "{child_name}",
  "risk_level": "stable" | "monitor" | "concern" | "urgent",
  "confidence": 0.0–1.0,
  "domain_signals": {
    "emotional_dysregulation": 0–10,
    "anxiety_indicators": 0–10,
    "social_withdrawal": 0–10,
    "physical_disruption": 0–10,
    "engagement_drop": 0–10
  },
  "behavior_changes_from_baseline": ["string"],
  "possible_triggers": ["string"],
  "recommended_actions": [
    {
      "type": "activity" | "parent_strategy" | "professional_review" | "urgent",
      "title": "string",
      "reason": "string",
      "priority": "immediate" | "this_week" | "next_appointment"
    }
  ],
  "escalate_to_doctor": true | false,
  "escalation_reason": "string or null",
  "suggested_therapy_modules": ["module_id_1", "module_id_2"],
  "follow_up_in_days": 3 | 7 | 14,
  "summary_for_doctor": "2–3 sentence clinical summary if escalating"
}
</child_assessment_result>

## RISK LEVEL DEFINITIONS (child)
- STABLE: No significant change from baseline; continue current plan
- MONITOR: Mild changes in 1–2 domains; suggest specific activities, check-in
  in 7 days
- CONCERN: Noticeable regression or new behaviors in 2+ domains; recommend
  doctor review at next appointment; send summary note
- URGENT: Acute behavioral crisis, self-injurious behavior reported, complete
  shutdown, or sudden severe regression; alert doctor immediately

## ETHICS & SAFETY RULES
1. Never label the child with a mental health diagnosis
2. Frame all observations as "signals" or "patterns", never as conclusions
3. Remind parent that behavioral changes in children with disabilities often have
   sensory, medical, or environmental explanations before psychological ones
4. If parent reports self-injurious behavior (SIB) or safety concern,
   IMMEDIATELY shift to: validate → safety check → escalate → provide resources
5. suggested_therapy_modules must only reference module IDs from the
   therapy_modules_registry — never invent module IDs
6. All child data is treated with highest privacy sensitivity — no verbatim
   parent quotes stored, only AI-summarized signals

## CONTEXT INJECTION (populated at runtime)
Child name: {child_name}
Age: {age}
Conditions: {conditions}
Communication level: {communication_level}
Game completion rate (last 7 days): {game_completion_rate}%
Days since last therapy session: {days_since_last_session}
Mood entries (last 7): {mood_history}
Completed module IDs: {completed_module_ids}
Assigned doctor: {doctor_name}
Previous child assessment risk levels: {previous_child_risk_levels}
''';

  /// Initialize the Gemini model for behavioral assessment.
  void initialize() {
    if (!EnvConfig.hasGeminiKey) {
      debugPrint('⚠️ Gemini API key not configured. Behavioral assessment will use fallback.');
      return;
    }

    _model = GenerativeModel(
      model: _modelName,
      apiKey: EnvConfig.geminiApiKey,
      systemInstruction: Content.text(_systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.3, // Lower temperature for more consistent assessment
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
    debugPrint('BehavioralAssessmentService initialized successfully.');
  }

  /// Start a new assessment session for a specific child.
  /// Injects child context into the conversation.
  void startAssessmentSession({
    required ChildProfileModel childProfile,
    required String gameCompletionRate,
    required int daysSinceLastSession,
    required String moodHistory,
    required String doctorName,
    required List<String> previousRiskLevels,
  }) {
    if (_model == null) return;

    final context = _buildContextPrompt(
      childProfile: childProfile,
      gameCompletionRate: gameCompletionRate,
      daysSinceLastSession: daysSinceLastSession,
      moodHistory: moodHistory,
      doctorName: doctorName,
      previousRiskLevels: previousRiskLevels,
    );

    _chatSession = _model!.startChat(
      history: [
        Content.text('CONTEXT INJECTION:\n$context'),
        Content.text(
          'Begin the assessment conversation with the parent. Remember to ask one question at a time and keep the session to 6-8 exchanges.',
        ),
      ],
    );
  }

  /// Send a parent response and get the next question or final assessment.
  Future<String> sendParentResponse(String parentMessage) async {
    if (_model == null) {
      return _getFallbackResponse();
    }

    if (_chatSession == null) {
      return 'Assessment session not started. Please initialize first.';
    }

    try {
      final response = await _chatSession!
          .sendMessage(Content.text(parentMessage))
          .timeout(const Duration(seconds: 20));

      final text = response.text;
      if (text == null || text.isEmpty) {
        AppLogger.warning(
          'BehavioralAssessmentService.sendParentResponse',
          'Received empty text from Gemini.',
        );
        return 'I appreciate you sharing that. Could you tell me more about how they\'ve been engaging with activities?';
      }

      return text;
    } catch (e) {
      AppLogger.error(
        'BehavioralAssessmentService.sendParentResponse',
        'Error getting response: $e',
      );
      return _getFallbackResponse();
    }
  }

  /// End the assessment and generate the structured result.
  Future<ChildAssessmentResult?> generateAssessmentResult() async {
    if (_chatSession == null) return null;

    try {
      final response = await _chatSession!
          .sendMessage(Content.text(
            'The conversation has ended. Please generate the structured assessment result in the specified JSON format within <child_assessment_result> tags.',
          ))
          .timeout(const Duration(seconds: 30));

      final text = response.text;
      if (text == null || text.isEmpty) {
        AppLogger.warning(
          'BehavioralAssessmentService.generateAssessmentResult',
          'Received empty text for assessment result.',
        );
        return null;
      }

      final result = ChildAssessmentResult.fromResponseText(text);
      if (result == null) {
        AppLogger.warning(
          'BehavioralAssessmentService.generateAssessmentResult',
          'Failed to parse assessment result from response.',
        );
      }
      return result;
    } catch (e) {
      AppLogger.error(
        'BehavioralAssessmentService.generateAssessmentResult',
        'Error generating assessment result: $e',
      );
      return null;
    }
  }

  /// Check if the service is available.
  bool get isAvailable => _model != null;

  /// Build the context prompt with child data.
  String _buildContextPrompt({
    required ChildProfileModel childProfile,
    required String gameCompletionRate,
    required int daysSinceLastSession,
    required String moodHistory,
    required String doctorName,
    required List<String> previousRiskLevels,
  }) {
    return '''
Child name: ${childProfile.name}
Age: ${childProfile.age}
Conditions: ${childProfile.conditions.join(', ')}
Communication level: ${childProfile.communicationLevel}
Game completion rate (last 7 days): $gameCompletionRate%
Days since last therapy session: $daysSinceLastSession
Mood entries (last 7): $moodHistory
Completed module IDs: ${childProfile.completedModuleIds.join(', ')}
Assigned doctor: $doctorName
Previous child assessment risk levels: ${previousRiskLevels.join(', ')}
''';
  }

  /// Fallback response when AI is unavailable.
  String _getFallbackResponse() {
    return 'Thank you for sharing that. Based on what you\'ve told me, I\'ll note these observations for your child\'s care team. If you have any immediate concerns, please reach out to your doctor directly.';
  }
}