# 🚀 FCM QUICK START - 5 MINUTES

## ⚡ FASTEST SETUP

### 1. Install Dependencies (30 seconds)
```bash
cd c:\Users\2023\AndroidStudioProjects\domfix
flutter pub get
```

### 2. Update Android (1 minute)

**File:** `android/app/src/main/AndroidManifest.xml`

Add inside `<application>`:
```xml
<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="chat_channel" />
```

Add before `<application>`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### 3. Deploy Cloud Function (2 minutes)
```bash
cd functions
npm install
firebase deploy --only functions
```

### 4. Test (1 minute)
1. Login on 2 devices
2. Send message from Device A
3. Device B receives notification ✅

---

## 📋 WHAT YOU GET

✅ **Push notifications** when user receives message  
✅ **Foreground notifications** (app open)  
✅ **Background notifications** (app closed)  
✅ **Click to open chat** automatically  
✅ **Token management** (auto-refresh)  
✅ **Debug logs** everywhere  

---

## 🔍 VERIFY IT WORKS

### Check 1: Token Saved
```
Firestore → users/{userId} → fcmToken field exists
```

### Check 2: Function Deployed
```bash
firebase functions:list
# Should show: sendMessageNotification
```

### Check 3: Notification Received
```
Send message → Other user gets notification
```

---

## 🐛 QUICK DEBUG

**No notification?**
```bash
firebase functions:log
# Check for errors
```

**No token?**
```
Check Flutter logs for:
[FCM] 🔑 Token generated
```

**Click doesn't work?**
```
Check logs for:
[App] 🚀 Navigating to chat
```

---

## 📁 FILES CHANGED

✅ `lib/main.dart` - FCM init  
✅ `lib/services/fcm_service.dart` - NEW  
✅ `lib/services/user_service.dart` - Added getUserById  
✅ `functions/index.js` - NEW  
✅ `functions/package.json` - NEW  
✅ `pubspec.yaml` - Added packages  

---

## 🎯 NOTIFICATION FORMAT

**Title:** "New Message from John"  
**Body:** "Hey, how are you?"  
**Click:** Opens ChatScreen automatically  

---

## ⚠️ IMPORTANT

- Test on **physical device** (emulators unreliable)
- **Android 13+** requires POST_NOTIFICATIONS permission
- **iOS** requires APNs key in Firebase Console
- Tokens auto-refresh every ~60 days

---

## 🚀 DEPLOY NOW

```bash
# 1. Get dependencies
flutter pub get

# 2. Deploy function
cd functions && npm install && firebase deploy --only functions

# 3. Run app
flutter run

# 4. Test!
```

---

**That's it! 🎉**

Full docs: `FCM_SETUP_COMPLETE.md`
