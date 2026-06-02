# 🔧 BUILD FIX GUIDE

## ⚠️ If You Get Build Errors

### Issue 1: Gradle Daemon Crash / Memory Error

**Solution**: Increase Gradle memory

**File**: `android/gradle.properties`

Add these lines:
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.caching=true
```

Then run:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

---

### Issue 2: Core Library Desugaring Error

**Already Fixed!** The `build.gradle.kts` has been updated with:
```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

---

### Issue 3: Permission Errors

**Add to `android/app/src/main/AndroidManifest.xml`**:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**Add to `ios/Runner/Info.plist`**:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone to record audio messages</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to send images</string>
```

---

### Issue 4: Flutter Sound Package Error

**Already Fixed!** We're using `flutter_sound: ^9.2.13` which is stable.

---

## 🚀 Clean Build Steps

If you encounter any build issues, follow these steps:

### 1. Clean Everything
```bash
flutter clean
cd android
./gradlew clean
cd ..
```

### 2. Get Dependencies
```bash
flutter pub get
```

### 3. Rebuild
```bash
flutter run
```

---

## 🔍 Check Your Setup

### Verify Dependencies
```bash
flutter pub get
```

Should show:
- ✅ flutter_sound: ^9.2.13
- ✅ audioplayers: ^6.1.0
- ✅ image_picker: ^1.2.1
- ✅ file_picker: ^8.1.6
- ✅ firebase_storage: ^12.4.10
- ✅ permission_handler: ^11.3.1

### Verify Android Config
Check `android/app/build.gradle.kts`:
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
    isCoreLibraryDesugaringEnabled = true
}
```

---

## 💡 Alternative: Test Without Audio First

If audio recording is causing issues, you can test images and files first:

1. Comment out audio recording in `chat_screen.dart`:
```dart
// Temporarily disable audio
// onTap: _messageController.text.trim().isEmpty
//     ? () => setState(() => _isRecording = true)
//     : (_isSending ? null : _sendMessage),

onTap: _isSending ? null : _sendMessage,
```

2. Test image and file uploads first
3. Fix audio recording separately

---

## 🆘 Still Having Issues?

### Check Flutter Doctor
```bash
flutter doctor -v
```

### Check Android SDK
Make sure you have:
- ✅ Android SDK 33 or higher
- ✅ Java 17
- ✅ Gradle 8.x

### Check Device
- ✅ USB Debugging enabled
- ✅ Device connected: `flutter devices`
- ✅ Sufficient storage space

---

## ✅ Success Indicators

When build succeeds, you should see:
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Launching lib\main.dart on UMIDIGI X in debug mode...
```

Then test:
1. ✅ Text messages work
2. ✅ Tap + button shows menu
3. ✅ Pick image works
4. ✅ Pick file works
5. ✅ Tap mic button (if audio enabled)

---

## 📞 Quick Test Without Building

You can test the logic without running on device:

```bash
flutter analyze
```

Should show no errors in:
- ✅ chat_screen.dart
- ✅ firebase_storage_service.dart
- ✅ audio_recorder_widget.dart
- ✅ All message widgets

---

**Good luck!** 🚀
