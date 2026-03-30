import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertSource {
  aiChat,
  behavioral,
  assessment,
}

enum AlertSeverity {
  low,
  medium,
  high,
}

class RiskAlertModel {
  final String id;
  final String userId; // Parent UID
  final AlertSource source;
  final AlertSeverity severity;
  final String description;
  final bool isResolved;
  final DateTime timestamp;

  RiskAlertModel({
    required this.id,
    required this.userId,
    required this.source,
    required this.severity,
    required this.description,
    this.isResolved = false,
    required this.timestamp,
  });

  factory RiskAlertModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    AlertSource source = AlertSource.behavioral;
    String srcStr = data['source'] ?? 'behavioral';
    if (srcStr == 'aiChat') source = AlertSource.aiChat;
    if (srcStr == 'assessment') source = AlertSource.assessment;

    AlertSeverity severity = AlertSeverity.low;
    String sevStr = data['severity'] ?? 'low';
    if (sevStr == 'medium') severity = AlertSeverity.medium;
    if (sevStr == 'high') severity = AlertSeverity.high;

    return RiskAlertModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      source: source,
      severity: severity,
      description: data['description'] ?? '',
      isResolved: data['isResolved'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'source': source.name,
      'severity': severity.name,
      'description': description,
      'isResolved': isResolved,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
