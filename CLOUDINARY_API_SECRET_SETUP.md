# 🔑 CLOUDINARY API SECRET - SETUP GUIDE

## ⚠️ CRITICAL: You Need Your API Secret

The error you got was because unsigned uploads require a preset. I've switched to **SIGNED uploads** which are more secure and don't require a preset.

---

## 📋 WHAT YOU NEED

1. ✅ Cloud Name: `dmksbfd7h` (already configured)
2. ✅ API Key: `862973714739146` (already configured)
3. ❌ API Secret: **YOU NEED TO GET THIS**

---

## 🔍 HOW TO GET YOUR API SECRET

### Step 1: Go to Cloudinary Dashboard
1. Open [Cloudinary Console](https://cloudinary.com/console)
2. Log in with your account

### Step 2: Find API Credentials
1. On the dashboard home page, look for **Account Details** section
2. You'll see:
   ```
   Cloud name: dmksbfd7h
   API Key: 862973714739146
   API Secret: **************** (hidden)
   ```

### Step 3: Reveal API Secret
1. Click the **eye icon** (👁️) next to API Secret
2. Copy the revealed secret (it's a long string like: `AbCdEfGhIjKlMnOpQrStUvWxYz123456`)

### Step 4: Update Your Code
1. Open `lib/services/cloudinary_service.dart`
2. Find line 13:
   ```dart
   static const String _apiSecret = 'YOUR_API_SECRET';
   ```
3. Replace `YOUR_API_SECRET` with your actual secret:
   ```dart
   static const String _apiSecret = 'AbCdEfGhIjKlMnOpQrStUvWxYz123456';
   ```

---

## 🚀 AFTER UPDATING

### 1. Install crypto package
```bash
flutter pub get
```

### 2. Rebuild app
```bash
flutter clean
flutter run
```

### 3. Test upload
- Send an image
- Look for: `MEDIA URL: https://res.cloudinary.com/dmksbfd7h/...`

---

## ✅ WHAT CHANGED

### Before (Unsigned Upload)
```dart
// Required upload preset
request.fields['upload_preset'] = 'ml_default';
```
**Problem**: Preset must be whitelisted

### After (Signed Upload)
```dart
// Uses API key + secret + signature
request.fields['api_key'] = _apiKey;
request.fields['timestamp'] = timestamp.toString();
request.fields['signature'] = signature;
```
**Solution**: No preset required!

---

## 🔒 SECURITY NOTE

### ⚠️ IMPORTANT: Keep API Secret Private

Your API Secret is like a password. **DO NOT**:
- ❌ Commit it to Git
- ❌ Share it publicly
- ❌ Post it in screenshots

### ✅ Best Practice

Add to `.gitignore`:
```
# Cloudinary secrets
lib/services/cloudinary_config.dart
```

Create separate config file:
```dart
// lib/services/cloudinary_config.dart
class CloudinaryConfig {
  static const String cloudName = 'dmksbfd7h';
  static const String apiKey = '862973714739146';
  static const String apiSecret = 'YOUR_SECRET_HERE';
}
```

---

## 🔍 VERIFICATION

After updating API secret, you should see:

### Console Output
```
[Cloudinary] Using SIGNED upload
[Cloudinary] Timestamp: 1234567890
[Cloudinary] Uploading 46829 bytes...
[Cloudinary] Response status: 200
[Cloudinary] ✅ SUCCESS!
MEDIA URL: https://res.cloudinary.com/dmksbfd7h/image/upload/...
```

### Success Indicators
- ✅ Response status: 200 (not 400)
- ✅ MEDIA URL appears
- ✅ Image appears in chat
- ✅ No "preset" error

---

## 🆘 TROUBLESHOOTING

### Error: "Invalid signature"
**Cause**: Wrong API secret
**Fix**: Double-check you copied the correct secret

### Error: "Invalid API key"
**Cause**: Wrong API key
**Fix**: Verify API key is `862973714739146`

### Error: "Unauthorized"
**Cause**: API credentials don't match
**Fix**: Get fresh credentials from dashboard

---

## 📝 QUICK CHECKLIST

- [ ] Go to Cloudinary Console
- [ ] Find API Secret in Account Details
- [ ] Click eye icon to reveal
- [ ] Copy the secret
- [ ] Update `cloudinary_service.dart` line 13
- [ ] Run `flutter pub get`
- [ ] Run `flutter clean && flutter run`
- [ ] Test image upload
- [ ] Look for "MEDIA URL" in console

---

## 🎉 EXPECTED RESULT

After configuring API secret:

```
[Cloudinary] 📷 IMAGE UPLOAD STARTED
[Cloudinary] Using SIGNED upload
[Cloudinary] Response status: 200
[Cloudinary] ✅ SUCCESS!
MEDIA URL: https://res.cloudinary.com/dmksbfd7h/image/upload/v1234/...
[ChatService] ✅ image message sent successfully
```

**No more "preset" errors! 🎊**

---

## 📞 NEED HELP?

If you can't find your API secret:

1. **Check email** - Cloudinary sends credentials on signup
2. **Reset credentials** - Settings → Security → Regenerate
3. **Contact support** - Cloudinary support can help

---

## 🚀 NEXT STEPS

1. Get API secret from dashboard
2. Update `cloudinary_service.dart`
3. Run `flutter pub get`
4. Test upload
5. Enjoy working media! 🎉

**The fix is simple - just need that API secret!** 🔑
