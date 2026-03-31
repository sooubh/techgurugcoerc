# Voice Agent Not Connecting - Quick Fix

## The Problem
Voice agent is stuck on "Connecting..." state. This means the WebSocket is trying to connect to Google's Gemini Live API but **the API is rejecting the connection**.

## Most Common Cause: Invalid API Key ❌

### Check Your API Key

1. **Open `.env` file** (in project root)
   - Look for: `GEMINI_API_KEY=AIzaSy...`
   
2. **Verify it looks correct:**
   - ✅ Starts with `AIzaSy`
   - ✅ Is at least 39 characters long
   - ✅ Has NO spaces or line breaks
   - ❌ Should NOT be `your_api_key_here` or empty

3. **Get a fresh API key:**
   - Go to: https://aistudio.google.com/app/apikey
   - If you see a red error, click **Create API Key**
   - If you already have one, click it to copy
   - Paste into `.env` file

### Example:
```env
# WRONG ❌
GEMINI_API_KEY=your_actual_api_key_here

# RIGHT ✅
GEMINI_API_KEY=AIzaSyAStzp47TRim_fds4AiATxWVDF6tD19s7A
```

---

## Fix Steps

### Step 1: Update `.env` with Valid API Key
```bash
# File: d:/Project/techgurugcoerc/.env
GEMINI_API_KEY=AIzaSy...your_real_key...
```

### Step 2: Hot Reload (or Full Restart)
```bash
# In VS Code terminal:
# Press 'r' to hot reload (fast)
# Or Ctrl+C then flutter run (full restart)
```

### Step 3: Open Voice Agent Again
- Home → Tap "Voice" button
- Wait for "Connected" status (green dot)

---

## Check Console Logs

If still not working, check the console for clues:

```bash
# Run with verbose logs
flutter run -v 2>&1 | grep -i "voice\|api\|websocket\|error"
```

### Look for these messages:

✅ **Good signs:**
```
[✓] VoiceAssistantService: Starting live session...
[✓] GeminiLiveService: Connecting to WebSocket...
[✓] GeminiLiveService: WebSocket handshake complete
[✓] GeminiLiveService: Setup message sent
[✓] GeminiLiveService: setupComplete received
```

❌ **Bad signs (means invalid API key):**
```
[✗] ERROR: API key is missing or invalid
[✗] ERROR: TIMEOUT waiting for setupComplete
[✗] ERROR: Gemini API key doesn't start with "AIzaSy"
```

---

## Advanced Debugging

### Option A: Test API Key in Browser
1. Go to: https://aistudio.google.com/app/apikey
2. See if your API key is listed
3. If not, create a new one

### Option B: Validate in Code
Add this test to `lib/core/config/env_config.dart`:

```dart
static void validate() {
  final key = geminiApiKey;
  print('API Key length: ${key.length}');
  print('Starts with AIzaSy: ${key.startsWith('AIzaSy')}');
  print('First 15 chars: ${key.substring(0, 15)}...');
}
```

Then call `EnvConfig.validate()` in main() and check the logs.

---

## Still Not Working?

### Try these in order:

1. **Force restart:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Check network:**
   - Open browser, go to google.com
   - If it works, network is fine
   - If not, WiFi/mobile data issue

3. **Check Gemini API is enabled:**
   - Go to: https://console.cloud.google.com
   - Find your project
   - Go to APIs & Services > Enabled APIs
   - Search for "Generative AI API"
   - Should have a blue checkmark

4. **Update .env file format:**
   ```bash
   # Make sure there are NO spaces around the =
   # Right:  GEMINI_API_KEY=AIzaSy...
   # Wrong: GEMINI_API_KEY = AIzaSy...
   GEMINI_API_KEY=your_full_api_key_here
   ```

---

## What NOT to Do

❌ Don't hardcode the API key in Dart code  
❌ Don't commit `.env` to GitHub  
❌ Don't share your API key in messages  
❌ Don't use a key from a training video (it's expired)  

---

## Model Change

The voice agent was updated to use the latest Gemini model: `gemini-2.0-flash-exp`

- ✅ Faster responses
- ✅ Better quality audio
- ✅ More reliable than the preview model

---

## Next Steps Once Connected

Once you see "Listening..." status:
1. Speak your first message
2. Wait for "CARE-AI is Speaking"
3. Listen to the response

If audio plays but is garbled, check your system audio settings.

---

**Still stuck?** Run:
```bash
flutter logs | grep -i "voice\|gemini"
```

And share the error messages for more specific help.
