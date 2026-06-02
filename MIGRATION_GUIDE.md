# 🔄 Migration Guide - From Local to Firebase Authentication

## 📋 Overview

This guide explains the migration from a **SharedPreferences-based** authentication system to a **Firebase + Firestore** authentication system.

---

## 🔀 What Changed

### Before (Local Storage Only)
```
SharedPreferences = Source of Truth
├─ user_role
├─ onboarding_completed
└─ isLoggedIn
```

### After (Firebase + Local Cache)
```
Firebase Auth = Authentication
Firestore = Source of Truth
SharedPreferences = Session Cache
```

---

## 📁 File Changes

### ❌ Deprecated Files
- `preferences_service.dart` → Replaced by `local_storage_service.dart`
- `navigation_service.dart` → Replaced by `firebase_navigation_service.dart`

### ✅ New Files
1. **user_service.dart** - Firestore operations
2. **local_storage_service.dart** - Local caching only
3. **firebase_navigation_service.dart** - Firebase-based navigation

### 🔄 Updated Files
- splash_screen.dart
- login_screen.dart
- register_screen.dart
- role_selection_screen.dart
- settings_screen.dart
- onboarding_screen.dart

---

## 🔑 Key Differences

### 1. Authentication Check

**Before:**
```dart
final isLoggedIn = await PreferencesService.isLoggedIn();
if (isLoggedIn) {
  // Navigate to home
}
```

**After:**
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  // Fetch data from Firestore
  final userData = await UserService().getUserData(user.uid);
  // Navigate based on Firestore data
}
```

### 2. Role Storage

**Before:**
```dart
// Only in SharedPreferences
await PreferencesService.setUserRole('client');
```

**After:**
```dart
// 1. Save to Firestore (source of truth)
await UserService().updateUserRole(uid, 'client');

// 2. Cache locally
await LocalStorageService.setUserRole('client');
```

### 3. App Start Logic

**Before:**
```dart
// Check local storage
final isLoggedIn = await PreferencesService.isLoggedIn();
final role = await PreferencesService.getUserRole();

// Navigate based on local data
if (role == 'client') {
  Navigator.push(context, ClientHomeScreen());
}
```

**After:**
```dart
// Check Firebase Auth
final user = FirebaseAuth.instance.currentUser;

if (user != null) {
  // Fetch from Firestore
  final userData = await UserService().getUserData(user.uid);
  
  // Cache locally
  await LocalStorageService.saveUserSession(
    role: userData['role'],
    onboardingDone: userData['onboarding_done'],
  );
  
  // Navigate based on Firestore data
  await NavigationService.navigateBasedOnAuth(context);
}
```

### 4. Registration Flow

**Before:**
```dart
// Register
await authService.register(email, password);

// Save locally
await PreferencesService.setLoggedIn(true);

// Navigate
Navigator.push(context, RoleSelectionScreen());
```

**After:**
```dart
// Register
final userCredential = await authService.register(email, password);

// Create Firestore document
await UserService().createUser(
  uid: userCredential.user!.uid,
  email: email,
  role: '', // Empty - will be set later
);

// Navigate
Navigator.push(context, RoleSelectionScreen());
```

### 5. Logout Flow

**Before:**
```dart
// Clear local storage
await PreferencesService.logout();

// Navigate
Navigator.push(context, LoginScreen());
```

**After:**
```dart
// Sign out from Firebase
await FirebaseAuth.instance.signOut();

// Clear local cache
await LocalStorageService.clearAll();

// Navigate
Navigator.pushAndRemoveUntil(context, LoginScreen(), (route) => false);
```

---

## 🗄️ Data Storage Comparison

### Before
| Data | Storage | Purpose |
|------|---------|---------|
| isLoggedIn | SharedPreferences | Auth status |
| user_role | SharedPreferences | User role |
| onboarding_completed | SharedPreferences | Onboarding status |

**Problem:** Data lost if SharedPreferences cleared

### After
| Data | Primary Storage | Cache | Purpose |
|------|----------------|-------|---------|
| Authentication | Firebase Auth | - | Login status |
| user_role | Firestore | SharedPreferences | User role |
| onboarding_done | Firestore | SharedPreferences | Onboarding status |

**Benefit:** Data persists in cloud, local cache for speed

---

## 🔄 Service Comparison

### PreferencesService → LocalStorageService

**Before (PreferencesService):**
```dart
class PreferencesService {
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }
  
  static Future<void> setUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }
  
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('isLoggedIn');
  }
}
```

**After (LocalStorageService + UserService):**
```dart
// LocalStorageService - Cache only
class LocalStorageService {
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }
  
  static Future<void> setUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }
  
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

// UserService - Firestore operations
class UserService {
  Future<String?> getUserRole(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['role'];
  }
  
