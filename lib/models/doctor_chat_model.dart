/// Model representing a real-time chat message between Doctor and Patient.
/// Stored at: users/{userId}/doctor_chats/{doctorId}/messages/{messageId}
/// in Firebase Realtime Database.
class DoctorChatMessage {
  final String id;
  final String senderId; // user_id or doctor_id
  final String senderName; // Display name
  final String senderRole; // 'patient', 'doctor', 'admin'
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? attachmentUrl;
  final String? attachmentType; // 'image', 'file', 'audio'

  DoctorChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentType,
  });

  bool get isFromPatient => senderRole == 'patient';
  bool get isFromDoctor => senderRole == 'doctor';

  /// Create from Firebase Realtime DB map
  factory DoctorChatMessage.fromMap(Map<dynamic, dynamic> map, String id) {
    return DoctorChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      senderRole: map['senderRole'] ?? 'patient',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      attachmentUrl: map['attachmentUrl'],
      attachmentType: map['attachmentType'],
    );
  }

  /// Convert to Firebase Realtime DB compatible map
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentType != null) 'attachmentType': attachmentType,
    };
  }

  /// Create a copy with updated fields
  DoctorChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? attachmentUrl,
    String? attachmentType,
  }) {
    return DoctorChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
    );
  }
}

/// Model representing an active doctor-patient chat session
class DoctorChatSession {
  final String id; // doctorId
  final String doctorName;
  final String? doctorImageUrl;
  final String? patientName;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final String? lastMessage;

  DoctorChatSession({
    required this.id,
    required this.doctorName,
    this.doctorImageUrl,
    this.patientName,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.lastMessage,
  });

  /// Create from Firebase Realtime DB map
  factory DoctorChatSession.fromMap(Map<dynamic, dynamic> map, String id) {
    return DoctorChatSession(
      id: id,
      doctorName: map['doctorName'] ?? 'Unknown Doctor',
      doctorImageUrl: map['doctorImageUrl'],
      patientName: map['patientName'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'] as int)
          : DateTime.now(),
      unreadCount: map['unreadCount'] ?? 0,
      isOnline: map['isOnline'] ?? false,
      lastMessage: map['lastMessage'],
    );
  }

  /// Convert to Firebase Realtime DB compatible map
  Map<String, dynamic> toMap() {
    return {
      'doctorName': doctorName,
      if (doctorImageUrl != null) 'doctorImageUrl': doctorImageUrl,
      if (patientName != null) 'patientName': patientName,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      if (lastMessage != null) 'lastMessage': lastMessage,
    };
  }
}
