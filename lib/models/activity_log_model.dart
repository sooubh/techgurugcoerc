import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a completed activity session logged to Firestore.
class ActivityLogModel {
  final String? id;
  final String activityId;
  final String activityTitle;
  final String category;
  final int durationSeconds;
  final int stepsCompleted;
  final DateTime completedAt;
  final bool isAdult;

  const ActivityLogModel({
    this.id,
    required this.activityId,
    required this.activityTitle,
    required this.category,
    required this.durationSeconds,
    required this.stepsCompleted,
    required this.completedAt,
    this.isAdult = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'activityTitle': activityTitle,
      'category': category,
      'durationSeconds': durationSeconds,
      'stepsCompleted': stepsCompleted,
      'completedAt': Timestamp.fromDate(completedAt),
      'isAdult': isAdult,
    };
  }

  factory ActivityLogModel.fromMap(Map<String, dynamic> map, String docId) {
    return ActivityLogModel(
      id: docId,
      activityId: map['activityId'] ?? '',
      activityTitle: map['activityTitle'] ?? '',
      category: map['category'] ?? '',
      durationSeconds: map['durationSeconds'] ?? 0,
      stepsCompleted: map['stepsCompleted'] ?? 0,
      completedAt:
          (map['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAdult: map['isAdult'] ?? false,
    );
  }
}