  Future<void> updateUserRole(String uid, String role) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': role});
  }
}
```

---

## 🎯 Migration Benefits

### ✅ Advantages

1. **Data Persistence**
   - Data survives app uninstall/reinstall
   - Accessible from multiple devices
   - Cloud backup

2. **Security**
   - Firebase Authentication
   - Firestore security rules
   - Server-side validation

3. **Scalability**
   - Easy to add more user fields
   - Can sync across devices
   - Backend integration ready

4. **Reliability**
   - Single source of truth
   - No data loss
   - Automatic sync

5. **Offline Support**
   - Local cache for quick access
   - Firebase offline persistence
   - Sync when online

---

## 🚀 How to Use New System

### 1. Check Authentication
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  // User is logged in
  final uid = user.uid;
}
```

### 2. Get User Data
```dart
// From Firestore (source of truth)
final userData = await UserService().getUserData(uid);
final role = userData?['role'];

// From local cache (fast access)
final cachedRole = await LocalStorageService.getUserRole();
```

### 3. Update User Data
```dart
// Update Firestore
await UserService().updateUserRole(uid, 'client');

// Update local cache
await LocalStorageService.setUserRole('client');
```

### 4. Navigate
```dart
// Smart navigation based on Firebase data
await NavigationService.navigateBasedOnAuth(context);
```

### 5. Logout
```dart
await NavigationService.logout(context);
```

---

## 📊 Data Flow Comparison

### Before (Local Only)
```
User Action
    ↓
SharedPreferences (Read/Write)
    ↓
Navigate
```

### After (Firebase + Cache)
```
User Action
    ↓
Firebase Auth (Authentication)
    ↓
Firestore (Read/Write - Source of Truth)
    ↓
SharedPreferences (Cache)
    ↓
Navigate
```

---

## 🔒 Security Improvements

### Before
- ❌ No server-side validation
- ❌ Data can be manipulated locally
- ❌ No authentication verification
- ❌ Role can be changed locally

### After
- ✅ Firebase Authentication
- ✅ Firestore security rules
- ✅ Server-side validation
- ✅ Role protected in cloud
- ✅ Cannot manipulate role locally

---

## 🎨 User Experience

### Before
- ✅ Fast (local only)
- ❌ Data loss on app uninstall
- ❌ No multi-device support
- ❌ No cloud backup

### After
- ✅ Fast (local cache)
- ✅ Data persists in cloud
- ✅ Multi-device support
- ✅ Cloud backup
- ✅ Offline support

---

## 🧪 Testing Differences

### Before
```dart
// Test by clearing SharedPreferences
await PreferencesService.logout();
// User must login again
```

### After
```dart
// Test by signing out from Firebase
await FirebaseAuth.instance.signOut();
await LocalStorageService.clearAll();
// User must login again

// Test data persistence
// 1. Login
// 2. Uninstall app
// 3. Reinstall app
// 4. Login again
// 5. Data should still be there (from Firestore)
```

---

## 📝 Code Examples

### Example 1: Login Flow

**Before:**
```dart
Future<void> login(String email, String password) async {
  await authService.signIn(email, password);
  await PreferencesService.setLoggedIn(true);
  Navigator.push(context, HomeScreen());
}
```

**After:**
```dart
Future<void> login(String email, String password) async {
  // 1. Authenticate with Firebase
  await authService.signIn(email, password);
  
  // 2. Fetch data from Firestore
  final user = FirebaseAuth.instance.currentUser!;
  final userData = await UserService().getUserData(user.uid);
  
  // 3. Cache locally
  await LocalStorageService.saveUserSession(
    role: userData['role'],
    onboardingDone: userData['onboarding_done'],
  );
  
  // 4. Navigate based on Firestore data
  await NavigationService.navigateBasedOnAuth(context);
}
```

### Example 2: Role Selection

**Before:**
```dart
Future<void> selectRole(String role) async {
  await PreferencesService.setUserRole(role);
  Navigator.push(context, HomeScreen());
}
```

**After:**
```dart
Future<void> selectRole(String role) async {
  final user = FirebaseAuth.instance.currentUser!;
  
  // 1. Save to Firestore
  await UserService().updateUserRole(user.uid, role);
  
  // 2. Cache locally
  await LocalStorageService.setUserRole(role);
  
  // 3. Navigate
  if (role == 'client') {
    Navigator.push(context, ClientHomeScreen());
  } else {
    Navigator.push(context, TechnicianOnboardingFlow());
  }
}
```

---

## 🎉 Summary

### What You Gained
- ✅ Firebase Authentication
- ✅ Firestore as source of truth
- ✅ Data persistence in cloud
- ✅ Multi-device support
- ✅ Better security
- ✅ Scalable architecture
- ✅ Production-ready system

### What Changed
- 🔄 SharedPreferences → Cache only (not source of truth)
- 🔄 Local storage → Firestore for user data
- 🔄 Simple navigation → Firebase-based navigation
- 🔄 Local auth check → Firebase Auth check

### What Stayed the Same
- ✅ User experience (still fast)
- ✅ Auto-login functionality
- ✅ Role-based navigation
- ✅ Onboarding flow

---

**Your app is now production-ready with Firebase!** 🚀

---

**Migration Complete ✅**
