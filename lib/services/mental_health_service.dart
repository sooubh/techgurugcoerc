import 'package:uuid/uuid.dart';
import '../models/assessment_model.dart';
import '../models/risk_alert_model.dart';
import 'firebase_service.dart';
import '../core/utils/app_logger.dart';

class EarlyIdentificationStatus {
  final String label;
  final String summary;
  final AlertSeverity severity;
  final int confidenceScore;
  final int recentAssessments;
  final int unresolvedAlerts;

  const EarlyIdentificationStatus({
    required this.label,
    required this.summary,
    required this.severity,
    required this.confidenceScore,
    required this.recentAssessments,
    required this.unresolvedAlerts,
  });
}

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

    // Generate alerts for early identification workflows.
    if (level == RiskLevel.high) {
      await logRiskAlert(
        source: AlertSource.assessment,
        severity: AlertSeverity.high,
        description: 'High risk score calculated from periodic assessment ($totalScore/27).',
      );
    } else if (level == RiskLevel.medium) {
      await logRiskAlert(
        source: AlertSource.assessment,
        severity: AlertSeverity.medium,
        description: 'Moderate risk score detected from check-in ($totalScore/27).',
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

  /// Builds an early-identification status from recent assessments + unresolved alerts.
  Future<EarlyIdentificationStatus> getEarlyIdentificationStatus() async {
    final assessments = await _firebaseService.getAssessments(limit: 7);
    final alerts = await _firebaseService.getRiskAlerts(limit: 20);

    final unresolved = alerts.where((a) => !a.isResolved).toList();
    final unresolvedHigh =
        unresolved.where((a) => a.severity == AlertSeverity.high).length;
    final unresolvedMedium =
        unresolved.where((a) => a.severity == AlertSeverity.medium).length;

    final latestRisk = assessments.isNotEmpty ? assessments.first.riskLevel : null;

    final confidenceBase = (assessments.length * 12) + (alerts.length * 4);
    final confidence = confidenceBase.clamp(10, 100);

    if (unresolvedHigh > 0 || latestRisk == RiskLevel.high) {
      return EarlyIdentificationStatus(
        label: 'High Risk',
        summary:
            'Early signals suggest high distress. Please prioritize immediate support and a professional check-in.',
        severity: AlertSeverity.high,
        confidenceScore: confidence,
        recentAssessments: assessments.length,
        unresolvedAlerts: unresolved.length,
      );
    }

    if (unresolvedMedium >= 2 ||
        unresolvedMedium > 0 ||
        latestRisk == RiskLevel.medium) {
      return EarlyIdentificationStatus(
        label: 'Mild Risk',
        summary:
            'Potential stress indicators were detected early. Continue regular check-ins and monitor changes closely.',
        severity: AlertSeverity.medium,
        confidenceScore: confidence,
        recentAssessments: assessments.length,
        unresolvedAlerts: unresolved.length,
      );
    }

    if (assessments.isEmpty && alerts.isEmpty) {
      return const EarlyIdentificationStatus(
        label: 'Not Enough Data',
        summary:
            'Complete a check-in to enable early identification of mental health status.',
        severity: AlertSeverity.low,
        confidenceScore: 10,
        recentAssessments: 0,
        unresolvedAlerts: 0,
      );
    }

    return EarlyIdentificationStatus(
      label: 'Stable',
      summary:
          'No major early-warning patterns found in recent activity. Keep up routine wellness check-ins.',
      severity: AlertSeverity.low,
      confidenceScore: confidence,
      recentAssessments: assessments.length,
      unresolvedAlerts: unresolved.length,
    );
  }
}
