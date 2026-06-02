# ⚡ QUICK FIX - Upload Preset Error

## 🚨 THE PROBLEM

```
Error: "Upload preset must be whitelisted for unsigned uploads"
```

## ✅ THE SOLUTION

I've switched from **unsigned** to **signed** uploads. No preset needed!

---

## 🔧 WHAT YOU NEED TO DO

### 1. Get Your API Secret

1. Go to [Cloudinary Console](https://cloudinary.com/console)
2. Look for **Account Details** on dashboard
3. Click the **eye icon** (👁️) next to **API Secret**
4. Copy the secret (long string like: `AbCdEfGhIjKlMnOpQrStUvWxYz123456`)

### 2. Update Code

Open `lib/services/cloudinary_service.dart` and find line 13:

```dart
static const String _apiSecret = 'YOUR_API_SECRET';
```

Replace with your actual secret:

```dart
static const String _apiSecret = 'AbCdEfGhIjKlMnOpQrStUvWxYz123456';
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Rebuild and Test

```bash
flutter clean
flutter run
```

Then send an image and look for:
```
MEDIA URL: https://res.cloudinary.com/dmksbfd7h/...
```

---

## ✅ WHAT I CHANGED

### File: `lib/services/cloudinary_service.dart`

**Before (Unsigned)**:
```dart
request.fields['upload_preset'] = 'ml_default';
```

**After (Signed)**:
```dart
request.fields['api_key'] = _apiKey;
request.fields['timestamp'] = timestamp.toString();
request.fields['signature'] = signature;
```

### File: `pubspec.yaml`

**Added**:
```yaml
crypto: ^3.0.3
```

---

## 🎯 EXPECTED RESULT

### Before (Error)
```
Response status: 400
Error: "Upload preset must be whitelisted"
```

### After (Success)
```
Response status: 200
✅ SUCCESS!
MEDIA URL: https://res.cloudinary.com/dmksbfd7h/...
```

---

## 📋 QUICK CHECKLIST

- [ ] Get API secret from Cloudinary dashboard
- [ ] Update line 13 in `cloudinary_service.dart`
- [ ] Run `flutter pub get`
- [ ] Run `flutter clean && flutter run`
- [ ] Test image upload
- [ ] Verify "MEDIA URL" appears in console

---

## 🔒 SECURITY WARNING

**DO NOT commit your API secret to Git!**

Your API secret is sensitive. Keep it private.

---

## 🆘 IF STILL FAILING

Check these:

1. **API Secret is correct** - Copy from dashboard carefully
2. **API Key is correct** - Should be `862973714739146`
3. **Cloud Name is correct** - Should be `dmksbfd7h`
4. **Internet connection** - Must be online to upload

---

## 🎉 THAT'S IT!

Just 3 steps:
1. Get API secret
2. Update code
3. Run `flutter pub get`

**Then it will work!** 🚀

---

See `CLOUDINARY_API_SECRET_SETUP.md` for detailed instructions.
