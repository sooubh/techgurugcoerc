import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/env_config.dart';
import '../../../services/sentiment_risk_analyzer.dart';
import '../../../services/future_risk_predictor.dart';
import '../../../services/firebase_service.dart';
import '../../../models/risk_forecast_model.dart';
import '../../../models/activity_log_model.dart';
import 'crisis_support_screen.dart';

/// Adult Mental Health Screen — mood tracker, AI feelings chat,
/// affirmations, self-care tips, breathing exercises, and support resources
/// tailored for adult mental wellness.
class AdultWellnessScreen extends StatefulWidget {
  const AdultWellnessScreen({super.key});

  @override
  State<AdultWellnessScreen> createState() => _AdultWellnessScreenState();
}

class _AdultWellnessScreenState extends State<AdultWellnessScreen> {
  int? _selectedMood;
  bool _isBreathing = false;
  String _breathLabel = 'Start';
  Timer? _breathTimer;
  int _breathCycle = 0;

  // ─── Chat State ───────────────────────────────────────────
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_FeelingMsg> _chatMessages = [];
  bool _isChatLoading = false;
  bool _chatExpanded = false;
  GenerativeModel? _chatModel;
  ChatSession? _chatSession;

  // ─── Risk Analyzer State ──────────────────────────────────
  late final SentimentRiskAnalyzer _riskAnalyzer;

  // ─── Risk Forecast State ──────────────────────────────────
  late final FutureRiskPredictor _riskPredictor;
  bool _isForecasting = false;
  RiskForecastModel? _forecastModel;

  static const _moodKey = 'adult_wellness_mood';
  static const _moodDateKey = 'adult_wellness_mood_date';

  // ─── Adult Wellness AI System Prompt ──────────────────────
  static const String _wellnessSystemPrompt = '''
You are a warm, empathetic AI mental wellness companion for adults. Your role is to:

1. Listen actively and validate the user's feelings without judgment.
2. Provide supportive, evidence-based coping strategies.
3. Use a calm, reassuring tone — like a trusted friend who also happens to be well-informed.
4. NEVER diagnose mental health conditions or prescribe medication.
5. For severe distress, self-harm, or suicidal ideation, ALWAYS urge the user to contact:
   - 988 Suicide & Crisis Lifeline (call/text 988)
   - Emergency services (911)
6. Keep responses concise (2-4 sentences unless the user asks for more detail).
7. Use Markdown for readability: **bold** for emphasis, bullet points for lists.
8. Suggest practical micro-actions the user can take right now.
9. End with an encouraging, forward-looking statement when appropriate.
10. Remember: you are NOT a therapist. You are a supportive companion.

DISCLAIMER: Always gently remind the user that your support supplements but does not replace professional mental health care.
''';

  // ─── Mood Emojis ──────────────────────────────────────────
  static const _moods = [
    {'emoji': '😊', 'label': 'Great'},
    {'emoji': '🙂', 'label': 'Good'},
    {'emoji': '😐', 'label': 'Okay'},
    {'emoji': '😟', 'label': 'Low'},
    {'emoji': '😫', 'label': 'Tough'},
  ];

  // ─── Affirmations (adult-focused) ─────────────────────────
  static const _affirmations = [
    'You are worthy of peace, rest, and happiness — no matter what today brings.',
    'It\'s okay to not have it all figured out. Growth is a process, not a race.',
    'You are allowed to set boundaries that protect your mental health.',
    'Your feelings are valid. Taking time for yourself is not selfish — it\'s necessary.',
    'Every small step forward counts. You are stronger than yesterday.',
    'You don\'t have to carry everything alone. Asking for help is a sign of courage.',
    'Today is a new chapter. You have the power to write it your way.',
    'You are doing better than you think. Celebrate how far you\'ve come.',
  ];

