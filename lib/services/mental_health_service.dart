import 'package:uuid/uuid.dart';
import '../models/assessment_model.dart';
import '../models/risk_alert_model.dart';
import 'firebase_service.dart';
import '../core/utils/app_logger.dart';

class MentalHealthService {
  final FirebaseService _firebaseService;
  final Uuid _uuid = const Uuid();

  MentalHealthService(this._firebaseService);

  /// Calculate score and risk level from an assessment map (e.g., PHQ-9 style 0-3 rating per question).
  Future<AssessmentModel> processAssessment(Map<String, int> responses) async {
    final userId = _firebaseService.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    int totalScore = 0;
    responses.forEach((key, value) {
      totalScore += value;
    });

    RiskLevel level = RiskLevel.low;
    if (totalScore >= 15) {
      level = RiskLevel.high;
    } else if (totalScore >= 10) {
      level = RiskLevel.medium;
    }

    final assessment = AssessmentModel(
      id: _uuid.v4(),
      userId: userId,
      score: totalScore,
      riskLevel: level,
      responses: responses,
      timestamp: DateTime.now(),
    );

    await _firebaseService.saveAssessment(assessment);

    // If risk is high, generate an alert
    if (level == RiskLevel.high) {
      await logRiskAlert(
        source: AlertSource.assessment,
        severity: AlertSeverity.high,
        description: 'High risk score calculated from periodic assessment ($totalScore/27).',
      );
    }

    return assessment;
  }

  /// Create and log a new risk alert. Used by behavioral triggers or AI chat.
  Future<void> logRiskAlert({
    required AlertSource source,
    required AlertSeverity severity,
    required String description,
  }) async {
    final userId = _firebaseService.currentUser?.uid;
    if (userId == null) {
      AppLogger.warning('MentalHealth', 'Cannot log alert: User is null');
      return;
    }

    final alert = RiskAlertModel(
      id: _uuid.v4(),
      userId: userId,
      source: source,
      severity: severity,
      description: description,
      timestamp: DateTime.now(),
      isResolved: false,
    );

    await _firebaseService.saveRiskAlert(alert);
    AppLogger.info('MentalHealth', 'Risk alert logged: ${source.name} - ${severity.name}');
  }

  Future<List<AssessmentModel>> getAssessmentsHistory() async {
    return await _firebaseService.getAssessments();
  }
}
