# 🔑 Google Directions API Setup (Optional)

## Why This is Optional

The app **already works** with free OSRM routing! You only need Google API if you want:
- Real-time traffic data
- Slightly more accurate routes
- Better ETA predictions

## Quick Setup (5 minutes)

### 1. Get API Key

Visit: https://console.cloud.google.com/apis/credentials

1. Click **"Create Credentials"** → **"API Key"**
2. Copy the key (looks like: `AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXX`)

### 2. Enable APIs

Visit: https://console.cloud.google.com/apis/library

Search and enable:
- ✅ **Directions API**
- ✅ **Maps SDK for Android** (if building for Android)
- ✅ **Maps SDK for iOS** (if building for iOS)

### 3. Add Key to App

Open: `lib/services/route_service.dart`

Find line 19:
```dart
static const String _googleApiKey = 'YOUR_GOOGLE_API_KEY_HERE';
```

Replace with your key:
```dart
static const String _googleApiKey = 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXX';
```

### 4. Test

```bash
flutter run
```

Check console for:
```
🗺️  Fetching route from routing service...
✅ Route fetched: 1.6 km, ETA: 5 min
```

## Restrict API Key (IMPORTANT)

**Don't skip this!** Protect your API key from abuse:

1. Go to: https://console.cloud.google.com/apis/credentials
2. Click your API key
3. Under **"API restrictions"**:
   - Select **"Restrict key"**
   - Choose: Directions API, Maps SDK for Android, Maps SDK for iOS
4. Under **"Application restrictions"**:
   - Android: Add package name + SHA-1 certificate fingerprint
   - iOS: Add Bundle ID
5. Click **"Save"**

## Get Android SHA-1 Fingerprint

```bash
# Debug certificate
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release certificate (when you create one)
keytool -list -v -keystore your-release-key.keystore -alias your-alias
```

Copy the **SHA-1** value and add to Google Cloud Console.

## Cost Monitoring

1. Set up billing alerts: https://console.cloud.google.com/billing
2. Set alert at $50, $100, $150
3. Monitor usage: https://console.cloud.google.com/apis/dashboard

**Expected cost for 1,000 users/month:** ~$50-75

## Troubleshooting

### "⚠️ Google Directions failed"
- Check if API key is correct
- Verify Directions API is enabled
- Check API key restrictions
- App will use OSRM fallback (everything still works!)

### "REQUEST_DENIED"
- API key restrictions are too strict
- Or Directions API not enabled
- Or billing not enabled in Google Cloud

### Still showing straight lines
- Check console for errors
- Verify internet connection
- Make sure you saved `route_service.dart` after adding key

## Free Tier Limits

Google gives you **$200 free credits/month**, which equals:
- 40,000 route requests/month
- About 100-150 route requests/day

For most small/medium apps, you'll **stay within free tier**.

## Environment Variables (Advanced)

For production, use environment variables:

1. Create `lib/config/api_keys.dart`:
```dart
class ApiKeys {
  static const String googleDirections = String.fromEnvironment(
    'GOOGLE_API_KEY',
    defaultValue: 'YOUR_GOOGLE_API_KEY_HERE',
  );
}
```

2. Update `route_service.dart`:
```dart
import '../config/api_keys.dart';

static const String _googleApiKey = ApiKeys.googleDirections;
```

3. Run with:
```bash
flutter run --dart-define=GOOGLE_API_KEY=AIzaSyXXXXXX
```

4. Add to `.gitignore`:
```
lib/config/api_keys.dart
```

## Summary

**Without Google API (DEFAULT):**
- ✅ Free OSRM routing
- ✅ Routes follow roads
- ✅ Distance + ETA displayed
- ✅ Everything works

**With Google API (OPTIONAL):**
- ✅ Real-time traffic
- ✅ Better accuracy
- ✅ Premium quality
- ⚠️ Costs ~$50-75/month for 1,000 users

**Choose based on your needs!** The free version is excellent for most use cases.
