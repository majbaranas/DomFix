# 🔍 CLIENT → TECHNICIAN FLOW DEBUG GUIDE

## Overview
This guide helps debug the client → technician interaction flow that was working before the recent Firestore Rules / review system changes.

## 🎯 What We're Testing

### Flow Steps:
1. **Client opens nearby technicians map** ✅ Working
2. **Client sees technician pins** ✅ Working  
3. **Client clicks technician profile** ⚠️ Sometimes fails
4. **Client clicks "Message" button** ❌ Permission denied
5. **Client clicks "Book" button** ❌ Fails

## 🔬 Debug Logging Added

We've added comprehensive debug logs to track the exact failure points:

### 1. Profile Loading (`technician_profile_screen.dart`)
- Logs when profile fetch starts
- Logs document existence check
- Logs stats/reviews/photos fetching
- Logs any errors with full stack trace

### 2. Chat Creation (`booking_service.dart`)
- Logs ensureConversationShell flow
- Logs current user IDs
- Logs chatId generation
- Logs chat document creation
- Logs permission errors

### 3. Message Opening (`technician_profile_screen.dart`)
- Logs when message button is clicked
- Logs authentication state
- Logs chat shell creation
- Logs navigation to chat screen

### 4. Booking Creation (`booking_service.dart`)
- Logs all booking parameters
- Logs slot availability check
- Logs batch write operations
- Logs commit success/failure

## 📱 How to Test

### Step 1: Run the App with Logs
```bash
cd d:\FlutterProjects\DomFix
flutter run
```

### Step 2: Watch the Console
Keep your terminal visible to see the debug logs in real-time.

### Step 3: Test Each Flow

#### Test A: Profile Loading
1. Open the app as CLIENT
2. Go to nearby technicians map
3. Click on a technician pin
4. Click "Profile"
5. **Watch for logs starting with** `[TechnicianProfile]`

**Expected logs:**
```
[TechnicianProfile] 🔵 _fetchProfile called
[TechnicianProfile]   technicianId: <uid>
[TechnicianProfile] 📖 Fetching technician document...
[TechnicianProfile] ✅ Technician document found
[TechnicianProfile]   Document data keys: [uid, fullName, email, role, ...]
[TechnicianProfile] ✅ Profile parsed successfully
[TechnicianProfile] 📖 Fetching technician stats...
[TechnicianProfile] ✅ Stats fetched: avgRating=4.5, totalReviews=10
[TechnicianProfile] 📖 Fetching reviews...
[TechnicianProfile] ✅ Reviews fetched: count=5
[TechnicianProfile] 📖 Fetching work photos...
[TechnicianProfile] ✅ Photos fetched: count=3
[TechnicianProfile] ✅ Profile loading complete
```

**If it fails, you'll see:**
```
[TechnicianProfile] ❌ ERROR in _fetchProfile: <error message>
[TechnicianProfile] StackTrace: <full stack trace>
```

#### Test B: Message Button
1. From the technician profile, click "Message"
2. **Watch for logs starting with** `[TechnicianProfile]` and `[BookingService]`

**Expected logs:**
```
[TechnicianProfile] 🔵 _openMessageChat called
[TechnicianProfile]   technicianId: <uid>
[TechnicianProfile]   technicianName: John Doe
[TechnicianProfile]   currentUserId: <client_uid>
[TechnicianProfile] 📝 Calling ensureConversationShell...
[BookingService] 🔵 ensureConversationShell called
[BookingService]   clientId: <client_uid>
[BookingService]   technicianId: <tech_uid>
[BookingService]   technicianName: John Doe
[BookingService]   chatId: <generated_chat_id>
[BookingService] 📖 Checking if chat exists...
[BookingService] 📝 Chat does not exist, creating new chat shell...
[BookingService] ✅ Chat shell created successfully
[TechnicianProfile] ✅ Chat shell ensured
[TechnicianProfile] 📱 Navigating to ChatScreen...
[TechnicianProfile] ✅ Navigation complete
```

**If it fails with permission denied:**
```
[BookingService] ❌ ERROR in ensureConversationShell: [cloud_firestore/permission-denied] ...
[BookingService] StackTrace: ...
```

#### Test C: Booking Creation
1. From the profile, click "Book Now"
2. Fill in the booking form
3. Submit the booking
4. **Watch for logs starting with** `[BookingService]`

