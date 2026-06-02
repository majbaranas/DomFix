# 🧪 FCM TESTING GUIDE - Step by Step

## 📱 PREREQUISITES

- 2 physical devices (Android/iOS)
- Both devices logged in as different users
- Internet connection
- Firebase Cloud Function deployed

---

## ✅ TEST 1: Token Generation & Storage

### Steps:
1. Open app on Device A
2. Login as User A
3. Check Flutter debug logs

### Expected Logs:
```
[FCM] 🚀 Initializing FCM Service...
[FCM] ✅ Permission status: AuthorizationStatus.authorized
[FCM] 🔑 Token generated: eF3xK2pL9...
[FCM] ✅ Token saved to Firestore for user: userA123
```

### Verify in Firestore:
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to `users/userA123`
4. Check fields:
   - `fcmToken`: "eF3xK2pL9..." ✅
   - `fcmTokenUpdatedAt`: timestamp ✅

### ✅ PASS CRITERIA:
- Token appears in logs
- Token saved in Firestore
- No errors in logs

---

## ✅ TEST 2: Foreground Notification (App Open)

### Steps:
1. Device A: Login as User A
2. Device B: Login as User B
3. Device B: Keep app OPEN (foreground)
4. Device A: Navigate to chat with User B
5. Device A: Send message "Hello from A!"
6. Device B: Observe notification

### Expected on Device B:
- Local notification appears at top of screen
- Notification shows:
  - Title: "New Message from User A"
  - Body: "Hello from A!"
- Notification sound plays

### Expected Logs (Device B):
```
[FCM] 📬 Foreground notification received
[FCM] Title: New Message from User A
[FCM] Body: Hello from A!
[FCM] Data: {chatId: userA_userB, senderId: userA123}
[FCM] ✅ Local notification shown
```

### Expected Cloud Function Logs:
```bash
firebase functions:log
```
```
[FCM Function] 🚀 New message detected
[FCM Function] Chat ID: userA_userB
[FCM Function] Sender ID: userA123
[FCM Function] Receiver ID: userB456
[FCM Function] ✅ FCM token found: gH7yL...
[FCM Function] 📤 Sending notification...
[FCM Function] Title: New Message from User A
[FCM Function] Body: Hello from A!
[FCM Function] ✅ Notification sent successfully!
```

### ✅ PASS CRITERIA:
- Notification appears on Device B
- Correct sender name shown
- Correct message text shown
- No errors in logs

---

## ✅ TEST 3: Background Notification (App Minimized)

### Steps:
1. Device B: Minimize app (press home button)
2. Device A: Send another message "Are you there?"
3. Device B: Check notification tray

### Expected on Device B:
- System notification appears in notification tray
- Notification shows:
  - Title: "New Message from User A"
  - Body: "Are you there?"
  - App icon visible
- Notification badge on app icon (iOS)

### Expected Logs:
```
[FCM] 📬 Background notification received
[FCM] Title: New Message from User A
[FCM] Body: Are you there?
```

### ✅ PASS CRITERIA:
- Notification appears in system tray
- Notification persists until dismissed
- App icon shows badge (iOS)

---

## ✅ TEST 4: Notification Click Navigation

### Steps:
1. Device B: App in background
2. Device A: Send message "Click this!"
3. Device B: Receive notification
4. Device B: **Click notification**
5. Device B: Observe app behavior

### Expected on Device B:
- App opens automatically
- ChatScreen opens directly
- Shows conversation with User A
- Message "Click this!" visible
- Can reply immediately

### Expected Logs (Device B):
```
[FCM] 🔔 Notification clicked (background)
[FCM] Data: {chatId: userA_userB, senderId: userA123}
[App] 🚀 Navigating to chat: userA_userB
[App] ✅ Navigated to chat successfully
[ChatScreen] 💬 CHAT INITIALIZED
[ChatScreen] Chat ID: userA_userB
```

### ✅ PASS CRITERIA:
- App opens on notification click
- ChatScreen opens automatically
- Correct chat displayed
- Messages visible
- Can send reply

---

## ✅ TEST 5: Terminated App Notification

### Steps:
1. Device B: **Force close app** (swipe away from recent apps)
2. Device A: Send message "Wake up!"
3. Device B: Receive notification
4. Device B: Click notification

### Expected on Device B:
- App launches from scratch
- Splash screen appears briefly
- ChatScreen opens after initialization
- Message "Wake up!" visible

### Expected Logs (Device B):
```
[FCM] 🔔 Notification clicked (terminated)
[FCM] Data: {chatId: userA_userB, senderId: userA123}
[App] 🚀 Navigating to chat: userA_userB
```

### ✅ PASS CRITERIA:
- App launches successfully
- Navigation works after cold start
- Chat opens correctly

---

## ✅ TEST 6: Token Refresh

### Steps:
1. Device A: Keep app open for 24+ hours
   OR
