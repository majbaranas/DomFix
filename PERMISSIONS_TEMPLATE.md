# 📋 PERMISSIONS TEMPLATE - COPY & PASTE

## 🤖 ANDROID PERMISSIONS

**File**: `android/app/src/main/AndroidManifest.xml`

**Add these lines inside `<manifest>` tag (before `<application>`)**:

```xml
<!-- Media Messaging Permissions -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**Full Example**:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- ADD THESE PERMISSIONS HERE -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    
    <application
        android:label="domfix"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        ...
    </application>
</manifest>
```

---

## 🍎 iOS PERMISSIONS

**File**: `ios/Runner/Info.plist`

**Add these lines inside `<dict>` tag**:

```xml
<!-- Media Messaging Permissions -->
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone to record audio messages</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to send images</string>
```

**Full Example**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>domfix</string>
    
    <!-- ADD THESE PERMISSIONS HERE -->
    <key>NSMicrophoneUsageDescription</key>
    <string>We need access to your microphone to record audio messages</string>
    <key>NSCameraUsageDescription</key>
    <string>We need access to your camera to take photos</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>We need access to your photo library to send images</string>
    
    <!-- Rest of your Info.plist -->
    ...
</dict>
</plist>
```

---

## 🔥 FIREBASE STORAGE RULES

**Update in Firebase Console** → Storage → Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to read/write chat media
    match /chats/{chatId}/{type}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

**Or update local file**: `storage.rules` (if you have it)

---

## ✅ VERIFICATION

After adding permissions, verify:

### Android
```bash
# Check if permissions are in manifest
cat android/app/src/main/AndroidManifest.xml | grep "RECORD_AUDIO"
cat android/app/src/main/AndroidManifest.xml | grep "CAMERA"
```

### iOS
```bash
# Check if permissions are in Info.plist
cat ios/Runner/Info.plist | grep "NSMicrophoneUsageDescription"
cat ios/Runner/Info.plist | grep "NSCameraUsageDescription"
```

---

## 🚨 IMPORTANT NOTES

1. **Restart App**: After adding permissions, restart the app completely
2. **Clean Build**: If permissions don't work, try:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
3. **Real Device**: Test on real device, not emulator (especially for audio)
4. **Grant Permissions**: When app asks for permissions, tap "Allow"

---

## 🎯 DONE!

After adding these permissions:
- ✅ Audio recording will work
- ✅ Camera will work
- ✅ Gallery access will work
- ✅ File uploads will work

**Now run the app and test!** 🚀
