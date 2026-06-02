# ⚡ Location Update - Quick Test Guide

## 🎯 Goal: Verify Location Updates Every 5 Seconds

**Duration**: 2 minutes

---

## 🧪 Test Steps

### Step 1: Open App (10 seconds)
1. **Login as Technician**
2. **Open Dashboard**
3. **Keep app in foreground**

### Step 2: Watch Console (30 seconds)

You should see this pattern repeating every 5 seconds:

```
⏰ Timer tick #1 - Publishing location...

========================================
UPDATING LOCATION...
========================================
✅ User authenticated: [your-uid]
📍 Permission status: LocationPermission.whileInUse
✅ Location permission granted
📍 Getting current position...
✅ Position obtained:
   Latitude: 40.7128
   Longitude: -74.0060
   Accuracy: 5.0m
🔥 Updating Firestore...
✅ Firestore updated successfully!
========================================
```

### Step 3: Check Firestore (30 seconds)

1. Open **Firebase Console**
2. Go to **Firestore Database**
3. Navigate to `technician_locations` collection
4. Find your document (your UID)
5. **Watch `updatedAt` field**

**Expected**: Timestamp refreshes every ~5 seconds

### Step 4: Verify Client Side (30 seconds)

1. **Open another device/emulator**
2. **Login as Client**
3. **Go to Pros → Map**
4. **Look for your technician**

**Expected**: 
- ✅ Technician appears on map
- ✅ Status shows "ONLINE" (green)
- ✅ "Last seen: X s ago" shows recent time (<10s)

---

## ✅ Success Criteria

All must be true:

- [x] Console shows "UPDATING LOCATION..." every 5 seconds
- [x] Console shows "✅ Firestore updated successfully!"
- [x] Firestore `updatedAt` refreshes every ~5 seconds
- [x] Client sees technician as "ONLINE"
- [x] No error messages in console

---

## ❌ Failure Indicators

If you see any of these, check the diagnostic guide:

### 1. No Console Logs
```
(nothing appears)
```
**Problem**: Dashboard not loading or logs not visible  
**Fix**: Run `flutter run -v`

### 2. Permission Denied
```
❌ ERROR: Location permission denied
```
**Problem**: Location permission not granted  
**Fix**: Grant permission in device settings

### 3. No Authenticated User
```
❌ ERROR: No authenticated user
```
**Problem**: Not logged in  
**Fix**: Logout and login again

### 4. Timer Not Ticking
```
✅ Periodic timer started successfully
(but no timer ticks appear)
```
**Problem**: App went to background or timer cancelled  
**Fix**: Keep app in foreground

### 5. GPS Timeout
```
❌ ERROR: TimeoutException after 0:00:10
```
**Problem**: GPS signal weak  
**Fix**: Go outside or near window

### 6. Firestore Error
```
❌ ERROR: [cloud_firestore/permission-denied]
```
**Problem**: Firestore rules blocking write  
**Fix**: Update Firestore security rules

---

## 🔧 Quick Fixes

### Fix 1: Grant Location Permission

**Android**:
```bash
adb shell pm grant com.example.domfix android.permission.ACCESS_FINE_LOCATION
```

**iOS**:
Settings → Privacy → Location Services → DomFix → "While Using"

### Fix 2: Check Firestore Rules

```javascript
match /technician_locations/{techId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && request.auth.uid == techId;
}
```

### Fix 3: Restart App

1. Close app completely
2. Reopen app
3. Login as technician
4. Check console logs

---

## 📊 Expected Timeline

```
0:00 - App opens
0:01 - Dashboard loads
0:02 - First location update
0:07 - Second location update (Timer tick #1)
0:12 - Third location update (Timer tick #2)
0:17 - Fourth location update (Timer tick #3)
```

---

## 🎯 What to Look For

### In Console
```
✅ GOOD: "UPDATING LOCATION..." appears every 5 seconds
✅ GOOD: "Firestore updated successfully!" appears
✅ GOOD: Latitude/Longitude values shown
✅ GOOD: Timer tick numbers incrementing

❌ BAD: No logs appear
❌ BAD: Error messages
❌ BAD: Timer stops after first update
```

### In Firestore
```
✅ GOOD: updatedAt timestamp is recent (<10 seconds)
✅ GOOD: Timestamp refreshes when you refresh page
✅ GOOD: lat/lng values are present

❌ BAD: updatedAt is old (>1 minute)
❌ BAD: Document doesn't exist
❌ BAD: lat/lng are 0 or null
```

### On Client Map
```
✅ GOOD: Technician appears on map
✅ GOOD: Status shows "ONLINE" in green
✅ GOOD: "Last seen: 3s ago" (recent)

❌ BAD: Technician doesn't appear
❌ BAD: Status shows "OFFLINE" in grey
❌ BAD: "Last seen: 2m ago" (old)
```

---

## 🚀 Next Steps

### If Test Passes ✅
**Congratulations!** Location updates are working correctly.

You can now:
1. Test with real device (not emulator)
2. Test while moving
3. Test with multiple technicians
4. Deploy to production

### If Test Fails ❌
1. Read [LOCATION_UPDATE_DIAGNOSTIC.md](./LOCATION_UPDATE_DIAGNOSTIC.md)
2. Check specific error in diagnostic guide
3. Apply suggested fix
4. Re-run this test

---

## 📞 Common Questions

**Q: How often should location update?**  
A: Every 5 seconds when app is in foreground

**Q: What if I see updates but Firestore doesn't change?**  
A: Check Firestore security rules

**Q: What if updates stop after 1 minute?**  
A: Check if app went to background or battery optimization killed timer

**Q: Can I change update interval?**  
A: Yes, modify `_publishInterval` in `technician_location_service.dart`

---

**Test Duration**: 2 minutes  
**Last Updated**: 2024  
**Status**: ✅ READY TO TEST