2. Manually trigger refresh:
   ```dart
   await FirebaseMessaging.instance.deleteToken();
   await FCMService().initialize();
   ```

### Expected Logs:
```
[FCM] 🔄 Token refreshed: newToken123...
[FCM] ✅ Token saved to Firestore for user: userA123
```

### Verify in Firestore:
- `fcmToken` updated with new value
- `fcmTokenUpdatedAt` timestamp updated

### ✅ PASS CRITERIA:
- New token generated
- Token saved to Firestore
- Notifications still work with new token

---

## ✅ TEST 7: Multiple Messages (Stress Test)

### Steps:
1. Device A: Send 10 messages rapidly
2. Device B: Observe notifications

### Expected on Device B:
- All 10 notifications received
- Notifications appear in order
- No duplicates
- No missing messages

### Expected Cloud Function Logs:
```
[FCM Function] ✅ Notification sent successfully! (x10)
```

### ✅ PASS CRITERIA:
- All messages trigger notifications
- No errors in function logs
- No rate limiting issues

---

## ✅ TEST 8: Audio Message Notification

### Steps:
1. Device A: Send audio message (if implemented)
2. Device B: Receive notification

### Expected on Device B:
- Notification shows:
  - Title: "New Message from User A"
  - Body: "🎤 Audio message"

### ✅ PASS CRITERIA:
- Audio message triggers notification
- Body shows audio indicator
- Click opens chat correctly

---

## ✅ TEST 9: Logout Token Cleanup

### Steps:
1. Device A: Logout
2. Check Firestore

### Expected Logs:
```
[App] 👤 User logged out
[FCM] ✅ Token deleted
```

### Verify in Firestore:
- `fcmToken` field should be removed or empty
  OR
- Token should not be used for notifications

### ✅ PASS CRITERIA:
- Token deleted on logout
- No notifications sent to logged out user

---

## ✅ TEST 10: Permission Denied Scenario

### Steps:
1. Fresh install on Device C
2. Login as User C
3. **Deny** notification permission
4. Device A: Send message to User C

### Expected on Device C:
- No notification received (expected)
- App still works normally
- Messages visible when opening chat

### Expected Logs (Device C):
```
[FCM] ❌ User declined permission
```

### Expected Cloud Function Logs:
```
[FCM Function] ⚠️ Receiver has no FCM token
```

### ✅ PASS CRITERIA:
- App handles denied permission gracefully
- No crashes
- Chat still works

---

## 🐛 TROUBLESHOOTING

### Issue: No Notifications Received

**Check 1: Token Exists**
```
Firestore → users/{userId} → fcmToken
```

**Check 2: Function Deployed**
```bash
firebase functions:list
```

**Check 3: Function Logs**
```bash
firebase functions:log
```

**Check 4: Firestore Rules**
```javascript
// Must allow token updates
allow update: if request.auth != null;
```

### Issue: Notification Click Doesn't Navigate

**Check 1: Navigator Key**
```dart
// main.dart must have:
navigatorKey: navigatorKey
```

**Check 2: Callback Set**
```dart
_fcmService.onNotificationClick = (chatId, senderId) {
  _navigateToChat(chatId, senderId);
};
```

**Check 3: Logs**
```
Look for navigation errors in logs
```

### Issue: Foreground Notification Not Showing

**Check 1: Local Notifications Initialized**
```
[FCM] ✅ Local notifications initialized
```

**Check 2: Android Channel Created**
```
Check AndroidManifest.xml has notification channel
```

---

## 📊 TEST RESULTS TEMPLATE

```
TEST 1: Token Generation          [ ] PASS [ ] FAIL
TEST 2: Foreground Notification   [ ] PASS [ ] FAIL
TEST 3: Background Notification   [ ] PASS [ ] FAIL
TEST 4: Notification Click        [ ] PASS [ ] FAIL
TEST 5: Terminated App            [ ] PASS [ ] FAIL
TEST 6: Token Refresh             [ ] PASS [ ] FAIL
TEST 7: Multiple Messages         [ ] PASS [ ] FAIL
TEST 8: Audio Message             [ ] PASS [ ] FAIL
TEST 9: Logout Cleanup            [ ] PASS [ ] FAIL
TEST 10: Permission Denied        [ ] PASS [ ] FAIL

OVERALL: [ ] ALL PASS [ ] NEEDS FIXES
```

---

## 🎯 ACCEPTANCE CRITERIA

✅ User receives notification within 2 seconds of message sent  
✅ Notification shows correct sender name and message  
✅ Clicking notification opens correct chat  
✅ Works in foreground, background, and terminated states  
✅ Token auto-refreshes without user action  
✅ No crashes or errors in production  

---

## 📞 SUPPORT

If any test fails:
1. Check logs (Flutter + Cloud Functions)
2. Verify Firestore structure
3. Confirm Cloud Function deployed
4. Test on physical device (not emulator)

---

**Ready to test? Start with TEST 1! 🚀**
