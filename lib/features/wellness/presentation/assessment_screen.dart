import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/mental_health_service.dart';
import '../../../services/firebase_service.dart';
import '../../../models/assessment_model.dart';
import 'crisis_support_screen.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final PageController _pageController = PageController();
  final FirebaseService _firebaseService = FirebaseService();
  late MentalHealthService _mentalHealthService;

  int _currentIndex = 0;
  bool _isSubmitting = false;

  final Map<String, int> _responses = {};

  final List<Map<String, dynamic>> _questions = [
    {
      'id': 'q1',
      'text': 'Over the last 2 weeks, how often have you felt overwhelmed by your caregiving responsibilities?',
    },
    {
      'id': 'q2',
      'text': 'How often have you felt down, depressed, or hopeless?',
    },
    {
      'id': 'q3',
      'text': 'How often have you had trouble relaxing or clearing your mind?',
    },
    {
      'id': 'q4',
      'text': 'How often have you felt that you have no time for yourself?',
    },
    {
      'id': 'q5',
      'text': 'Have you felt isolated or disconnected from friends and family?',
    },
  ];

  final List<String> _options = [
    'Not at all',
    'Several days',
    'More than half the days',
    'Nearly every day'
  ];

  @override
  void initState() {
    super.initState();
    _mentalHealthService = MentalHealthService(_firebaseService);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onOptionSelected(int score) {
    final questionId = _questions[_currentIndex]['id'] as String;
    setState(() {
      _responses[questionId] = score;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_currentIndex < _questions.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _submitAssessment() async {
    setState(() => _isSubmitting = true);

    try {
      final assessment = await _mentalHealthService.processAssessment(_responses);

      if (!mounted) return;

      if (assessment.riskLevel == RiskLevel.high) {
        // High risk logic: Show the crisis support bottom sheet immediately
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const CrisisSupportBottomSheet(),
        );
      } else {
        // Low/Medium risk logic: Show success dialog and pop
        _showResultsDialog(assessment);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \$e', style: const TextStyle(color: Colors.white))),
      );
      setState(() => _isSubmitting = false);
    }
  }

  void _showResultsDialog(AssessmentModel assessment) {
    String title = 'Check-in Complete';
    String message = 'Thank you for taking a moment to check in. Remember to prioritize your own wellbeing!';

    if (assessment.riskLevel == RiskLevel.medium) {
      message = 'You\'ve been carrying a heavy load lately. Please consider talking to your doctor or trying some of the self-care resources in the Wellness tab.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Return to Wellness'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellbeing Check-in'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _questions.length,
                  backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final question = _questions[index];
                      final questionId = question['id'] as String;
                      final currentScore = _responses[questionId];

                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Question \${index + 1} of \${_questions.length}',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              question['text'],
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 48),
                            ...List.generate(_options.length, (optIndex) {
                              final isSelected = currentScore == optIndex;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: InkWell(
                                  onTap: () => _onOptionSelected(optIndex),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : (isDark ? AppColors.darkCardBackground : AppColors.cardBackground),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.divider),
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                          color: isSelected ? Colors.white : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          _options[optIndex],
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, duration: 300.ms);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentIndex > 0)
                          TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text('Back'),
                          )
                        else
                          const SizedBox.shrink(),
                          
                        if (_currentIndex == _questions.length - 1)
                          ElevatedButton(
                            onPressed: _responses.length == _questions.length ? _submitAssessment : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            child: const Text('Complete', style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