**Expected logs:**
```
[BookingService] 🔵 createBooking called
[BookingService]   clientId: <client_uid>
[BookingService]   technicianId: <tech_uid>
[BookingService]   serviceName: Plumbing Repair
[BookingService]   scheduledAt: 2025-01-15 14:00:00
[BookingService]   chatId: <chat_id>
[BookingService]   bookingId: <booking_id>
[BookingService] 🔍 Checking slot availability...
[BookingService] ✅ Slot is available
[BookingService] 📝 Creating batch write...
[BookingService] 💾 Committing batch...
[BookingService] ✅ Booking created successfully
```

**If it fails:**
```
[BookingService] ❌ ERROR committing batch: [cloud_firestore/permission-denied] ...
[BookingService] StackTrace: ...
```

## 🔥 Common Issues to Look For

### Issue 1: Permission Denied on Chat Creation
**Log pattern:**
```
[cloud_firestore/permission-denied] Missing or insufficient permissions
```

**Likely cause:**
- User not authenticated
- Participants array validation failing
- Chat document structure mismatch

**Check:**
1. Is `currentUserId` valid and not empty?
2. Are both UIDs in the participants array?
3. Does the chat document have all required fields?

### Issue 2: Profile Loading Fails
**Log pattern:**
```
[TechnicianProfile] ❌ Technician document does not exist
```

**Likely cause:**
- Technician UID from map doesn't match users collection
- technician_locations collection has wrong UID
- Document was deleted

**Check:**
1. Compare technician UID from map vs. users collection
2. Check if document exists in Firestore Console
3. Verify role field = 'technician'

### Issue 3: Booking Creation Fails
**Log pattern:**
```
[BookingService] ❌ ERROR committing batch: ...
```

**Likely causes:**
- Missing required fields in booking document
- participants array validation failing  
- clientId != current user UID

**Check:**
1. Are clientId and technicianId valid?
2. Is participants array exactly 2 elements?
3. Is status = 'pending'?

## 🛠️ Next Steps After Identifying Issue

### If Permission Denied on Chat:
1. Copy the exact error message
2. Copy the chatId from logs
3. Copy both clientId and technicianId
4. Check Firestore Rules for chats collection
5. Verify participants array format

### If Profile Not Found:
1. Copy the technicianId from logs
2. Go to Firebase Console → Firestore
3. Check if `users/{technicianId}` exists
4. Check if role = 'technician'
5. Check technician_locations collection

### If Booking Fails:
1. Copy the exact error message
2. Copy bookingId, clientId, technicianId from logs
3. Check if user is authenticated
4. Check Firestore Rules for bookings collection
5. Verify all required fields are present

## 📊 Firestore Rules Reference

### Current Rules for Key Collections:

#### users/{userId}
```javascript
allow read: if isAuthenticated();
```
✅ Any authenticated user can read any user profile

#### chats/{chatId}
```javascript
allow read: if isAuthenticated() &&
              (resource == null ||
               request.auth.uid in resource.data.participants);
allow create: if isAuthenticated() &&
                request.auth.uid in request.resource.data.participants &&
                request.resource.data.participants.size() == 2;
```
✅ Allows reading non-existent docs and creating chats

#### bookings/{bookingId}
```javascript
allow read: if isAuthenticated();
allow create: if isAuthenticated() &&
                request.resource.data.clientId == request.auth.uid &&
                request.auth.uid in request.resource.data.participants &&
                request.resource.data.participants.size() == 2 &&
                request.resource.data.status == 'pending';
```
✅ Allows creating bookings with validation

## 📝 Report Format

After testing, provide this information:

```
ISSUE: [Brief description]

FLOW STEP: [Which step failed - Profile/Message/Booking]

ERROR MESSAGE: [Exact error from logs]

LOGS:
[Paste relevant logs here]

USER IDS:
- Client UID: <uid>
- Technician UID: <uid>
- Chat ID: <chatId>
- Booking ID: <bookingId> (if applicable)

ADDITIONAL INFO:
[Any other relevant details]
```

## 🎬 After You Test

Once you've run through all test cases and captured the logs, share:
1. Which flows are working ✅
2. Which flows are failing ❌  
3. The complete error messages
4. The full log output for failed flows

This will help pinpoint the exact issue and fix it surgically without breaking anything else.
