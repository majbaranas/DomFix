# Testing Checklist - Role-Based Authentication

## ✅ Pre-Testing Setup

- [ ] Clear app data / Uninstall and reinstall app
- [ ] Ensure Firebase is configured
- [ ] Ensure Google Sign-In is configured
- [ ] Have test accounts ready (email/password)

---

## 🧪 Test Scenarios

### 1. First Launch (New User)
- [ ] App shows splash screen
- [ ] After splash, navigates to OnboardingScreen
- [ ] Can swipe through onboarding pages
- [ ] "Get Started" button navigates to LoginScreen

### 2. Registration Flow - Client
- [ ] Click "Create Account" on LoginScreen
- [ ] Fill all fields in RegisterScreen
- [ ] Check "Terms of Service" checkbox
- [ ] Click "Create Account"
- [ ] Navigates to RoleSelectionScreen
- [ ] Select "I need help" (Client)
- [ ] Click "Continue"
- [ ] Navigates to ClientHomeScreen
- [ ] Bottom nav shows: Home, AI Chat, Pros, Control, Settings
- [ ] Can navigate between all tabs
- [ ] Close app and reopen
- [ ] Should go directly to ClientHomeScreen (no login prompt)

### 3. Registration Flow - Technician
- [ ] Logout from Settings
- [ ] Register new account
- [ ] Select "I'm a professional" (Technician)
- [ ] Click "Continue"
- [ ] Navigates to TechnicianOnboardingFlow
- [ ] Complete all onboarding steps
- [ ] After completion, navigates to TechnicianHomeScreen
- [ ] Bottom nav shows: Dashboard, Jobs, Profile, Settings
- [ ] Can navigate between all tabs
- [ ] Close app and reopen
- [ ] Should go directly to TechnicianHomeScreen

### 4. Login Flow - Existing Client
- [ ] Logout from Settings
- [ ] Enter client credentials
- [ ] Click "Sign In"
- [ ] Navigates directly to ClientHomeScreen (no role selection)
- [ ] All client features accessible

### 5. Login Flow - Existing Technician
- [ ] Logout from Settings
- [ ] Enter technician credentials
- [ ] Click "Sign In"
- [ ] Navigates directly to TechnicianHomeScreen
- [ ] All technician features accessible

### 6. Google Sign-In - New User
- [ ] Click "Continue with Google"
- [ ] Select Google account
- [ ] Navigates to RoleSelectionScreen
- [ ] Select role
- [ ] Navigates to appropriate home screen

### 7. Google Sign-In - Existing User
- [ ] Logout
- [ ] Click "Continue with Google"
- [ ] Select same Google account
- [ ] Navigates directly to appropriate home screen (no role selection)

### 8. Logout Flow
- [ ] From any home screen, go to Settings
- [ ] Click "Logout" button
- [ ] Confirmation dialog appears
- [ ] Click "Logout"
- [ ] Navigates to LoginScreen
- [ ] Cannot go back to home screen
- [ ] Close and reopen app
- [ ] Shows LoginScreen (not home screen)

### 9. Role Persistence
- [ ] Login as client
- [ ] Close app completely
- [ ] Reopen app
- [ ] Should show ClientHomeScreen
- [ ] Logout
- [ ] Login as technician
- [ ] Close app completely
- [ ] Reopen app
- [ ] Should show TechnicianHomeScreen

### 10. Technician Onboarding Interruption
- [ ] Register as technician
- [ ] Start onboarding flow
- [ ] Close app mid-onboarding
- [ ] Reopen app
- [ ] Should resume onboarding flow
- [ ] Complete onboarding
- [ ] Close and reopen app
- [ ] Should go to TechnicianHomeScreen (not onboarding)

### 11. Navigation - No Back Button Issues
- [ ] After login, press back button
- [ ] Should NOT go back to login screen
- [ ] After role selection, press back button
- [ ] Should NOT go back to role selection
- [ ] After logout, press back button
- [ ] Should NOT go back to home screen

### 12. Error Handling
- [ ] Try login with wrong password
- [ ] Should show error message
- [ ] Try login with empty fields
- [ ] Should show validation error
- [ ] Try register with mismatched passwords
- [ ] Should show error
- [ ] Try register without accepting terms
- [ ] Should show error
- [ ] Try role selection without selecting role
- [ ] Should show error

### 13. UI/UX
- [ ] All screens use consistent dark theme
- [ ] Neon accent color (D9FF00) used consistently
- [ ] Loading indicators show during async operations
- [ ] Smooth transitions between screens
- [ ] Haptic feedback on button taps
- [ ] No UI glitches or overlaps
- [ ] Text is readable on all screens
- [ ] Icons are clear and appropriate

### 14. Client-Specific Features
- [ ] Home tab shows client dashboard
- [ ] AI Chat tab accessible
- [ ] Find Pros tab accessible
- [ ] Control tab accessible
- [ ] Settings tab accessible
- [ ] All navigation works smoothly

### 15. Technician-Specific Features
- [ ] Dashboard shows stats (Active Jobs, Completed)
- [ ] Dashboard shows active jobs list
- [ ] Jobs tab accessible
- [ ] Profile tab accessible
- [ ] Settings tab accessible
- [ ] All navigation works smoothly

---

## 🔍 Edge Cases

### Edge Case 1: Rapid Navigation
- [ ] Rapidly tap between tabs
- [ ] No crashes or freezes
- [ ] Smooth transitions

### Edge Case 2: Network Issues
- [ ] Turn off internet
- [ ] Try to login
- [ ] Should show appropriate error
- [ ] Turn on internet
- [ ] Login should work

### Edge Case 3: Multiple Accounts
- [ ] Login as client
- [ ] Logout
- [ ] Login as technician
- [ ] Logout
- [ ] Login as client again
- [ ] Each time shows correct home screen

### Edge Case 4: App Backgrounding
- [ ] Login
- [ ] Send app to background
- [ ] Wait 5 minutes
- [ ] Bring app to foreground
- [ ] Should still be logged in
- [ ] Should show correct home screen

---

## 📊 Performance Checks

- [ ] Splash screen loads in < 3 seconds
- [ ] Login completes in < 2 seconds (good network)
- [ ] Role selection navigation is instant
- [ ] Tab switching is smooth (no lag)
- [ ] No memory leaks (check with profiler)
- [ ] App size is reasonable

---

## 🐛 Known Issues to Check

- [ ] No duplicate navigation calls
- [ ] No setState after dispose errors
- [ ] No context usage after unmount
- [ ] No infinite loops in navigation
- [ ] No memory leaks from controllers
- [ ] All controllers properly disposed

---

## ✨ Final Verification

- [ ] All test scenarios pass
- [ ] No crashes during testing
- [ ] No console errors or warnings
- [ ] UI looks professional
- [ ] Navigation is intuitive
- [ ] Role persistence works 100%
- [ ] Logout clears all data
- [ ] Ready for production

---

## 📝 Test Results

**Date:** _______________
**Tester:** _______________
**Device:** _______________
**OS Version:** _______________

**Pass Rate:** _____ / _____ tests passed

**Issues Found:**
1. 
2. 
3. 

**Notes:**


---

## 🎯 Priority Tests (Quick Check)

If time is limited, test these critical flows:

1. ✅ Register as client → See ClientHomeScreen
2. ✅ Logout → Login as same client → See ClientHomeScreen
3. ✅ Register as technician → Complete onboarding → See TechnicianHomeScreen
4. ✅ Close app → Reopen → See correct home screen
5. ✅ Logout → Cannot go back to home screen

If all 5 pass, core functionality is working! ✨
