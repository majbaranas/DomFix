# 🎯 QUICK REFERENCE - TECHNICIAN PROFILE SYSTEM

## 📦 FIRESTORE COLLECTIONS

```dart
users/{uid}
├─ Basic: uid, email, role, fullName, profileImage, bio, city
├─ Public: rating, reviewCount, jobsCompleted, rankScore, isAvailable
└─ Location: lat, lng

technician_profiles/{uid}
├─ Professional: specialties, customSkills, primarySpecialty, yearsOfExperience
├─ Media: portfolioUrls, certificationUrls
├─ Availability: isAvailable, availableDays, workingHours, serviceRadiusMiles
├─ Verification: isPhoneVerified, isIdentityVerified, phoneNumber, identityDocumentUrl
└─ Metrics: profileCompletionScore, createdAt, updatedAt

technician_stats/{uid}
├─ Ratings: averageRating, totalReviews, ratingSum
├─ Activity: completedJobs
├─ Quality: reviewQualityScore
└─ Ranking: rankScore, profileCompletionBonus, lastUpdated
```

---

## 🔑 KEY FORMULAS

### Profile Completion Score (0-100%)
```dart
score = (profilePhoto ? 15 : 0)
      + (bio.length > 50 ? 10 : 0)
      + (specialties ≥ 3 ? 15 : specialties > 0 ? 7 : 0)
      + (yearsOfExperience > 0 ? 10 : 0)
      + (portfolioUrls ≥ 3 ? 15 : portfolioUrls > 0 ? 7 : 0)
      + (certifications.isNotEmpty ? 10 : 0)
      + (isIdentityVerified ? 15 : hasIdentityDoc ? 7 : 0)
      + (isPhoneVerified ? 10 : 0)
```

### Rank Score (0-~765 points)
```dart
rankScore = (averageRating * 100)              // Max 500
          + (min(totalReviews, 50) * 2)        // Max 100
          + (min(completedJobs, 100))          // Max 100
          + (reviewQualityScore * 10)          // ~15
          + (profileCompletionScore * 0.5)     // Max 50
```

### Review Quality Score
```dart
qualityScore = (rating / 5.0) + (comment.length ≥ 12 ? 0.2 : 0.0)
```

---

## 🎨 PROFILE TIERS

| Tier | Score Range | Badge Color | Icon |
|------|-------------|-------------|------|
| Gold | 90-100% | #FFD700 | workspace_premium_rounded |
| Silver | 70-89% | #C0C0C0 | military_tech_rounded |
| Bronze | 50-69% | #CD7F32 | emoji_events_rounded |
| Basic | 0-49% | None | None |

---

## 🔄 DATA FLOW

### Onboarding → Profile
```dart
TechnicianOnboardingData data;
// Step 1-6: Collect data

await TechnicianProfileService().saveOnboardingProfile(
  uid: uid,
  email: email,
  data: data,
  lat: lat,
  lng: lng,
);

// Creates:
// - users/{uid}
// - technician_profiles/{uid}
// - technician_stats/{uid}
```

### Review Submission → Stats Update
```dart
await ReviewService.instance.submitBookingReview(
  booking: booking,
  rating: 5,
  comment: "Great work!",
);

// Flow:
// 1. Create reviews/{bookingId}
// 2. Aggregate all reviews for technician
// 3. Calculate: averageRating, totalReviews, qualityScore
// 4. Recalculate rankScore (includes profile completion)
// 5. Update technician_stats/{uid} + users/{uid}
```

### Job Completion → Count Increment
```dart
await ReviewService.incrementCompletedJobs(technicianId);

// Updates:
// - technician_stats.completedJobs += 1
// - Recalculates rankScore
// - Updates users.jobsCompleted
```

---

## 🚀 COMMON OPERATIONS

### Fetch Full Profile
```dart
final profile = await TechnicianProfileService().getProfile(technicianId);
// Returns: TechnicianProfileModel with all data from 3 collections
// Cached for 5 minutes
```

### Stream Profile Updates
```dart
TechnicianProfileService().streamProfile(technicianId).listen((profile) {
  // Real-time updates
});
```

### Update Profile Fields
```dart
await TechnicianProfileService().updateProfile(
  uid: uid,
  fullName: "New Name",
  bio: "Updated bio",
  specialties: ["Electrician", "Plumber"],
  isAvailable: true,
);
// Automatically recalculates profileCompletionScore and rankScore
```

### Query Technicians (for map/search)
```dart
final technicians = await TechnicianProfileService().queryTechnicians(
  nearLocation: GeoPoint(40.7128, -74.0060),
  radiusKm: 10.0,
  specialties: ["Electrician"],
  minRating: 4.0,
  limit: 20,
);
// Returns: List<TechnicianProfileModel> sorted by rankScore
```

---

## 🎨 UI COMPONENTS

### Profile Hero
```dart
Stack(
  children: [
    CircleAvatar(backgroundImage: NetworkImage(profile.profilePhotoUrl)),
    if (profile.isIdentityVerified) VerificationBadge(), // Top-right
    if (profile.isAvailable) OnlineDot(), // Bottom-right
  ],
)
```

### Tier Badge
```dart
_ProfileBadge(
  tier: profile.profileTier, // "Gold", "Silver", "Bronze"
  score: profile.profileCompletionScore,
)
```

