# 🚀 Quick Setup Guide - Media Messaging

## Step 1: Install Dependencies
```bash
flutter pub get
```

## Step 2: Update Android Permissions

**File**: `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>` tag:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

## Step 3: Update iOS Permissions

**File**: `ios/Runner/Info.plist`

Add inside `<dict>` tag:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone to record audio messages</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to send images</string>
```

## Step 4: Update Firebase Storage Rules

**File**: `firestore.rules` (or update in Firebase Console)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /chats/{chatId}/{type}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

## Step 5: Run the App
```bash
flutter run
```

---

## 🧪 Quick Test

1. **Text Message**: Type and send ✅
2. **Audio Message**: Tap mic button, record, send 🎤
3. **Image Message**: Tap +, select Photo, pick image 📷
4. **File Message**: Tap +, select File, pick PDF 📎

---

## ⚠️ Common Issues

### "Permission denied" error
- Make sure you added permissions to AndroidManifest.xml and Info.plist
- Restart the app after adding permissions

### "Storage upload failed"
- Check Firebase Storage rules
- Make sure user is authenticated
- Check internet connection

### Audio not recording
- Grant microphone permission
- Test on real device (not emulator)

### Images not loading
- Check Firebase Storage rules
- Verify image URL is valid
- Check internet connection

---

## 📱 Test on Real Device

**Android**:
```bash
flutter run -d <device-id>
```

**iOS**:
```bash
flutter run -d <device-id>
```

---

## ✅ Done!

Your chat now supports:
- 💬 Text messages
- 🎤 Audio messages
- 📷 Image messages
- 📎 File messages

**Happy coding!** 🎉
