# 🔥 FIX: Firebase Storage 404 Error

## ❌ Error Found
```
E/StorageException: Object does not exist at location.
Code: -13010 HttpResult: 404
```

## 🎯 Root Cause
**Firebase Storage bucket is not properly configured or doesn't exist.**

---

## ✅ SOLUTION

### Step 1: Enable Firebase Storage

1. Go to **Firebase Console**: https://console.firebase.google.com
2. Select your project: **domfix**
3. Click **Storage** in left sidebar
4. Click **Get Started**
5. Click **Next** (keep default rules)
6. Select location (choose closest to you)
7. Click **Done**

### Step 2: Verify Storage Bucket

After enabling, you should see:
- ✅ Storage bucket URL: `gs://your-project.appspot.com`
- ✅ Files tab (empty for now)
- ✅ Rules tab

### Step 3: Update Storage Rules

Click **Rules** tab and paste:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /chats/{chatId}/{type}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

Click **Publish**.

### Step 4: Verify google-services.json

Check if `android/app/google-services.json` has storage bucket:

```json
{
  "project_info": {
    "storage_bucket": "your-project.appspot.com"  ← Should exist
  }
}
```

If missing, download new `google-services.json`:
1. Firebase Console → Project Settings
2. Your apps → Android app
3. Click **Download google-services.json**
4. Replace `android/app/google-services.json`

### Step 5: Rebuild App

```bash
flutter clean
flutter pub get
flutter run
```

---

## 🧪 Test Again

1. Open chat
2. Tap mic button
3. Record audio
4. Tap send
5. **Check logs** - should see:

```
[UPLOAD] 🎤 AUDIO UPLOAD STARTED
[UPLOAD] File size: 4965 bytes
[UPLOAD] Storage path: chats/.../audio/...
[UPLOAD] Starting upload...
[UPLOAD] ✅ Upload completed
[UPLOAD] ✅ SUCCESS!
[UPLOAD] Download URL: https://firebasestorage...
```

---

## 🔍 Verify Storage is Enabled

### Check in Firebase Console:
1. Go to Storage
2. Should see "Files" tab
3. Should NOT see "Get Started" button

### Check in google-services.json:
```bash
cat android/app/google-services.json | grep storage_bucket
```

Should show:
```
"storage_bucket": "your-project.appspot.com"
```

---

## 📊 What the Logs Show

### Current State (Before Fix):
```
[UPLOAD] Starting upload...
E/StorageException: Object does not exist at location.
E/StorageException: Code: -13010 HttpResult: 404
[UPLOAD] ❌ AUDIO UPLOAD FAILED
```

### Expected State (After Fix):
```
[UPLOAD] Starting upload...
[UPLOAD] ✅ Upload completed
[UPLOAD] State: TaskState.success
[UPLOAD] Getting download URL...
[UPLOAD] ✅ SUCCESS!
```

---

## ⚠️ Common Issues

### Issue 1: "Get Started" button still shows
**Fix**: Click it to enable Storage

### Issue 2: storage_bucket is empty in google-services.json
**Fix**: Download new google-services.json after enabling Storage

### Issue 3: Still getting 404
**Fix**: 
- Wait 1-2 minutes after enabling Storage
- Rebuild app completely
- Check Storage rules are published

---

## 🎯 Quick Checklist

- [ ] Firebase Storage enabled in console
- [ ] Storage bucket URL exists
- [ ] Storage rules published
- [ ] google-services.json has storage_bucket
- [ ] App rebuilt after changes
- [ ] Test audio upload

---

## 📝 Summary

**Problem**: Firebase Storage bucket not configured
**Solution**: Enable Storage in Firebase Console
**Result**: Audio/image/file uploads will work

**Do this now and test again!** 🚀
