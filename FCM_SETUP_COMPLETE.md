# 🔔 FCM Push Notification System - Complete Implementation

## ✅ WHAT WAS IMPLEMENTED

### 1. Flutter FCM Service (`lib/services/fcm_service.dart`)
- ✅ FCM token generation and management
- ✅ Token refresh handling
- ✅ Foreground notification display
- ✅ Background notification handling
- ✅ Notification click navigation
- ✅ Token storage in Firestore (`users/{userId}/fcmToken`)

### 2. Updated Main App (`lib/main.dart`)
- ✅ FCM initialization on user login
- ✅ Navigation handler for notification clicks
- ✅ Token cleanup on logout
- ✅ Global navigator key for deep linking

### 3. Cloud Function (`functions/index.js`)
- ✅ Triggers on new message: `chats/{chatId}/messages/{messageId}`
- ✅ Extracts receiver from chatId
- ✅ Fetches receiver's FCM token
- ✅ Sends push notification with message content
- ✅ Includes chatId and senderId in notification data

### 4. Updated Dependencies (`pubspec.yaml`)
- ✅ `firebase_messaging: ^15.1.6`
- ✅ `flutter_local_notifications: ^18.0.1`

---

## 📋 SETUP INSTRUCTIONS

### STEP 1: Install Flutter Dependencies

```bash
cd c:\Users\2023\AndroidStudioProjects\domfix
flutter pub get
```

### STEP 2: Android Configuration

#### A. Update `android/app/build.gradle`

Add inside `android` block:
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // FCM requires minimum SDK 21
    }
}
```

#### B. Update `android/app/src/main/AndroidManifest.xml`

Add inside `<application>` tag:
```xml
<!-- FCM Notification Channel -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="chat_channel" />

<!-- FCM Notification Icon -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@mipmap/ic_launcher" />

<!-- FCM Notification Color -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_color"
    android:resource="@color/notification_color" />
```

Add permissions before `<application>` tag:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### STEP 3: iOS Configuration

#### A. Update `ios/Runner/Info.plist`

Add before `</dict>`:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

#### B. Enable Push Notifications in Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" → Check "Remote notifications"

#### C. Upload APNs Key to Firebase Console
1. Go to Firebase Console → Project Settings
2. Cloud Messaging tab
3. iOS app configuration
4. Upload APNs Authentication Key (.p8 file)

### STEP 4: Deploy Firebase Cloud Function

```bash
cd c:\Users\2023\AndroidStudioProjects\domfix\functions

# Install dependencies
npm install

# Login to Firebase (if not already)
firebase login

