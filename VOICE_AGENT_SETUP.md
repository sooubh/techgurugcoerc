# Voice Agent Setup Guide

## Overview
The CARE-AI Voice Agent uses Google's Gemini Live API for real-time voice conversations. To get it working, you need to:

1. Get a Gemini API Key
2. Add it to your `.env` file
3. Enable microphone permissions
4. Have a stable internet connection

---

## Step 1: Get Your Gemini API Key

### Option A: Free API Key (Development)
1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Click **Create API Key**
3. Select your Google Cloud Project (or create a new one)
4. Copy the generated API key

### Option B: Production (Paid)
- Set up a Google Cloud project with billing enabled
- Enable the Generative AI API
- Create a service account with appropriate permissions

---

## Step 2: Add API Key to `.env` File

The `.env` file in your project root contains:
```env
GEMINI_API_KEY=your_actual_api_key_here
```

### Update the key:
```bash
# Replace 'your_actual_api_key_here' with your real key
GEMINI_API_KEY=AIzaSy...your_key...
```

**Location:** `d:/Project/techgurugcoerc/.env`

---

## Step 3: Permissions (Mobile Devices)

### Android
The app requests microphone permission on first use. When you open the Voice Agent screen, you'll see a permission prompt. **Tap Allow**.

### iOS
iOS also requests microphone permission. Approve it in the system dialog.

To manually enable:
- **Android:** Settings > Apps > CARE-AI > Permissions > Microphone > Allow
- **iOS:** Settings > CARE-AI > Microphone > Allow

---

## Step 4: Network Connection

The Voice Agent requires:
- **WiFi** or **Mobile Data** connection
- At least 1-2 Mbps upload/download speed
- Stable connection (WebSocket will close if dropped)

### Check Connection
- Open Settings
- Verify you're connected to WiFi or mobile data
- Test speed at speedtest.net if unsure

---

## Troubleshooting

### Error: "Gemini API key not configured"
- ✅ Verify the `.env` file exists in the project root
- ✅ Check that `GEMINI_API_KEY=` has a value (not empty)
- ✅ Run `flutter clean` then `flutter pub get` to reload environment
- ✅ Restart the app with `flutter run`

### Error: "No internet connection"
- ✅ Check WiFi / Mobile Data is enabled
- ✅ Ping google.com to verify connectivity
- ✅ Try connecting to a different WiFi network
- ✅ Restart router if connection is unstable

### Error: "Microphone permission denied"
- ✅ Go to **Settings > Apps > CARE-AI > Permissions**
- ✅ Enable **Microphone** permission
- ✅ Restart the app

### Voice Not Working / WebSocket Error
- ✅ Verify API key is correct (check `.env` file)
- ✅ Check if Gemini API is enabled in your Google Cloud project
- ✅ Try running with explicit API key:
  ```bash
  flutter run --dart-define=GEMINI_API_KEY=your_key_here
  ```

### Slow or Choppy Audio
- ✅ Move closer to WiFi router
- ✅ Close other apps using bandwidth
- ✅ Try a wired connection if possible
- ✅ Check if multiple devices are using the same network

---

## Testing the Voice Agent

1. **Open the App**
   - Run `flutter run`

2. **Navigate to Voice Agent**
   - Home Screen → Tap **Voice** button (or navigate to `/voice-assistant`)

3. **Wait for Connection**
   - Status bar shows: "Connecting..." → "Ready"
   - Green dot indicates API is connected

4. **Speak Naturally**
   - Tap microphone area or just start speaking
   - Wait for "Listening..." status
   - Speak your question or message

5. **Listen to Response**
   - Status changes to "CARE-AI is Speaking"
   - Audio plays through speaker

6. **End Session**
   - Tap the down arrow (↓) at the top to close

---

## Debugging Logs

If voice agent still doesn't work, check the console logs:

```bash
# Run with verbose logging
flutter run -v 2>&1 | grep -i "voice\|api\|websocket"
```

Look for:
- ✅ `VoiceAssistantService: Starting live session...`
- ✅ `GeminiLiveService: Connecting to WebSocket...`
- ✅ `GeminiLiveService: WebSocket handshake complete`
- ✅ `VoiceAssistantService: Setup complete — starting mic`

If you see errors, share them for debugging.

---

## API Key Security

### Development
- Using a free API key in `.env` is fine for testing
- Never commit `.env` to GitHub (it's in `.gitignore`)

### Production
- Replace with a restricted API key (IP whitelisting, quota limits)
- Use environment variables or secrets manager
- Implement backend proxy for API calls if deploying to production

---

## Costs

### Free Tier
- First 50 requests per day free
- Then quota limits apply

### Paid
- Once you add billing to Google Cloud, charges apply
- Check [Google AI API Pricing](https://ai.google.dev/pricing)

---

## Next Steps

Once voice is working:
1. Test with different child profiles
2. Verify context is being passed correctly
3. Check that risk detection works
4. Test navigation commands ("Go to breathing", "Show games")

---

For more details, see **VOICE_BOT.md** in the project root.