### Stats Cards
```dart
Row(
  children: [
    _StatCard(value: "${profile.completedJobs}+", label: "Jobs"),
    _StatCard(value: "${profile.yearsOfExperience}yr", label: "Experience"),
    _StatCard(value: profile.replyTime, label: "Reply"),
  ],
)
```

---

## 🔒 SECURITY RULES

### Technician Profiles
```javascript
match /technician_profiles/{technicianId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == technicianId;
}
```

### Technician Stats
```javascript
match /technician_stats/{technicianId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == technicianId;
}
```

### Reviews
```javascript
match /reviews/{reviewId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null
    && reviewId == request.resource.data.bookingId
    && get(/databases/$(database)/documents/bookings/$(reviewId)).data.status == 'completed'
    && get(/databases/$(database)/documents/bookings/$(reviewId)).data.clientId == request.auth.uid;
  allow update, delete: if false;
}
```

---

## 🎯 PROFILE SCREEN SECTIONS

```dart
TechnicianProfileScreen(technicianId: id)
  ├─ Hero Section
  │  ├─ Avatar (96×96)
  │  ├─ Verification badge (if verified)
  │  ├─ Full name
  │  ├─ Primary specialty
  │  ├─ Tier badge (if ≥50%)
  │  └─ Rating + review count
  ├─ Stats Cards
  │  ├─ Completed jobs
  │  ├─ Years of experience
  │  └─ Reply time
  ├─ About Section (bio)
  ├─ Recent Work Gallery
  │  └─ Horizontal scroll (work photos + portfolio)
  ├─ Reviews Section
  │  └─ List of client reviews
  └─ Action Bar
     ├─ Message button
     └─ Book Now button
```

---

## 🗺️ MAP INTEGRATION

### Display Technician on Map
```dart
NearbyTechniciansMapScreen()
  // Automatically queries technician_locations collection
  // Shows markers for online technicians
  // Click marker → Preview card with real data
```

### Preview Card Data
```dart
_TechPreviewCard(
  tech: technicianLocation,
  userPoint: userLatLng,
  routeInfo: routeInfo, // Distance + ETA from routing API
  onClose: () {},
)
```

---

## 📊 TESTING

### Test Profile Completion
```dart
// Create technician with different completion levels
final lowScore = TechnicianProfileModel(
  profilePhotoUrl: null,        // 0 pts
  bio: "Hi",                    // 0 pts (< 50 chars)
  specialties: ["Electrician"], // 7 pts (1 specialty)
  yearsOfExperience: 0,         // 0 pts
  portfolioUrls: [],            // 0 pts
  certificationUrls: [],        // 0 pts
  isIdentityVerified: false,    // 0 pts
  isPhoneVerified: false,       // 0 pts
);
// Expected score: 7%

final highScore = TechnicianProfileModel(
  profilePhotoUrl: "https://...",           // 15 pts
  bio: "Licensed electrician with 10...",   // 10 pts
  specialties: ["A", "B", "C"],             // 15 pts
  yearsOfExperience: 10,                    // 10 pts
  portfolioUrls: ["1", "2", "3"],           // 15 pts
  certificationUrls: ["cert1"],             // 10 pts
  isIdentityVerified: true,                 // 15 pts
  isPhoneVerified: true,                    // 10 pts
);
// Expected score: 100%
```

### Test Ranking
```dart
// Tech A: rating 5.0, 50 reviews, 100 jobs, 95% profile
// Expected rank: 500 + 100 + 100 + ~10 + 47.5 = ~757

// Tech B: rating 0.0, 0 reviews, 0 jobs, 90% profile
// Expected rank: 0 + 0 + 0 + 0 + 45 = 45

// Verify: A ranks higher than B in queryTechnicians()
```

---

## 🚨 COMMON ISSUES

### Profile not loading
```dart
// Check:
1. Firestore rules deployed?
2. technician_profiles/{uid} exists?
3. onboardingCompleted = true?
4. Console shows any errors?
```

### Rank not updating
```dart
// Fix:
await TechnicianProfileService()._recalculateProfileCompletion(uid);
// Or submit a new review to trigger aggregation
```

### Images not displaying
```dart
// Check:
1. Cloudinary URLs valid?
2. Network error handler implemented?
3. Image.network errorBuilder present?
```

---

## 📚 DOCUMENTATION

- **Full System:** `TECHNICIAN_PROFILE_PRODUCTION_READY.md`
- **Deployment:** `DEPLOYMENT_CHECKLIST.md`
- **Visual Specs:** `TECHNICIAN_PROFILE_VISUAL_SUMMARY.md`
- **This Card:** `QUICK_REFERENCE.md`

---

## 🎯 KEY TAKEAWAYS

1. **3 collections:** users, technician_profiles, technician_stats
2. **Profile completion:** 0-100% based on 8 factors
3. **Ranking:** Includes profile quality (up to 50 bonus points)
4. **Tiers:** Gold/Silver/Bronze badges for ≥50% completion
5. **Verification:** Identity + phone badges build trust
6. **Dynamic:** All data from Firestore, no static content
7. **Performance:** 5-minute cache, parallel fetches
8. **Security:** Owner-only writes, authenticated reads

---

**Keep this card handy for quick reference during development!**

**Version:** 1.0.0 | **Last Updated:** January 2024