# Deploy function
firebase deploy --only functions
```

**Expected Output:**
```
✔ functions[sendMessageNotification(us-central1)] Successful create operation.
Function URL: https://us-central1-YOUR-PROJECT.cloudfunctions.net/sendMessageNotification
```

### STEP 5: Update Firestore Security Rules

Add to `firestore.rules`:
```javascript
match /users/{userId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && request.auth.uid == userId;
  
  // Allow Cloud Functions to update FCM tokens
  allow update: if request.auth != null && 
                   request.resource.data.diff(resource.data).affectedKeys()
                   .hasOnly(['fcmToken', 'fcmTokenUpdatedAt']);
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

---

## 🔄 HOW IT WORKS

### Flow Diagram

```
User A sends message
        ↓
ChatService.sendMessage()
        ↓
Message saved to Firestore
chats/{chatId}/messages/{messageId}
        ↓
Cloud Function TRIGGERED
        ↓
Extract receiverId from chatId
        ↓
Fetch User B's fcmToken from Firestore
        ↓
Send FCM notification to User B
        ↓
User B receives notification
        ↓
User B clicks notification
        ↓
App opens ChatScreen with chatId
        ↓
Messages loaded and marked as seen
```

### Token Management Flow

```
User logs in
        ↓
FCMService.initialize()
        ↓
Request notification permission
        ↓
Generate FCM token
        ↓
Save to Firestore: users/{userId}/fcmToken
        ↓
Setup token refresh listener
        ↓
On token refresh → Update Firestore
        ↓
On logout → Delete token
```

---

## 🧪 TESTING GUIDE

### Test 1: Token Generation
1. Login to app
2. Check debug logs:
```
[FCM] 🔑 Token generated: eF3xK...
[FCM] ✅ Token saved to Firestore for user: abc123
```
3. Verify in Firestore:
   - Go to `users/{userId}`
   - Check `fcmToken` field exists

### Test 2: Foreground Notification
1. Open app on Device A (User A)
2. Open app on Device B (User B)
3. User A sends message to User B
4. User B should see local notification while app is open
5. Check logs:
```
[FCM] 📬 Foreground notification received
[FCM] Title: New Message from User A
[FCM] Body: Hello!
```

### Test 3: Background Notification
1. User B minimizes app (background)
2. User A sends message
3. User B receives system notification
4. Check Firebase Functions logs:
```
[FCM Function] ✅ Notification sent successfully!
```

### Test 4: Notification Click
1. User B receives notification
2. User B clicks notification
3. App opens to ChatScreen
4. Messages displayed correctly
5. Check logs:
```
[FCM] 🔔 Notification clicked
[App] 🚀 Navigating to chat: user1_user2
[App] ✅ Navigated to chat successfully
```

### Test 5: Token Refresh
1. Keep app open for 24+ hours
2. Token should auto-refresh
3. Check logs:
```
[FCM] 🔄 Token refreshed: gH7yL...
[FCM] ✅ Token saved to Firestore
```

---

## 🐛 DEBUG LOGS REFERENCE

### Flutter App Logs

**Token Generated:**
```
[FCM] 🔑 Token generated: eF3xK...
[FCM] ✅ Token saved to Firestore for user: abc123
```

**Notification Received (Foreground):**
```
[FCM] 📬 Foreground notification received
[FCM] Title: New Message from John
[FCM] Body: Hey, how are you?
[FCM] Data: {chatId: user1_user2, senderId: user1}
```

**Notification Clicked:**
```
[FCM] 🔔 Notification clicked (background)
[FCM] Data: {chatId: user1_user2, senderId: user1}
[App] 🚀 Navigating to chat: user1_user2
```

### Cloud Function Logs

**View in Firebase Console:**
```bash
firebase functions:log
```

**Successful Notification:**
```
[FCM Function] 🚀 New message detected
[FCM Function] Chat ID: user1_user2
[FCM Function] Sender ID: user1
[FCM Function] Receiver ID: user2
[FCM Function] ✅ FCM token found: eF3xK...
[FCM Function] 📤 Sending notification...
[FCM Function] ✅ Notification sent successfully!
```

**Error - No Token:**
```
[FCM Function] ⚠️ Receiver has no FCM token
```

---

## 📁 FILE STRUCTURE

```
domfix/
├── lib/
│   ├── main.dart                    ✅ UPDATED (FCM init + navigation)
│   ├── services/
│   │   ├── fcm_service.dart         ✅ NEW (FCM logic)
│   │   ├── chat_service.dart        ✅ EXISTING (no changes)
│   │   └── user_service.dart        ✅ UPDATED (added getUserById)
│   └── screens/
│       └── chat_screen.dart         ✅ EXISTING (no changes)
├── functions/
│   ├── index.js                     ✅ NEW (Cloud Function)
│   └── package.json                 ✅ NEW (Dependencies)
├── android/
│   └── app/
│       └── src/main/AndroidManifest.xml  ⚠️ NEEDS UPDATE
├── ios/
│   └── Runner/
│       └── Info.plist               ⚠️ NEEDS UPDATE
└── pubspec.yaml                     ✅ UPDATED (Dependencies)
```

---

## 🚨 COMMON ISSUES & FIXES

### Issue 1: No Token Generated
**Symptom:** `[FCM] ❌ Failed to get token`

**Fix:**
- Check `google-services.json` exists in `android/app/`
- Check `GoogleService-Info.plist` exists in `ios/Runner/`
- Run `flutter clean && flutter pub get`
- Rebuild app

### Issue 2: Notification Not Received
**Symptom:** Message sent but no notification

**Fix:**
- Check Cloud Function logs: `firebase functions:log`
- Verify receiver has `fcmToken` in Firestore
- Check Firestore rules allow token updates
- Verify Cloud Function is deployed

### Issue 3: Notification Click Doesn't Navigate
**Symptom:** Notification received but clicking does nothing

**Fix:**
- Check `navigatorKey` is set in MaterialApp
- Verify `onNotificationClick` callback is set
- Check logs for navigation errors
- Ensure ChatScreen route is accessible

### Issue 4: Permission Denied (Android 13+)
**Symptom:** No permission dialog shown

**Fix:**
- Add `POST_NOTIFICATIONS` permission to AndroidManifest.xml
- Request permission explicitly in code
- Target SDK 33+ requires runtime permission

---

## 🎯 NOTIFICATION CONTENT

### Title Format
```
"New Message from {senderName}"
```

### Body Format
```
{messageText}  // Truncated to 100 chars if longer
```

### Data Payload
```json
{
  "chatId": "user1_user2",
  "senderId": "user1",
  "messageId": "msg123",
  "type": "chat_message"
}
```

---

## 🔐 SECURITY CONSIDERATIONS

1. **Token Storage:** FCM tokens stored in Firestore with user-level security
2. **Cloud Function:** Only triggers on authenticated writes
3. **Notification Data:** Contains only IDs, no sensitive content
4. **Token Cleanup:** Tokens deleted on logout

---

## 📊 MONITORING

### Firebase Console
- **Functions:** Monitor execution count, errors, duration
- **Cloud Messaging:** Track delivery rates, open rates
- **Firestore:** Monitor token updates

### Debug Commands
```bash
# View function logs
firebase functions:log

# View specific function
firebase functions:log --only sendMessageNotification

# Real-time logs
firebase functions:log --follow
```

---

## 🚀 DEPLOYMENT CHECKLIST

- [ ] Run `flutter pub get`
- [ ] Update AndroidManifest.xml
- [ ] Update Info.plist (iOS)
- [ ] Deploy Cloud Function: `firebase deploy --only functions`
- [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
- [ ] Test on physical device (emulators have limitations)
- [ ] Test foreground notifications
- [ ] Test background notifications
- [ ] Test notification clicks
- [ ] Verify token storage in Firestore
- [ ] Check Cloud Function logs

---

## 📞 SUPPORT

If issues persist:
1. Check Firebase Console → Functions → Logs
2. Check Flutter debug logs
3. Verify Firestore structure matches expected format
4. Test with Firebase Cloud Messaging test tool

---

**Status:** ✅ READY FOR TESTING
**Last Updated:** 2024
**Version:** 1.0.0
