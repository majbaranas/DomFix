# 💬 DomFix Chat System - Developer Quick Reference

## 🚀 Quick Start

### 1. Navigate to Chat Screen
```dart
import 'package:domfix/screens/chat_screen.dart';

// Open chat with a user
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChatScreen(
      otherUserId: 'tech123',
      otherUserName: 'John Technician',
      otherUserRole: 'technician',
    ),
  ),
);
```

### 2. Send a Message (Automatic)
- User types message in ChatScreen
- Presses send button
- ChatService handles everything automatically

### 3. View All Chats
- Navigate to MessagesScreen
- Shows all conversations automatically
- Real-time updates

---

## 📦 Services

### ChatService
```dart
final chatService = ChatService();

// Generate chat ID (ALWAYS use this)
String chatId = chatService.generateChatId(userId1, userId2);

// Send text message
await chatService.sendMessage(
  chatId: chatId,
  receiverId: otherUserId,
  text: 'Hello!',
);

// Send audio message
await chatService.sendAudioMessage(
  chatId: chatId,
  receiverId: otherUserId,
  audioUrl: 'https://...',
);

// Get messages stream (real-time)
Stream<List<MessageModel>> messages = chatService.getMessagesStream(chatId);

// Get user's chats
Stream<QuerySnapshot> chats = chatService.getUserChats();
```

### UserService
```dart
final userService = UserService();

// Get user data
Map<String, dynamic>? userData = await userService.getUserData(userId);

// Update profile
await userService.updateProfileFields(
  userId,
  name: 'John Doe',
  profileImageUrl: 'https://...',
);
```

---

## 🎨 UI Components

### ChatScreen
- **Purpose**: One-on-one chat interface
- **Features**: Real-time messaging, auto-scroll, WhatsApp-style bubbles
- **Required params**: `otherUserId`, `otherUserName`
- **Optional params**: `otherUserRole`

### MessagesScreen
- **Purpose**: Chat list / inbox
- **Features**: Real-time chat list, search, last message preview
- **No params needed**: Automatically shows current user's chats

---

## 🔥 Firestore Structure

```
firestore
├── users/{uid}
│   ├── uid: string
│   ├── email: string
│   ├── name: string
│   ├── role: "user" | "technician"
│   ├── profileImage: string (URL)
│   └── onboardingCompleted: boolean
│
├── chats/{chatId}
│   ├── participants: [uid1, uid2]
│   ├── lastMessage: string
│   └── lastMessageTime: timestamp
│   │
│   └── messages/{messageId}
│       ├── senderId: string
│       ├── type: "text" | "audio"
│       ├── text: string?
│       ├── audioUrl: string?
│       └── createdAt: timestamp
│
└── technician_locations/{technicianId}
    ├── latitude: number
    ├── longitude: number
    └── updatedAt: timestamp
```

---

## ⚡ Key Rules

### 1. Chat ID Generation
```dart
// ✅ CORRECT - Always sorted
String chatId = chatService.generateChatId(uid1, uid2);

// ❌ WRONG - Don't create manually
String chatId = '${uid1}_${uid2}'; // May not match!
```

### 2. Message Timestamps
```dart
// ✅ CORRECT - Server timestamp
'createdAt': FieldValue.serverTimestamp()

// ❌ WRONG - Client timestamp
'createdAt': DateTime.now() // Inconsistent across devices
```

### 3. Chat Document Creation
```dart
// ✅ CORRECT - ChatService handles this automatically
await chatService.sendMessage(...);

// ❌ WRONG - Don't create manually unless needed
await firestore.collection('chats').doc(chatId).set(...);
```

---

## 🐛 Debugging

### Enable Debug Logs
All services use `debugPrint()`. Check console for:
```
[ChatService] Sending message
[ChatService] Current User ID: user123
[ChatService] Receiver ID: tech456
[ChatService] Chat ID: tech456_user123
[ChatService] Message sent successfully
```

### Common Issues

**Messages not appearing?**
- Check chatId is generated correctly (sorted UIDs)
- Verify chat document exists with participants array
- Check Firestore rules are deployed

**"Permission denied" error?**
- Deploy firestore.rules to Firebase Console
- Verify user is authenticated
- Check user is in participants array

**"Query requires an index" error?**
- Deploy firestore.indexes.json
- Or click the link in error to create index

---

## 🧪 Testing

### Test with 2 Devices/Emulators
1. Login as User A on Device 1
2. Login as User B on Device 2
3. User A opens chat with User B
4. User A sends message → Should appear on Device 2 instantly
5. User B replies → Should appear on Device 1 instantly

### Test Chat List
1. Send messages in multiple chats
2. Open MessagesScreen
3. Verify all chats appear
4. Verify last message shows correctly
5. Verify timestamps are correct

---

## 📚 Code Examples

### Example 1: Start Chat from Technician Card
```dart
// In find_technician_screen.dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: technician.uid,
          otherUserName: technician.name,
          otherUserRole: 'technician',
        ),
      ),
    );
  },
  child: Text('Chat'),
)
```

### Example 2: Display Chat List
```dart
// Already implemented in messages_screen.dart
// Just navigate to MessagesScreen
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => MessagesScreen()),
);
```

### Example 3: Custom Message Handling
```dart
// Listen to messages stream
StreamBuilder<List<MessageModel>>(
  stream: chatService.getMessagesStream(chatId),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final messages = snapshot.data!;
      return ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return Text(message.text ?? '');
        },
      );
    }
    return CircularProgressIndicator();
  },
)
```

---

## 🎯 Best Practices

1. **Always use ChatService methods** - Don't write to Firestore directly
2. **Use StreamBuilder** - For real-time updates
3. **Handle errors** - Wrap in try-catch and show user feedback
4. **Validate input** - Check message not empty before sending
5. **Use server timestamps** - Never use client DateTime.now()
6. **Generate chatId correctly** - Always use generateChatId()
7. **Check authentication** - Verify user is logged in before operations

---

## 🔒 Security

- ✅ Users can only read their own chats
- ✅ Users can only send messages to chats they're in
- ✅ Users cannot impersonate others (senderId validated)
- ✅ Users cannot edit messages (immutable)
- ✅ Users can only delete their own messages
- ✅ Role cannot be changed after creation

---

## 📊 Performance

- ✅ Indexed queries (fast)
- ✅ Real-time streams (efficient)
- ✅ Minimal reads (cost-effective)
- ✅ Pagination-ready (scalable)

---

## 🎉 You're Ready!

The chat system is production-ready and follows WhatsApp/Messenger patterns.

**Need help?** Check `CHAT_PRODUCTION_READY.md` for detailed deployment guide.
