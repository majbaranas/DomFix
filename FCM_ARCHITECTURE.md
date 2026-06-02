# 🎨 FCM ARCHITECTURE - Visual Guide

## 📊 SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                         DOMFIX FCM SYSTEM                        │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐                                    ┌──────────────┐
│   DEVICE A   │                                    │   DEVICE B   │
│  (Sender)    │                                    │  (Receiver)  │
└──────┬───────┘                                    └──────▲───────┘
       │                                                   │
       │ 1. Send Message                                  │ 6. Receive
       │    "Hello!"                                      │    Notification
       ▼                                                   │
┌─────────────────────────────────────────────────────────┴───────┐
│                      FIREBASE FIRESTORE                          │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  chats/userA_userB/messages/msg123                         │ │
│  │  {                                                          │ │
│  │    senderId: "userA",                                       │ │
│  │    text: "Hello!",                                          │ │
│  │    createdAt: timestamp                                     │ │
│  │  }                                                          │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ 2. Firestore Trigger
                               │    onCreate()
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│              FIREBASE CLOUD FUNCTION                             │
│              sendMessageNotification()                           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  1. Extract chatId: "userA_userB"                          │ │
│  │  2. Determine receiver: "userB"                            │ │
│  │  3. Fetch fcmToken from users/userB                        │ │
│  │  4. Get sender name from users/userA                       │ │
│  │  5. Build notification payload                             │ │
│  │  6. Send via FCM                                           │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ 3. Send Notification
                               │    via FCM API
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                   FIREBASE CLOUD MESSAGING                       │
│                         (FCM Server)                             │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ 4. Push to Device
                               │    using fcmToken
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DEVICE B (Receiver)                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  FCMService.onMessage()                                    │ │
│  │  ├─ Foreground: Show local notification                   │ │
│  │  └─ Background: System notification                       │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  5. User Clicks Notification                                    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  FCMService.onNotificationClick()                          │ │
│  │  └─ Navigate to ChatScreen(chatId, senderId)              │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 TOKEN LIFECYCLE

```
┌─────────────────────────────────────────────────────────────────┐
│                      TOKEN MANAGEMENT FLOW                       │
└─────────────────────────────────────────────────────────────────┘

USER LOGIN
    │
    ▼
┌─────────────────────┐
│ FCMService.init()   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────┐
│ Request Permission          │
│ ├─ Android: Auto-granted    │
│ └─ iOS: User prompt         │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ Generate FCM Token          │
│ Token: "eF3xK2pL9..."       │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ Save to Firestore           │
│ users/{userId}/fcmToken     │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ Setup Listeners             │
│ ├─ Token Refresh            │
│ ├─ Foreground Messages      │
│ ├─ Background Messages      │
│ └─ Notification Clicks      │
└──────────┬──────────────────┘
           │
           ▼
    ┌──────────────┐
    │ TOKEN ACTIVE │ ◄──────────┐
    └──────┬───────┘            │
           │                    │
           │ Every ~60 days     │
           ▼                    │
    ┌──────────────┐            │
    │ Token Refresh│────────────┘
    └──────────────┘
           │
           │ USER LOGOUT
           ▼
    ┌──────────────┐
    │ Delete Token │
    └──────────────┘
```

---

## 📱 NOTIFICATION STATES

```
┌─────────────────────────────────────────────────────────────────┐
│                    APP STATE HANDLING                            │
└─────────────────────────────────────────────────────────────────┘

STATE 1: FOREGROUND (App Open)
┌─────────────────────────────────────────────────────────────────┐
│  Message Arrives                                                 │
│       │                                                          │
│       ▼                                                          │
│  FirebaseMessaging.onMessage                                    │
│       │                                                          │
│       ▼                                                          │
│  Show Local Notification                                        │
│  ┌──────────────────────────────────────┐                      │
│  │  🔔 New Message from John            │                      │
│  │  Hey, how are you?                   │                      │
│  └──────────────────────────────────────┘                      │
│       │                                                          │
│       ▼                                                          │
│  User Clicks → Navigate to ChatScreen                           │
└─────────────────────────────────────────────────────────────────┘

STATE 2: BACKGROUND (App Minimized)
┌─────────────────────────────────────────────────────────────────┐
│  Message Arrives                                                 │
│       │                                                          │
│       ▼                                                          │
│  System Notification (Automatic)                                │
│  ┌──────────────────────────────────────┐                      │
│  │  DomFix                              │                      │
│  │  🔔 New Message from John            │                      │
│  │  Hey, how are you?                   │                      │
│  └──────────────────────────────────────┘                      │
│       │                                                          │
│       ▼                                                          │
│  User Clicks → App Opens → Navigate to ChatScreen              │
└─────────────────────────────────────────────────────────────────┘

STATE 3: TERMINATED (App Closed)
┌─────────────────────────────────────────────────────────────────┐
│  Message Arrives                                                 │
│       │                                                          │
│       ▼                                                          │
│  System Notification (Automatic)                                │
│  ┌──────────────────────────────────────┐                      │
│  │  DomFix                              │                      │
│  │  🔔 New Message from John            │                      │
│  │  Hey, how are you?                   │                      │
│  └──────────────────────────────────────┘                      │
│       │                                                          │
│       ▼                                                          │
│  User Clicks → App Launches → Navigate to ChatScreen           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗂️ FIRESTORE STRUCTURE

```
firestore/
│
├── users/
│   ├── userA123/
│   │   ├── uid: "userA123"
│   │   ├── name: "John Doe"
│   │   ├── email: "john@example.com"
│   │   ├── role: "client"
│   │   ├── fcmToken: "eF3xK2pL9..."          ◄── FCM TOKEN
│   │   └── fcmTokenUpdatedAt: timestamp       ◄── TOKEN TIMESTAMP
│   │
│   └── userB456/
│       ├── uid: "userB456"
│       ├── name: "Jane Smith"
│       ├── email: "jane@example.com"
│       ├── role: "technician"
│       ├── fcmToken: "gH7yL4mN8..."          ◄── FCM TOKEN
│       └── fcmTokenUpdatedAt: timestamp       ◄── TOKEN TIMESTAMP
│
└── chats/
    └── userA123_userB456/                     ◄── CHAT ID (sorted)
        ├── participants: ["userA123", "userB456"]
        ├── lastMessage: "Hello!"
        ├── lastMessageTime: timestamp
        │
        └── messages/                          ◄── TRIGGER POINT
            ├── msg001/
            │   ├── senderId: "userA123"
            │   ├── text: "Hello!"
            │   ├── type: "text"
            │   ├── createdAt: timestamp
            │   └── isSeen: false
            │
            └── msg002/                        ◄── NEW MESSAGE
                ├── senderId: "userA123"       ◄── TRIGGERS FUNCTION
                ├── text: "How are you?"
                ├── type: "text"
                ├── createdAt: timestamp
                └── isSeen: false
