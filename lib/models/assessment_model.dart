import 'package:cloud_firestore/cloud_firestore.dart';

enum RiskLevel { low, medium, high }

class AssessmentModel {
  final String id;
  final String userId; // Usually the parent taking the assessment
  final int score;
  final RiskLevel riskLevel;
  final Map<String, int> responses;
  final DateTime timestamp;

  AssessmentModel({
    required this.id,
    required this.userId,
    required this.score,
    required this.riskLevel,
    required this.responses,
    required this.timestamp,
  });

  factory AssessmentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    RiskLevel rLevel = RiskLevel.low;
    String levelStr = data['riskLevel'] ?? 'low';
    if (levelStr == 'medium') rLevel = RiskLevel.medium;
    if (levelStr == 'high') rLevel = RiskLevel.high;

    return AssessmentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      score: data['score'] ?? 0,
      riskLevel: rLevel,
      responses: Map<String, int>.from(data['responses'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'score': score,
      'riskLevel': riskLevel.name,
      'responses': responses,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
