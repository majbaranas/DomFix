# 🔥 FIX: Firestore Permission Denied Error

## ❌ Error You're Seeing
```
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

## 🔍 Root Cause
The Firestore security rules are blocking access to messages because the chat document doesn't exist yet or the rules are too strict.

---

## ✅ SOLUTION: Update Firestore Rules in Firebase Console

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Click **Firestore Database** in left menu
4. Click **Rules** tab

### Step 2: Replace Rules with This

Copy and paste these rules:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user is owner
    function isOwner(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }
    
    // USERS COLLECTION
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isOwner(userId) && 
                      request.resource.data.uid == userId &&
                      request.resource.data.email is string;
      allow update: if isOwner(userId) && 
                      (!resource.data.keys().hasAny(['role']) || 
                       request.resource.data.role == resource.data.role);
      allow delete: if isOwner(userId);
    }
    
    // CHATS COLLECTION - FIXED FOR MEDIA MESSAGES
    match /chats/{chatId} {
      // Allow read if user is participant
      allow read: if isAuthenticated() && 
                    request.auth.uid in resource.data.participants;
      
      // Allow create if user is in participants
      allow create: if isAuthenticated() && 
                      request.auth.uid in request.resource.data.participants &&
                      request.resource.data.participants.size() == 2;
      
      // Allow update if user is participant
      allow update: if isAuthenticated() && 
                      request.auth.uid in resource.data.participants;
      
      // Allow delete if user is participant
      allow delete: if isAuthenticated() && 
                      request.auth.uid in resource.data.participants;
      
      // MESSAGES SUBCOLLECTION - FIXED
      match /messages/{messageId} {
        // Allow read if chat exists and user is participant
        allow read: if isAuthenticated() && 
                      (exists(/databases/$(database)/documents/chats/$(chatId)) &&
                       request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants);
        
        // Allow create if user is sender and participant
        allow create: if isAuthenticated() && 
                        request.resource.data.senderId == request.auth.uid &&
                        (exists(/databases/$(database)/documents/chats/$(chatId)) &&
                         request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants);
        
        // Allow update for marking as seen
        allow update: if isAuthenticated() && 
                        (exists(/databases/$(database)/documents/chats/$(chatId)) &&
                         request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants);
        
        // Allow delete only for own messages
        allow delete: if isAuthenticated() && 
                        resource.data.senderId == request.auth.uid;
      }
    }
    
    // TECHNICIAN LOCATIONS COLLECTION
    match /technician_locations/{technicianId} {
      allow read: if isAuthenticated();
      allow create, update: if isOwner(technicianId);
      allow delete: if isOwner(technicianId);
    }
    
    // Deny all other collections by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Publish Rules
1. Click **Publish** button
2. Wait for confirmation

---

## 🧪 Test After Publishing

1. Close and reopen your app
2. Navigate to chat screen
3. Messages should now load
4. Try sending a text message

---

## 🔧 Alternative: Temporary Open Rules (FOR TESTING ONLY)

If you want to test quickly, use these TEMPORARY rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

⚠️ **WARNING**: These rules allow ANY authenticated user to read/write EVERYTHING. Only use for testing, then switch back to secure rules above.

---

## 📊 What Changed

### Before (Broken)
- Rules didn't check if chat exists before accessing
- Messages couldn't be updated (needed for "seen" status)

### After (Fixed)
- ✅ Checks if chat exists with `exists()`
- ✅ Allows message updates for seen status
- ✅ Maintains security (only participants can access)

---

## 🎯 Expected Behavior After Fix

✅ Chat screen loads without errors
✅ Messages display correctly
✅ Can send text messages
✅ Can send media messages
✅ Real-time updates work
✅ Seen status updates work

---

## 🆘 Still Not Working?

### Check 1: User is Authenticated
In your app logs, verify:
```
[App] 👤 User authenticated: [USER_ID]
```

### Check 2: Chat Document Exists
In Firebase Console → Firestore → chats collection:
- Should see a document with ID like `userId1_userId2`
- Document should have `participants` array with both user IDs

### Check 3: Rules Published
In Firebase Console → Firestore → Rules:
- Check "Last published" timestamp
- Should be recent (within last few minutes)

---

## 🚀 Quick Fix Commands

If you have Firebase CLI installed:

```bash
# Deploy rules from local file
firebase deploy --only firestore:rules

# Or update directly in console (recommended)
```

---

## ✅ Success Indicators

After fixing, you should see:
- ✅ No error messages in chat
- ✅ Messages load successfully
- ✅ Can send and receive messages
- ✅ Real-time updates work

---

**Update the rules in Firebase Console now!** 🔥
