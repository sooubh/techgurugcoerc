# Doctor-Patient Real-time Chat Integration

## Overview

A real-time bidirectional chat system for doctors and patients has been successfully integrated into the CARE-AI app using **Firebase Realtime Database (RTDB)**. This enables seamless, low-latency communication between healthcare providers and patients.

---

## Architecture

### Data Structure (Firebase Realtime Database)

```
doctor_patient_chats/
├── {patientUserId}/
│   ├── {doctorId}/
│   │   ├── messages/
│   │   │   ├── -randomKey1/
│   │   │   │   ├── senderId: "user123"
│   │   │   │   ├── senderName: "John Doe"
│   │   │   │   ├── senderRole: "patient"
│   │   │   │   ├── message: "Hello doctor, how are you?"
│   │   │   │   ├── timestamp: 1704067200000
│   │   │   │   ├── isRead: false
│   │   │   │   └── attachmentUrl: null
│   │   │   ├── -randomKey2/
│   │   │   │   └── {...}
│   │   │   └── ...
│   │   ├── doctorName: "Dr. Aisha Khan"
│   │   ├── doctorImageUrl: "https://..."
│   │   ├── patientName: "John Doe"
│   │   ├── createdAt: 1704067200000
│   │   └── doctorOnline: true
│   └── {anotherDoctorId}/
│       └── {...}
└── {anotherPatientId}/
    └── {...}
```

---

## Components Created

### 1. **Models** (`lib/models/doctor_chat_model.dart`)

#### `DoctorChatMessage`
- Represents individual chat messages
- Fields: `id`, `senderId`, `senderName`, `senderRole`, `message`, `timestamp`, `isRead`, `attachmentUrl`, `attachmentType`
- Methods: `toMap()`, `fromMap()`, `copyWith()`

#### `DoctorChatSession`
- Represents an active chat session between doctor and patient
- Fields: `id` (doctorId), `doctorName`, `lastMessageTime`, `unreadCount`, `isOnline`, `lastMessage`
- Methods: `toMap()`, `fromMap()`

### 2. **Firebase Service Methods** (`lib/services/firebase_service.dart`)

#### Message Operations
- **`sendDoctorChatMessage(doctorId, message)`** - Send a message
- **`getDoctorChatMessages(doctorId)`** - Stream of live messages
- **`markDoctorChatMessageAsRead(doctorId, messageId)`** - Mark as read
- **`getDoctorChatSessions()`** - Get all active chat sessions

#### Session Management
- **`initializeDoctorChatSession(...)`** - Create/update session metadata
- **`setDoctorOnlineStatus(patientUserId, isOnline)`** - Update doctor's online status
- **`getDoctorChatWithPatients()`** - Get doctor-side chat list

### 3. **UI Screens**

#### `DoctorPatientChatScreen` (`lib/features/chat/presentation/doctor_patient_chat_screen.dart`)
- Full-featured chat interface for doctor-patient communication
- Real-time message streaming
- Doctor info display
- Message timestamp formatting
- Message bubble styling (gradient for patient, card for doctor)

#### `DoctorChatListScreen` (`lib/features/chat/presentation/doctor_chat_list_screen.dart`)
- List of all active chats with doctors
- Shows last message preview, timestamp, unread count
- Doctor online status indicator
- Tap to open individual chat

---

## How to Use

### 1. **Access Chat List**
Navigate to `/doctor-chats` route:
```dart
Navigator.pushNamed(context, '/doctor-chats');
```

### 2. **Start a Chat with Doctor**
First, ensure the patient has connected with a doctor. Then:
```dart
final doctor = DoctorModel(...);
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => DoctorPatientChatScreen(doctor: doctor),
  ),
);
```

### 3. **Send a Message**
The message is sent automatically when the user taps the send button. The `sendDoctorChatMessage()` method handles persistence to RTDB.

### 4. **Listen to Messages in Real-time**
The `getDoctorChatMessages(doctorId)` stream automatically updates the UI when new messages arrive.

### 5. **Mark Messages as Read**
```dart
await firebaseService.markDoctorChatMessageAsRead(doctorId, messageId);
```

---

## Integration Points

### Routes Added (in `main.dart`)
```dart
'/doctor-chats': (context) => const DoctorChatListScreen(),
```

### Imports Added
```dart
import 'features/chat/presentation/doctor_chat_list_screen.dart';
import 'features/chat/presentation/doctor_patient_chat_screen.dart';
```

### Firebase Realtime Database Reference
```dart
final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
```

---