  // ─── Self-Care Tips (adult-focused) ───────────────────────
  static const _selfCareTips = [
    {
      'icon': Icons.bedtime_rounded,
      'title': 'Quality Sleep',
      'tip':
          'Aim for 7–9 hours of sleep. Create a wind-down routine: dim lights, avoid screens 30 min before bed.',
      'color': Color(0xFF6366F1),
    },
    {
      'icon': Icons.fitness_center_rounded,
      'title': 'Stay Active',
      'tip':
          'Even 20 minutes of moderate exercise — a brisk walk, yoga, or stretching — can significantly reduce anxiety.',
      'color': Color(0xFF10B981),
    },
    {
      'icon': Icons.self_improvement_rounded,
      'title': 'Practice Mindfulness',
      'tip':
          'Spend 5–10 minutes daily in meditation or deep breathing. Mindfulness rewires your brain for calm.',
      'color': Color(0xFFF59E0B),
    },
    {
      'icon': Icons.water_drop_rounded,
      'title': 'Hydrate & Nourish',
      'tip':
          'Dehydration worsens mood and focus. Drink 8 glasses of water and eat balanced, nutrient-rich meals.',
      'color': Color(0xFF06B6D4),
    },
    {
      'icon': Icons.people_rounded,
      'title': 'Social Connection',
      'tip':
          'Loneliness impacts mental health deeply. Schedule regular check-ins with friends, family, or a therapist.',
      'color': Color(0xFFEC4899),
    },
    {
      'icon': Icons.auto_stories_rounded,
      'title': 'Journaling',
      'tip':
          'Write down your thoughts, gratitude, or worries. Journaling helps process emotions and gain clarity.',
      'color': Color(0xFF8B5CF6),
    },
  ];

  // ─── Suggested Chat Prompts ───────────────────────────────
  static const _suggestedPrompts = [
    'I\'m feeling stressed and can\'t sleep',
    'I feel anxious about work',
    'I\'m overwhelmed and need a break',
    'Help me calm down right now',
  ];

  @override
  void initState() {
    super.initState();
    _loadMood();
    _initChatModel();
    _riskAnalyzer = SentimentRiskAnalyzer();
    _riskPredictor = FutureRiskPredictor(FirebaseService());
  }

