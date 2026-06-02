# Quick Reference Guide - Role-Based Authentication

## 🚀 Quick Start

### Check User Role
```dart
final role = await PreferencesService.getUserRole();
// Returns: "client", "technician", or null
```

### Navigate Based on Role
```dart
await NavigationService.navigateBasedOnRole(context);
// Automatically routes to correct screen
```

### Logout User
```dart
await AuthService().signOut();
await PreferencesService.logout();
await NavigationService.logout(context);
```

### Save User Role
```dart
await PreferencesService.setUserRole('client'); // or 'technician'
```

### Check Onboarding Status
```dart
final completed = await PreferencesService.isOnboardingCompleted();
```

## 📱 Screen Navigation Map

```
LoginScreen
    ↓
NavigationService.navigateBasedOnRole()
    ↓
    ├─→ No Role → RoleSelectionScreen
    │                   ↓
    │       ├─→ Client → ClientHomeScreen
    │       └─→ Technician → TechnicianOnboardingFlow → TechnicianHomeScreen
    │
    ├─→ Client Role → ClientHomeScreen
    │
    └─→ Technician Role
            ├─→ Onboarding Not Complete → TechnicianOnboardingFlow
            └─→ Onboarding Complete → TechnicianHomeScreen
```

## 🔑 Key Files

### Services
- `lib/services/auth_service.dart` - Firebase authentication
- `lib/services/preferences_service.dart` - Local storage
- `lib/services/navigation_service.dart` - Role-based navigation

### Screens
- `lib/screens/client_home_screen.dart` - Client dashboard
- `lib/screens/technician_home_screen.dart` - Technician dashboard
- `lib/screens/role_selection_screen.dart` - Role picker
- `lib/screens/login_screen.dart` - Login/auth
- `lib/screens/splash_screen.dart` - App initialization

## 💾 SharedPreferences Keys

| Key | Type | Values |
|-----|------|--------|
| `isFirstLaunch` | bool | true/false |
| `isLoggedIn` | bool | true/false |
| `user_role` | String | "client" / "technician" |
| `onboarding_completed` | bool | true/false |

## 🎯 Common Tasks

### Add New Role
1. Add role string constant
2. Update NavigationService.navigateBasedOnRole()
3. Create new home screen
4. Update RoleSelectionScreen

### Add Feature to Client Only
```dart
// In any screen
final role = await PreferencesService.getUserRole();
if (role == 'client') {
  // Show client-only feature
}
```

### Add Feature to Technician Only
```dart
final role = await PreferencesService.getUserRole();
if (role == 'technician') {
  // Show technician-only feature
}
```

### Force Re-select Role (Testing)
```dart
await PreferencesService.setUserRole('');
// User will be prompted to select role on next login
```

### Reset Everything (Testing)
```dart
await PreferencesService.logout();
await PreferencesService.resetFirstLaunch();
```

## 🔒 Security Best Practices

1. ✅ Always check role before showing sensitive features
2. ✅ Validate role on backend (when implemented)
3. ✅ Use NavigationService for consistent routing
4. ✅ Clear all data on logout
5. ✅ Never hardcode navigation paths

## 🐛 Debugging

### User Stuck on Wrong Screen?
```dart
// Check stored values
final isLoggedIn = await PreferencesService.isLoggedIn();
final role = await PreferencesService.getUserRole();
final onboarding = await PreferencesService.isOnboardingCompleted();
print('Logged in: $isLoggedIn, Role: $role, Onboarding: $onboarding');
```

### Reset User State
```dart
await PreferencesService.logout();
// Restart app
```

### Test Different Roles
```dart
// Set role manually for testing
await PreferencesService.setUserRole('client');
// or
await PreferencesService.setUserRole('technician');
await PreferencesService.setOnboardingCompleted(true); // Skip onboarding
```

## 📝 Code Examples

### Complete Login Flow
```dart
Future<void> _handleLogin() async {
  try {
    await AuthService().signInWithEmailPassword(email, password);
    await PreferencesService.setLoggedIn(true);
    await NavigationService.navigateBasedOnRole(context);
  } catch (e) {
    // Handle error
  }
}
```

### Complete Logout Flow
```dart
Future<void> _handleLogout() async {
  await AuthService().signOut();
  await PreferencesService.logout();
  await NavigationService.logout(context);
}
```

### Check Role Before Action
```dart
Future<void> _performAction() async {
  final role = await PreferencesService.getUserRole();
  
  if (role == 'technician') {
    // Technician-specific action
  } else if (role == 'client') {
    // Client-specific action
  } else {
    // No role - redirect to role selection
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoleSelectionScreen()),
    );
  }
}
```

## 🎨 UI Customization

### Client Home Tabs
Edit: `lib/screens/client_home_screen.dart`
- Home, AI Chat, Pros, Control, Settings

### Technician Home Tabs
Edit: `lib/screens/technician_home_screen.dart`
- Dashboard, Jobs, Profile, Settings

### Add New Tab
1. Add screen to `_screens` list
2. Add nav item to bottom navigation
3. Update `_currentIndex` logic

## 🚨 Important Notes

- Always use `Navigator.pushReplacement()` for auth flows
- Never allow back navigation after login
- Always check `mounted` before navigation
- Use `NavigationService` for consistency
- Test both roles thoroughly
- Clear data on logout

## 📞 Support

For issues or questions:
1. Check this guide
2. Review ROLE_AUTH_IMPLEMENTATION.md
3. Check code comments in NavigationService
4. Debug with print statements
