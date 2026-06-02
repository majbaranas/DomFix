# 🚀 Firebase Auth - Quick Reference Card

## 📋 Essential Code Snippets

### Check if User is Logged In
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  print('User is logged in: ${user.uid}');
} else {
  print('User is not logged in');
}
```

### Get User Data from Firestore
```dart
final userData = await UserService().getUserData(uid);
final role = userData?['role'];
final onboardingDone = userData?['onboarding_done'];
```

### Create User in Firestore
```dart
await UserService().createUser(
  uid: uid,
  email: email,
  role: 'client', // or 'technician' or ''
  onboardingDone: false,
);
```

### Update User Role
```dart
await UserService().updateUserRole(uid, 'client');
```

### Update Onboarding Status
```dart
await UserService().updateOnboardingStatus(uid, true);
```

### Save to Local Cache
```dart
await LocalStorageService.saveUserSession(
  role: 'client',
  onboardingDone: false,
);
```

### Get from Local Cache
```dart
final role = await LocalStorageService.getUserRole();
final onboardingDone = await LocalStorageService.getOnboardingDone();
```

### Navigate Based on Auth
```dart
await NavigationService.navigateBasedOnAuth(context);
```

### Logout
```dart
await NavigationService.logout(context);
```

---

## 🔄 Common Workflows

### Registration Workflow
```dart
// 1. Register with Firebase Auth
final userCredential = await authService.registerWithEmailPassword(email, password);

// 2. Create Firestore document
await UserService().createUser(
  uid: userCredential.user!.uid,
  email: email,
  role: '', // Empty - will be set in role selection
);

// 3. Navigate to role selection
Navigator.pushReplacement(context, RoleSelectionScreen());
```

### Login Workflow
```dart
// 1. Login with Firebase Auth
await authService.signInWithEmailPassword(email, password);

// 2. Navigate (will fetch from Firestore automatically)
await NavigationService.navigateBasedOnAuth(context);
```

### Role Selection Workflow
```dart
// 1. Get current user
final user = FirebaseAuth.instance.currentUser!;

// 2. Update Firestore
await UserService().updateUserRole(user.uid, selectedRole);

// 3. Cache locally
await LocalStorageService.setUserRole(selectedRole);

// 4. Navigate
if (selectedRole == 'client') {
  Navigator.pushReplacement(context, ClientHomeScreen());
} else {
  Navigator.pushReplacement(context, TechnicianOnboardingFlow());
}
```

### App Start Workflow
```dart
// 1. Check Firebase Auth
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
  // Not logged in
  Navigator.pushReplacement(context, LoginScreen());
} else {
  // Logged in - navigate based on Firestore data
  await NavigationService.navigateBasedOnAuth(context);
}
```

### Logout Workflow
```dart
// 1. Sign out from Firebase
await FirebaseAuth.instance.signOut();

// 2. Clear local cache
await LocalStorageService.clearAll();

// 3. Navigate to login
Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => LoginScreen()),
  (route) => false,
);
```

---

## 📁 File Structure

```
lib/
├── services/
│   ├── auth_service.dart              # Firebase Auth operations
│   ├── user_service.dart              # Firestore operations ⭐
│   ├── local_storage_service.dart     # Local caching ⭐
│   └── firebase_navigation_service.dart # Navigation logic ⭐
│
└── screens/
    ├── splash_screen.dart             # App initialization
    ├── login_screen.dart              # Login
    ├── register_screen.dart           # Registration
    ├── role_selection_screen.dart     # Role selection
    ├── client_home_screen.dart        # Client dashboard
    └── technician_home_screen.dart    # Technician dashboard
```

---

## 🔥 Firestore Structure

```
users (collection)
  └── {uid} (document)
      ├── uid: string
      ├── email: string
      ├── role: "client" | "technician" | ""
      ├── onboarding_done: boolean
      ├── created_at: Timestamp
      └── updated_at: Timestamp
```

---

## 💾 Local Storage Keys

```
SharedPreferences:
├── is_logged_in: boolean
├── user_role: "client" | "technician"
├── onboarding_done: boolean
└── isFirstLaunch: boolean
```

---

## 🎯 Navigation Logic

```
FirebaseAuth.currentUser
    ↓
    ├─ null → LoginScreen
    │
    └─ exists
        ↓
        Fetch from Firestore
        ↓
        ├─ role = "" → RoleSelectionScreen
        │
        ├─ role = "client" → ClientHomeScreen
        │
        └─ role = "technician"
            ↓
            ├─ onboarding_done = false → TechnicianOnboardingFlow
            │
            └─ onboarding_done = true → TechnicianHomeScreen
```

---

## 🔒 Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null 
                         && request.auth.uid == userId;
    }
  }
}
```

---

## 🧪 Quick Test Commands

### Test Registration
```dart
// Register → Select role → Should see home screen
// Close app → Reopen → Should stay logged in
```

### Test Login
```dart
// Login → Should go directly to home screen
// No role selection if role already set
```

### Test Logout
```dart
// Logout → All data cleared
// Cannot go back to home screen
```

### Test Data Persistence
```dart
// 1. Login
// 2. Uninstall app
// 3. Reinstall app
// 4. Login again
// 5. Data should still be there (from Firestore)
```

---

## 🚨 Common Issues & Solutions

### Issue: User not staying logged in
**Solution:** Check if Firebase Auth is initialized in main.dart
```dart
await Firebase.initializeApp();
```

### Issue: Role not persisting
**Solution:** Make sure you're updating both Firestore and local storage
```dart
await UserService().updateUserRole(uid, role);
await LocalStorageService.setUserRole(role);
```

### Issue: Navigation not working
**Solution:** Use NavigationService.navigateBasedOnAuth()
```dart
await NavigationService.navigateBasedOnAuth(context);
```

### Issue: Data not syncing
**Solution:** Always fetch from Firestore on app start
```dart
final userData = await UserService().getUserData(uid);
```

---

## 📞 Quick Links

- **Complete Guide:** FIREBASE_AUTH_GUIDE.md
- **Migration Guide:** MIGRATION_GUIDE.md
- **Summary:** FIREBASE_IMPLEMENTATION_SUMMARY.md

---

## ✅ Checklist

Before deploying:
- [ ] Firebase configured (google-services.json)
- [ ] Firestore security rules set
- [ ] Test registration flow
- [ ] Test login flow
- [ ] Test logout flow
- [ ] Test data persistence
- [ ] Test role-based navigation
- [ ] Test onboarding flow

---

**Keep this card handy for quick reference!** 📌