## Firebase Realtime Database Rules

Recommended security rules for `firestore.rules` or database rules:

```json
{
  "rules": {
    "doctor_patient_chats": {
      "$userId": {
        ".read": "$userId === auth.uid",
        ".write": "$userId === auth.uid",
        "$doctorId": {
          "messages": {
            "$messageId": {
              ".read": "auth.uid === $userId || auth.uid === $doctorId",
              ".write": "auth.uid === $userId || auth.uid === $doctorId"
            }
          }
        }
      }
    }
  }
}
```

---

## Features

✅ **Real-time Messaging** - Instant message delivery using Firebase Realtime Database  
✅ **Message Status** - Read/unread tracking  
✅ **Online Status** - Doctor availability indicator  
✅ **Unread Badges** - Count of unread messages  
✅ **Last Message Preview** - Quick view of recent conversations  
✅ **Timestamp Formatting** - Human-readable time (e.g., "2m ago", "Mar 15")  
✅ **Doctor Info Display** - Access doctor details within chat  
✅ **Dark Mode Support** - Full theming support  
✅ **Responsive UI** - Works on all screen sizes  
✅ **Error Handling** - Graceful error management with user feedback  

---

## Performance Considerations

### Optimizations:
- **Stream-based Updates** - Messages are streamed in real-time without polling
- **Efficient Queries** - Only necessary data is fetched
- **Message Sorting** - Sorted by timestamp client-side
- **Unread Tracking** - Computed from message data, not a separate counter

### Best Practices:
- Messages are kept in RTDB (not Firestore) for low-latency delivery
- Session metadata (doctorName, isOnline) stored at session level for quick access
- Patient-indexed path ensures scalability for multi-doctor scenarios

---

## Error Handling

All methods include try-catch blocks and log errors to `AppLogger`:

```dart
try {
  await _firebaseService.sendDoctorChatMessage(doctorId, message);
} catch (e) {
  AppLogger.error('DoctorPatientChatScreen', 'Failed to send message', e, StackTrace.current);
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

---

## Future Enhancements

- [ ] File/image attachments in chat
- [ ] Voice message support
- [ ] Typing indicator animations
- [ ] Message search/filtering
- [ ] Chat history export
- [ ] Scheduled appointments/video calls
- [ ] Chat encryption (end-to-end)
- [ ] Message media (images, PDFs, videos)
- [ ] Rich text formatting (bold, italic, links)
- [ ] Message reactions/emojis

---

## Testing

### To Test Locally:

1. **Sign up as patient** on account A
2. **Sign up as doctor** on account B  
3. **Patient:** Navigate to `/doctor-chats`
4. **Connect with doctor** (e.g., through the consultation request flow)
5. **Patient:** Open chat with doctor from the list
6. **Patient:** Send a test message
7. **Doctor:** Open the doctor dashboard and see the chat
8. **Doctor:** Reply to the message
9. **Patient:** Verify real-time message appears

---

## Dependencies

- `firebase_database: ^11.3.10` ✅ Already in pubspec.yaml
- `provider: ^6.1.2` ✅ Already in pubspec.yaml
- `intl: ^0.20.2` ✅ Already in pubspec.yaml

No additional dependencies needed!

---

## File Summary

| File | Purpose |
|------|---------|
| `lib/models/doctor_chat_model.dart` | Chat message and session models |
| `lib/services/firebase_service.dart` | RTDB operations (modified) |
| `lib/features/chat/presentation/doctor_patient_chat_screen.dart` | 1:1 chat UI |
| `lib/features/chat/presentation/doctor_chat_list_screen.dart` | Chat list UI |
| `lib/main.dart` | Route registration (modified) |

---

## API Reference

```dart
// Send a message
Future<void> sendDoctorChatMessage(String doctorId, DoctorChatMessage message)

// Listen to messages
Stream<List<DoctorChatMessage>> getDoctorChatMessages(String doctorId)

// Get all sessions
Future<List<DoctorChatSession>> getDoctorChatSessions()

// Mark as read
Future<void> markDoctorChatMessageAsRead(String doctorId, String messageId)

// Update doctor status
Future<void> setDoctorOnlineStatus(String patientUserId, bool isOnline)

// Initialize session
Future<void> initializeDoctorChatSession(...)
```

---

## Support

For issues or questions about the doctor-patient chat implementation, check:
- `VOICE_BOT.md` for voice integration patterns
- Existing `ChatScreen` implementation for AI chat reference
- Firebase Realtime Database documentation

---

**Status:** ✅ Complete and Ready for Use