  @override
  void dispose() {
    _breathTimer?.cancel();
    _riskAnalyzer.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initChatModel() {
    if (!EnvConfig.hasGeminiKey) return;
    
    _chatModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: EnvConfig.geminiApiKey,
      systemInstruction: Content.text(_wellnessSystemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.8,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 512,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );

    _chatSession = _chatModel!.startChat(history: []);
  }

  Future<void> _loadMood() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_moodDateKey);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (savedDate == today) {
      setState(() => _selectedMood = prefs.getInt(_moodKey));
    }
  }

  Future<void> _saveMood(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setInt(_moodKey, index);
    await prefs.setString(_moodDateKey, today);
    setState(() => _selectedMood = index);

    try {
      final firebaseService = FirebaseService();
      await firebaseService.logActivity(
        ActivityLogModel(
          activityId: 'mood_checkin_$today',
          activityTitle: 'Mood: ${_moods[index]['label']}',
          category: 'Wellness',
          durationSeconds: 30,
          stepsCompleted: 1,
          completedAt: DateTime.now(),
          isAdult: true,
        ),
      );
    } catch (_) {}
  }

  void _startBreathingExercise() {
    if (_isBreathing) {
      _breathTimer?.cancel();
      setState(() {
        _isBreathing = false;
        _breathLabel = 'Start';
        _breathCycle = 0;
      });
      return;
    }

    setState(() {
      _isBreathing = true;
      _breathCycle = 0;
    });

    _runBreathCycle();
  }

  void _runBreathCycle() {
    if (_breathCycle >= 5) {
      setState(() {
        _isBreathing = false;
        _breathLabel = 'Done! 🎉';
        _breathCycle = 0;
      });
      
      try {
        final firebaseService = FirebaseService();
        firebaseService.logActivity(
          ActivityLogModel(
            activityId: 'breathing_exercise_${DateTime.now().millisecondsSinceEpoch}',
            activityTitle: 'Breathing Exercise',
            category: 'Mindfulness',
            durationSeconds: 60,
            stepsCompleted: 5,
            completedAt: DateTime.now(),
            isAdult: true,
          ),
        );
      } catch (_) {}

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _breathLabel = 'Start');
      });
      return;
    }

    setState(() => _breathLabel = 'Breathe In...');
    _breathTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _breathLabel = 'Hold...');
      _breathTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _breathLabel = 'Breathe Out...');
        _breathTimer = Timer(const Duration(seconds: 4), () {
          if (!mounted) return;
          setState(() => _breathCycle++);
          _runBreathCycle();
        });
      });
    });
  }

  // ─── AI Forecast Method ───────────────────────────────────
  Future<void> _generateForecast() async {
    setState(() => _isForecasting = true);
    try {
      final forecast = await _riskPredictor.generate7DayForecast();
      if (mounted) {
        setState(() => _forecastModel = forecast);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate forecast. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isForecasting = false);
      }
    }
  }

  // ─── Chat Methods ─────────────────────────────────────────
  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _chatController.text).trim();
    if (text.isEmpty || _isChatLoading) return;

    _chatController.clear();

    setState(() {
      _chatMessages.add(_FeelingMsg(text: text, isUser: true));
      _isChatLoading = true;
      _chatExpanded = true;
    });
    _scrollChatToBottom();

    // Run risk analysis in parallel with AI response
    _riskAnalyzer.analyze(text).then((result) {
      if (!mounted) return;
      setState(() {
        // Associate risk result with the user message
        final userMsgIndex = _chatMessages.lastIndexWhere((m) => m.isUser && m.text == text);
        if (userMsgIndex != -1) {
          _chatMessages[userMsgIndex] = _FeelingMsg(
            text: text,
            isUser: true,
            riskResult: result,
          );
        }
      });
      _scrollChatToBottom();

      // Trigger crisis bottom sheet for high risk
      if (result.level == SentimentRiskLevel.high) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            // Fake alert to doctor as requested
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ High Risk Detected: Alert auto-sent to your connected doctor.'),
                backgroundColor: Color(0xFFDC2626), // AppColors.error
                duration: Duration(seconds: 4),
              ),
            );

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const CrisisSupportBottomSheet(),
            );
          }
        });
      }
    });

    try {
      if (_chatSession == null) {
        // Fallback when API key not available
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _chatMessages.add(_FeelingMsg(
            text: _getFallbackResponse(text),
            isUser: false,
          ));
          _isChatLoading = false;
        });
        _scrollChatToBottom();
        return;
      }

      // Stream the AI response
      final responseStream = _chatSession!.sendMessageStream(Content.text(text));
      
      // Add placeholder for AI response
      final aiMsgIndex = _chatMessages.length;
      setState(() {
        _chatMessages.add(const _FeelingMsg(text: '', isUser: false));
      });

      String fullResponse = '';
      await for (final chunk in responseStream) {
        if (!mounted) return;
        final chunkText = chunk.text;
        if (chunkText != null && chunkText.isNotEmpty) {
          fullResponse += chunkText;
          setState(() {
            _chatMessages[aiMsgIndex] = _FeelingMsg(text: fullResponse, isUser: false);
          });
          _scrollChatToBottom();
        }
      }

      if (fullResponse.isEmpty) {
        setState(() {
          _chatMessages[aiMsgIndex] = _FeelingMsg(
            text: _getFallbackResponse(text),
            isUser: false,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chatMessages.add(_FeelingMsg(
          text: _getFallbackResponse(text),
          isUser: false,
        ));
      });
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
      _scrollChatToBottom();
    }
  }

  String _getFallbackResponse(String userMessage) {
    final lower = userMessage.toLowerCase();

    if (lower.contains('stress') || lower.contains('overwhelm') || lower.contains('pressure')) {
      return "I hear you — stress can feel all-consuming. Here are a few things you can do **right now**:\n\n"
          "• 🫁 Try the **4-4-4 breathing exercise** below\n"
          "• 🚶 Step outside for a 5-minute walk\n"
          "• 📝 Write down 3 things you can control today\n\n"
          "You're doing your best, and that's enough. 💙\n\n"
          "_This is not professional advice. If you're struggling, please reach out to a therapist or call 988._";
    }

    if (lower.contains('sleep') || lower.contains('insomnia') || lower.contains('can\'t sleep')) {
      return "Sleep struggles are tough. Here are a few evidence-based tips:\n\n"
          "• 🌙 Keep a **consistent sleep schedule** — even on weekends\n"
          "• 📵 Avoid screens **30 min before bed**\n"
          "• 🧘 Try a **body scan meditation** in bed\n"
          "• ☕ No caffeine after **2 PM**\n\n"
          "Be patient with yourself — better sleep comes with practice. 💙\n\n"
          "_If insomnia persists, consider speaking with a healthcare provider._";
    }

    if (lower.contains('anxious') || lower.contains('anxiety') || lower.contains('panic') || lower.contains('worry')) {
      return "Anxiety can feel overwhelming, but you have more power over it than you think:\n\n"
          "• 🧊 Try the **5-4-3-2-1 grounding technique**: name 5 things you see, 4 you feel, 3 you hear, 2 you smell, 1 you taste\n"
          "• 🫁 Use the **breathing exercise** on this page\n"
          "• ✍️ Write down your worry, then ask: *\"Can I control this right now?\"*\n\n"
          "You're not alone in this. One moment at a time. 💙\n\n"
          "_This is supportive guidance, not a substitute for professional care._";
    }

    if (lower.contains('sad') || lower.contains('depress') || lower.contains('hopeless') || lower.contains('lonely')) {
      return "I'm really glad you shared that. Your feelings are valid and important.\n\n"
          "• 💛 Reach out to someone you trust today — even a short text counts\n"
          "• 🌤️ Try to get some **natural sunlight** for 10–15 minutes\n"
          "• 📖 Write down **one thing** you're grateful for, no matter how small\n\n"
          "If these feelings persist, please talk to a professional. You deserve support. 💙\n\n"
          "_If you're in crisis, call or text **988** anytime._";
    }

    return "Thank you for sharing how you feel. That takes courage. Here are some general tips:\n\n"
        "• 🫁 Take 3 deep breaths right now\n"
        "• 📝 Name what you're feeling — labeling emotions reduces their intensity\n"
        "• 🤝 Consider speaking with someone you trust\n"
        "• 💧 Drink a glass of water and take a short break\n\n"
        "I'm here to listen whenever you need. 💙\n\n"
        "_Remember: this is not a substitute for professional guidance._";
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final affirmation =
        _affirmations[DateTime.now().day % _affirmations.length];

    return Scaffold(
      appBar: AppBar(title: const Text('Adult Mental Health')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Mood Check-In ──────────────────────────
            _buildMoodCheckIn(context, isDark),
            const SizedBox(height: 24),

            // ─── AI Wellness Forecast ───────────────────
            _buildForecastCard(context, isDark),
            if (_forecastModel != null || _isForecasting) const SizedBox(height: 24),

            // ─── Mental Health Self-Assessment ──────────
            _buildMentalHealthAssessment(context, isDark),
            const SizedBox(height: 24),

            // ─── Stress Level Check-in ──────────────────
            _buildStressCheckIn(context, isDark),
            const SizedBox(height: 24),

            // ─── Feelings Chat ──────────────────────────
            _buildFeelingsChat(context, isDark),
            const SizedBox(height: 24),

            // ─── Daily Affirmation ──────────────────────
            _buildAffirmation(context, isDark, affirmation),
            const SizedBox(height: 24),

            // ─── Breathing Exercise ─────────────────────
            _buildBreathingExercise(context, isDark),
            const SizedBox(height: 24),

            // ─── Self-Care Tips ─────────────────────────
            _sectionTitle(context, 'Self-Care Tips'),
            const SizedBox(height: 12),
            _buildSelfCareTips(context, isDark),
            const SizedBox(height: 24),

            // ─── Support Resources ──────────────────────
            _sectionTitle(context, 'Support Resources'),
            const SizedBox(height: 12),
            _buildResources(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ═════════════════════════════════════════════════════════
  // MOOD CHECK-IN
  // ═════════════════════════════════════════════════════════
  Widget _buildMoodCheckIn(BuildContext context, bool isDark) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'How are you feeling today?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:
                    _moods.asMap().entries.map((entry) {
                      final index = entry.key;
                      final mood = entry.value;
                      final isSelected = _selectedMood == index;
                      return GestureDetector(
                        onTap: () => _saveMood(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                mood['emoji']!,
                                style: TextStyle(
                                  fontSize: isSelected ? 30 : 26,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mood['label']!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
              if (_selectedMood != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _selectedMood! <= 1
                        ? '💙 Great to hear! Keep nurturing that positive energy.'
                        : _selectedMood == 2
                        ? '💙 That\'s okay. Be gentle with yourself today.'
                        : '💙 Tough days pass. You\'re not alone — reach out if you need support.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.05, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  // ═════════════════════════════════════════════════════════
  // MENTAL HEALTH SELF-ASSESSMENT
  // ═════════════════════════════════════════════════════════
  Widget _buildMentalHealthAssessment(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFF0EA5E9), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Adult Therapy & Mental Health Self-Check',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Take a quick 2-minute self-assessment to track your mental wellbeing and discover personalized coping strategies.',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/mental-health-assessment');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Start Self-Check'),
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 500.ms, delay: 100.ms)
    .slideY(begin: 0.05, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  // ═════════════════════════════════════════════════════════
  // STRESS CHECK-IN
  // ═════════════════════════════════════════════════════════
  Widget _buildStressCheckIn(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A3A4A), const Color(0xFF2A6070)]
              : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF1A3A4A) : const Color(0xFFE0F2FE)).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_rounded,
                color: isDark ? Colors.white : const Color(0xFF0369A1),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Stress & Anxiety Check-in',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0369A1),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Take a few minutes to reflect on your stress levels. Understand your triggers and get personalized tips to manage anxiety effectively.',
            style: TextStyle(
              color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF0369A1).withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/behavioral-assessment');
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Start Check-in'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF0EA5E9) : Colors.white,
                foregroundColor: isDark ? Colors.white : const Color(0xFF0369A1),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 500.ms, delay: 200.ms)
    .slideY(begin: 0.05, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  // ═════════════════════════════════════════════════════════
  // FEELINGS CHAT (AI-powered)
  // ═════════════════════════════════════════════════════════
  Widget _buildFeelingsChat(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.3)
              : const Color(0xFF0EA5E9).withValues(alpha: 0.15),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Talk About Your Feelings (Chat Input & AI Risk Detector)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI Wellness Companion • Always here',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_chatMessages.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _chatMessages.clear();
                        _chatExpanded = false;
                        // Re-create session for fresh conversation
                        if (_chatModel != null) {
                          _chatSession = _chatModel!.startChat(history: []);
                        }
                      });
                    },
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                    tooltip: 'Clear chat',
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Disclaimer Banner ────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5)
                  : AppColors.warningLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.2)
                    : AppColors.warning.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: AppColors.warning, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI companion, not a therapist. For emergencies, call 988.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Chat Messages ────────────────────────
          if (_chatMessages.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _chatExpanded ? 380 : 0,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildChatBubble(context, msg, isDark, index),
                      // Show risk indicator after user messages that have a risk result
                      if (msg.isUser && msg.riskResult != null)
                        _buildRiskIndicator(context, msg.riskResult!, isDark),
                    ],
                  );
                },
              ),
            ),

          // ─── Suggested Prompts (when no messages) ─
          if (_chatMessages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedPrompts.map((prompt) {
                  return GestureDetector(
                    onTap: () => _sendMessage(prompt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : const Color(0xFF0EA5E9).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.3)
                              : const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          // ─── Input Area ───────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? AppColors.darkDivider.withValues(alpha: 0.5)
                    : AppColors.border.withValues(alpha: 0.3),
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share how you\'re feeling...',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _isChatLoading
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _isChatLoading
                          ? (isDark ? AppColors.darkBackground : AppColors.surfaceVariant)
                          : null,
                      shape: BoxShape.circle,
                      boxShadow: _isChatLoading || isDark
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: _isChatLoading
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 500.ms, delay: 250.ms)
    .slideY(begin: 0.05, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  // ─── Chat Bubble ──────────────────────────────────────────
  Widget _buildChatBubble(BuildContext context, _FeelingMsg message, bool isDark, int index) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser
              ? null
              : (isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: isDark
              ? []
              : [
                  if (isUser)
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      size: 12,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Wellness AI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9),
                      ),
                    ),
                  ],
                ),
              ),
            if (message.text.isEmpty && !isUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TypingDot(delay: 0.ms),
                  const SizedBox(width: 4),
                  _TypingDot(delay: 200.ms),
                  const SizedBox(width: 4),
                  _TypingDot(delay: 400.ms),
                ],
              )
            else if (isUser)
              Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              )
            else
              MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  strong: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  listBullet: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  em: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 250.ms)
    .slideX(
      begin: isUser ? 0.05 : -0.05,
      duration: 250.ms,
      curve: Curves.easeOutCubic,
    );
  }

  // ═════════════════════════════════════════════════════════
  // RISK INDICATOR CARD
  // ═════════════════════════════════════════════════════════
  Widget _buildRiskIndicator(
    BuildContext context,
    SentimentRiskResult risk,
    bool isDark,
  ) {
    // Risk level → color mapping
    Color riskColor;
    IconData riskIcon;
    String riskLabel;

    switch (risk.level) {
      case SentimentRiskLevel.high:
        riskColor = const Color(0xFFDC2626); // Red
        riskIcon = Icons.warning_rounded;
        riskLabel = 'High Risk';
        break;
      case SentimentRiskLevel.medium:
        riskColor = const Color(0xFFF59E0B); // Amber
        riskIcon = Icons.info_rounded;
        riskLabel = 'Medium Risk';
        break;
      case SentimentRiskLevel.low:
        riskColor = const Color(0xFF10B981); // Green
        riskIcon = Icons.check_circle_rounded;
        riskLabel = 'Low Risk';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? riskColor.withValues(alpha: 0.08)
            : riskColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: riskColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: icon + label + score badge ───
          Row(
            children: [
              Icon(riskIcon, color: riskColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Support Output: $riskLabel',
                style: TextStyle(
                  color: riskColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(risk.score * 100).toInt()}%',
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ─── Score Bar ────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: risk.score,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ─── Message ──────────────────────────────
          Text(
            risk.message,
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),

          // ─── Tips (for medium/high) ───────────────
          if (risk.tips.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...risk.tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      risk.level == SentimentRiskLevel.high
                          ? Icons.arrow_forward_rounded
                          : Icons.lightbulb_outline_rounded,
                      size: 14,
                      color: riskColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 400.ms)
    .slideY(begin: 0.08, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  // ═════════════════════════════════════════════════════════
  // AI FORECAST CARD
  // ═════════════════════════════════════════════════════════
  Widget _buildForecastCard(BuildContext context, bool isDark) {
    if (_forecastModel == null && !_isForecasting) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: _generateForecast,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Generate 7-Day Wellness Forecast'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6366F1),
            side: const BorderSide(color: Color(0xFF6366F1)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ).animate().fadeIn();
    }

    if (_isForecasting) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF6366F1)),
            const SizedBox(height: 16),
            Text(
              'Analyzing your wellness history...',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    final forecast = _forecastModel!;

    // Trajectory visuals
    IconData trajIcon;
    Color trajColor;
    switch (forecast.trajectory) {
      case RiskForecastTrajectory.improving:
        trajIcon = Icons.trending_up_rounded;
        trajColor = AppColors.success;
        break;
      case RiskForecastTrajectory.declining:
        trajIcon = Icons.trending_down_rounded;
        trajColor = AppColors.error;
        break;
      case RiskForecastTrajectory.stable:
        trajIcon = Icons.trending_flat_rounded;
        trajColor = AppColors.accent;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '7-Day Wellness Forecast',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: trajColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      forecast.trajectory.name.toUpperCase(),
                      style: TextStyle(color: trajColor, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Icon(trajIcon, color: trajColor, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            forecast.analysisText,
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (forecast.preventativeTips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Actionable Steps:',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...forecast.preventativeTips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.arrow_right_rounded, color: Color(0xFF6366F1), size: 16),
                    ),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  // ═════════════════════════════════════════════════════════
  // DAILY AFFIRMATION
  // ═════════════════════════════════════════════════════════
  Widget _buildAffirmation(
    BuildContext context,
    bool isDark,
    String affirmation,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [const Color(0xFF1A2744), const Color(0xFF1E3A5F)]
                  : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('🌟', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            affirmation,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: affirmation));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Affirmation copied! 💙'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy & Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              side: BorderSide(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
  }

  // ═════════════════════════════════════════════════════════
  // BREATHING EXERCISE
  // ═════════════════════════════════════════════════════════
  Widget _buildBreathingExercise(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border:
            isDark
                ? Border.all(color: AppColors.darkBorder.withValues(alpha: 0.3))
                : null,
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.air_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '4-4-4 Breathing',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '5 cycles • Calm your mind in 60 seconds',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Breathing circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width:
                _isBreathing ? (_breathLabel.contains('In') ? 120 : 80) : 100,
            height:
                _isBreathing ? (_breathLabel.contains('In') ? 120 : 80) : 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0EA5E9).withValues(alpha: _isBreathing ? 0.6 : 0.2),
                  const Color(0xFF6366F1).withValues(alpha: _isBreathing ? 0.4 : 0.1),
                ],
              ),
              boxShadow:
                  _isBreathing
                      ? [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                          blurRadius: 30,
                        ),
                      ]
                      : [],
            ),
            child: Center(
              child: Text(
                _breathLabel,
                style: TextStyle(
                  color:
                      _isBreathing
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary),
                  fontSize: _isBreathing ? 14 : 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          if (_isBreathing) ...[
            const SizedBox(height: 10),
            Text(
              'Cycle ${_breathCycle + 1} of 5',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF0EA5E9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startBreathingExercise,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isBreathing ? AppColors.error : const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                _isBreathing ? 'Stop' : 'Begin Breathing Exercise',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);
  }

  // ═════════════════════════════════════════════════════════
  // SELF-CARE TIPS CAROUSEL
  // ═════════════════════════════════════════════════════════
  Widget _buildSelfCareTips(BuildContext context, bool isDark) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selfCareTips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final tip = _selfCareTips[index];
          final color = tip['color'] as Color;
          return Container(
            width: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppColors.darkCardBackground
                      : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              boxShadow:
                  isDark
                      ? []
                      : [
                        BoxShadow(
                          color: color.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tip['icon'] as IconData, color: color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  tip['title'] as String,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    tip['tip'] as String,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(
            delay: Duration(milliseconds: 100 * index),
            duration: 400.ms,
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SUPPORT RESOURCES (adult-focused)
  // ═════════════════════════════════════════════════════════
  Widget _buildResources(BuildContext context, bool isDark) {
    final resources = [
      {
        'icon': Icons.phone_rounded,
        'title': 'Crisis Helpline',
        'info': '988 Suicide & Crisis Lifeline',
        'detail': 'Call or text 988 • Available 24/7',
        'color': AppColors.error,
      },
      {
        'icon': Icons.psychology_rounded,
        'title': 'Find a Therapist',
        'info': 'Psychology Today Directory',
        'detail': 'psychologytoday.com • Search by location & specialty',
        'color': const Color(0xFF6366F1),
      },
      {
        'icon': Icons.groups_rounded,
        'title': 'Peer Support',
        'info': 'NAMI Helpline',
        'detail': 'nami.org • 1-800-950-NAMI • Free support',
        'color': const Color(0xFF0EA5E9),
      },
      {
        'icon': Icons.self_improvement_rounded,
        'title': 'Mindfulness & Meditation',
        'info': 'Free Guided Resources',
        'detail': 'Headspace, Calm, or Insight Timer apps',
        'color': AppColors.accent,
      },
    ];

    return Column(
      children:
          resources.asMap().entries.map((entry) {
            final index = entry.key;
            final resource = entry.value;
            final color = resource['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppColors.darkCardBackground
                        : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border:
                    isDark
                        ? Border.all(
                          color: AppColors.darkBorder.withValues(alpha: 0.2),
                        )
                        : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      resource['icon'] as IconData,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource['title'] as String,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          resource['info'] as String,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          resource['detail'] as String,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(
              delay: Duration(milliseconds: 100 * index),
              duration: 400.ms,
            );
          }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HELPER MODELS & WIDGETS
// ═══════════════════════════════════════════════════════════

/// Simple chat message model for the feelings chat.
class _FeelingMsg {
  final String text;
  final bool isUser;
  final SentimentRiskResult? riskResult;

  const _FeelingMsg({required this.text, required this.isUser, this.riskResult});
}

/// Animated typing dot indicator.
class _TypingDot extends StatelessWidget {
  final Duration delay;

  const _TypingDot({required this.delay});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            shape: BoxShape.circle,
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(delay: delay, duration: 300.ms)
        .then()
        .fadeOut(duration: 300.ms)
        .then()
        .fadeIn(duration: 300.ms);
  }
}
