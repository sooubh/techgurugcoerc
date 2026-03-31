# CARE-AI — Detailed Project README

CARE-AI is a Flutter + Firebase mobile application that supports mental wellness, therapy routines, and collaboration between families and healthcare professionals.

This repository includes:
- Parent/Caregiver workflows
- Doctor/Therapist workflows
- AI chat and voice support
- Wellness and assessment flows
- Adult mental health support (including doctor consultation request)

---

## 1) Project Summary

CARE-AI helps users with daily mental wellness and therapy support through:
- guided activities,
- progress tracking,
- AI conversation,
- and doctor connection workflows.

The app supports multiple user journeys:
- **Parent/Caregiver** journey for child support
- **Doctor/Therapist** journey for clinical follow-up
- **Adult wellness** journey for self-care and consultation

---

## 2) Key Capabilities

### A. Mental Health & Wellness
- Adult mood check-in
- Stress check-in
- AI feelings chat
- Self-care suggestions
- Breathing exercises
- Crisis guidance sheet
- Mental health self-assessment screen

### B. Home Dashboard Actions
The home dashboard includes quick actions such as:
- AI chat
- Voice assistant
- Daily plan
- Wellness
- **Talk Feelings** (adult feelings chat)
- **Consult Doctor** (adult consultation request)
- Community and achievements

### C. Adult ↔ Doctor Connection
- Adult users can view available doctors.
- Adult users can send consultation requests with an optional note.
- Doctor users can see pending requests and accept/decline.

### D. Parent/Child Support
- Child profile setup and multi-child support
- Therapy module library
- Therapeutic game hub
- Progress dashboard with weekly metrics and streaks
- Guidance notes from doctor

### E. Doctor Portal
- Doctor dashboard tabs (home, patients, requests, alerts, profile)
- Patient details and activity context
- Assign plan/activities
- Send guidance notes
- Handle consultation/connection requests

---

## 3) Tech Stack

### Frontend
- Flutter (Dart SDK ^3.7.0)
- Provider state management
- Material 3 UI + animations

### Backend & Cloud
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Firebase Messaging
- Cloud Functions (TypeScript)

### AI
- `google_generative_ai` for Gemini text interactions
- Gemini Live stack for low-latency voice interactions

### Local Data & Background
- Hive + SharedPreferences
- Workmanager for background tasks
- Connectivity-aware sync behavior

---

## 4) Repository Structure

```text
techgurugcoerc/
├── lib/
│   ├── core/                # theme, constants, config, utils
│   ├── features/            # feature-first UI modules
│   ├── models/              # app data models
│   ├── services/            # Firebase, AI, voice, cache, notifications
│   └── main.dart            # app bootstrap and routing
├── functions/               # Firebase Cloud Functions (TypeScript)
├── android/                 # Android project files
├── ios/                     # iOS project files
├── assets/                  # images/icons/animations
├── test/                    # unit + widget tests
└── pubspec.yaml             # dependencies and assets
```

---

## 5) Important Screens (Current)

### Parent & General
- Home dashboard
- Chat screen
- Voice assistant
- Activities & games
- Progress
- Community
- Settings

### Wellness
- Wellness screen
- Adult wellness screen
- Crisis support
- Assessment/self-check screens

### Doctor
- Doctor dashboard
- Requests tab
- Patients tab
- Compose guidance note
- Assign plan

### New Adult Consultation Flow
- **Adult consultation screen** where users:
  1. load doctor list,
  2. add optional note,
  3. submit consultation request.

---

## 6) Core Service Responsibilities

- `FirebaseService`
  - auth and user profile handling
  - child profiles, activity logs, guidance notes
  - doctor requests and responses
  - adult consultation request creation

- `AiService`
  - recommendation and AI support logic

- `VoiceAssistantService` + `GeminiLiveService`
  - audio session lifecycle
  - real-time streaming interactions

- `SmartDataRepository` + cache services
  - cache-first data reads
  - offline fallback and sync

---

## 7) Environment Setup

Create a `.env` file in project root:

```env
GEMINI_API_KEY=your_gemini_api_key_here
```

The app reads this key through `EnvConfig`.

---

## 8) Firebase Setup Checklist

1. Create/select Firebase project.
2. Enable:
   - Authentication
   - Firestore
   - Storage
   - Cloud Messaging
   - Functions
3. Add Android/iOS apps in Firebase console.
4. Place `google-services.json` under:
   - `android/app/google-services.json`
5. Generate/update Flutter firebase options (`lib/firebase_options.dart`) if needed.

---

## 9) Run the Flutter App

```bash
flutter pub get
flutter run
```

Optional with explicit define:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_gemini_api_key_here
```

---

## 10) Run Tests

```bash
flutter test
```

---

## 11) Cloud Functions (Optional Local Dev)

From `functions/`:

```bash
npm install
npm run build
npm run serve
```

Deploy:

```bash
npm run deploy
```

---

## 12) Data & Security Notes

- Firestore access is protected by authenticated user context and rules in `firestore.rules`.
- AI output is assistive and not a replacement for licensed clinical diagnosis.
- Crisis messaging encourages users to contact emergency/professional support.

---

## 13) Current Product Direction

The current product state supports a stronger mental-health-oriented flow by:
- surfacing feelings conversation from home (`Talk Feelings`),
- adding direct adult-to-doctor consult requests (`Consult Doctor`),
- and preserving doctor-side request handling in dashboard tabs.

---

## 14) Useful Commands

```bash
# Flutter
flutter pub get
flutter analyze
flutter test
flutter run

# Android release (example)
flutter build apk --release

# iOS release (example)
flutter build ios --release
```

---

## 15) Disclaimer

CARE-AI provides educational and supportive wellness guidance. It does not replace emergency services or licensed medical diagnosis/treatment.

For urgent mental health crises, users should contact local emergency services or official crisis hotlines immediately.