```

---

## 🔐 SECURITY FLOW

```
┌─────────────────────────────────────────────────────────────────┐
│                      SECURITY LAYERS                             │
└─────────────────────────────────────────────────────────────────┘

LAYER 1: Firestore Rules
┌─────────────────────────────────────────────────────────────────┐
│  users/{userId}                                                  │
│  ├─ read: if authenticated                                      │
│  └─ write: if authenticated AND userId == auth.uid              │
│                                                                  │
│  chats/{chatId}                                                  │
│  ├─ read: if authenticated AND user in participants             │
│  └─ write: if authenticated AND user in participants            │
└─────────────────────────────────────────────────────────────────┘

LAYER 2: Cloud Function Authentication
┌─────────────────────────────────────────────────────────────────┐
│  ✓ Only triggers on authenticated writes                        │
│  ✓ Validates chatId format                                      │
│  ✓ Verifies sender is participant                               │
│  ✓ Checks receiver exists                                       │
└─────────────────────────────────────────────────────────────────┘

LAYER 3: FCM Token Security
┌─────────────────────────────────────────────────────────────────┐
│  ✓ Token stored per-user (not shared)                           │
│  ✓ Token deleted on logout                                      │
│  ✓ Token auto-refreshes (prevents stale tokens)                 │
│  ✓ Only Cloud Function can send notifications                   │
└─────────────────────────────────────────────────────────────────┘

LAYER 4: Notification Data
┌─────────────────────────────────────────────────────────────────┐
│  ✓ Contains only IDs (no sensitive data)                        │
│  ✓ Message content in notification body (encrypted in transit)  │
│  ✓ User must authenticate to view full chat                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚡ PERFORMANCE METRICS

```
┌─────────────────────────────────────────────────────────────────┐
│                      EXPECTED LATENCY                            │
└─────────────────────────────────────────────────────────────────┘

Message Sent → Firestore Write:           ~50-100ms
Firestore Write → Function Trigger:       ~100-200ms
Function Execution:                        ~200-500ms
FCM Send → Device Receive:                 ~500-1000ms
─────────────────────────────────────────────────────────
TOTAL: Message Sent → Notification:       ~1-2 seconds

┌─────────────────────────────────────────────────────────────────┐
│                      OPTIMIZATION TIPS                           │
└─────────────────────────────────────────────────────────────────┘

✓ Use batch writes (already implemented)
✓ Cache user data in function (reduce Firestore reads)
✓ Use FCM topics for group notifications
✓ Implement notification throttling for spam prevention
✓ Monitor function execution time in Firebase Console
```

---

## 🎯 DATA FLOW DIAGRAM

```
USER A SENDS MESSAGE
        │
        ▼
┌───────────────────┐
│  ChatService      │
│  sendMessage()    │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Firestore        │
│  Write Message    │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Cloud Function   │
│  Triggered        │
└────────┬──────────┘
         │
         ├─────────────────┐
         │                 │
         ▼                 ▼
┌─────────────────┐  ┌─────────────────┐
│  Get Receiver   │  │  Get Sender     │
│  FCM Token      │  │  Name           │
└────────┬────────┘  └────────┬────────┘
         │                    │
         └──────────┬─────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │  Build Notification │
         │  Payload            │
         └──────────┬──────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │  Send via FCM API   │
         └──────────┬──────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │  FCM Server         │
         │  Routes to Device   │
         └──────────┬──────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │  USER B DEVICE      │
         │  Receives           │
         └─────────────────────┘
```

---

## 📊 MONITORING DASHBOARD

```
┌─────────────────────────────────────────────────────────────────┐
│                    FIREBASE CONSOLE METRICS                      │
└─────────────────────────────────────────────────────────────────┘

CLOUD FUNCTIONS
├─ Invocations:        Track function execution count
├─ Execution Time:     Monitor latency (target: <500ms)
├─ Memory Usage:       Check for memory leaks
└─ Error Rate:         Alert on failures (target: <1%)

CLOUD MESSAGING
├─ Sent:               Total notifications sent
├─ Delivered:          Successfully delivered (target: >95%)
├─ Opened:             User engagement rate
└─ Failed:             Track delivery failures

FIRESTORE
├─ Reads:              Monitor token fetches
├─ Writes:             Track token updates
└─ Document Count:     Monitor users collection growth
```

---

**Visual guide complete! 🎨**

See `FCM_SETUP_COMPLETE.md` for implementation details.
