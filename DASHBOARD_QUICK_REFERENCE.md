# 🚀 Dashboard Quick Reference Guide

## File Structure
```
lib/
├── models/
│   └── dashboard_metrics.dart (DashboardMetrics, ActivityItem, AIInsight)
├── services/
│   └── dashboard_service.dart (Real-time data service)
├── widgets/dashboard/
│   ├── dashboard_header.dart (Profile + greeting)
│   ├── live_status_card.dart (Metrics hero card)
│   ├── job_card.dart (Job cards & section)
│   ├── analytics_card.dart (Analytics grid)
│   ├── ai_insights_card.dart (Smart suggestions)
│   ├── activity_feed.dart (Timeline view)
│   ├── quick_actions.dart (Action pills)
│   └── dashboard_skeleton.dart (Loading state)
└── screens/
    └── technician_home_screen.dart (Main container)
```

## Key Classes

### DashboardMetrics
```dart
class DashboardMetrics {
  final double todayEarnings;
  final double weeklyEarnings;
  final int activeJobsCount;
  final int completedJobsCount;
  final double completionRate; // 0-100
  final double customerRating; // 0-5
  final int responseTimeMinutes;
  final double cancellationRate; // 0-100
  final List<double> weeklyEarningsData; // 7 days
  final bool isOnline;
  final String performanceBadge;
}
```

### ActivityItem
```dart
class ActivityItem {
  final String id;
  final String type; // 'booking', 'payment', 'review', 'message'
  final String title;
  final String description;
  final String? iconUrl;
  final DateTime timestamp;
  final String? metadata; // e.g., "$120"
}
```

### AIInsight
```dart
class AIInsight {
  final String id;
  final String title;
  final String description;
  final String icon; // emoji
  final String category;
  final double? metric;
}
```

## DashboardService API

```dart
// Get real-time metrics
Stream<DashboardMetrics> getDashboardMetrics(String technicianId)

// Get today's bookings only
Stream<List<BookingModel>> getTodayBookings(String technicianId)

// Get recent activity (last 5)
Stream<List<ActivityItem>> getRecentActivity(String technicianId)

// Get AI-generated insights
Stream<List<AIInsight>> getAIInsights(String technicianId)
```

## Firebase Collections Used

```
users/{uid}
├─ isOnline (bool)
├─ rating (double)
├─ name / fullName
└─ profileImage (URL)

bookings/
├─ technicianId (filter)
├─ status (active/completed)
├─ technicianFee (earnings)
└─ scheduledAt (timestamp)

technician_locations/{uid}
├─ lat / lng
└─ updatedAt

chats/
├─ participants
└─ lastMessageTime
```

## Widget Component Hierarchy

```
TechnicianDashboard (SafeArea)
└─ StreamBuilder<DashboardMetrics>
   ├─ DashboardHeader
   │  └─ Online status indicator
   ├─ LiveStatusCard
   │  ├─ Online/Offline toggle
   │  └─ 6 metric columns
   ├─ StreamBuilder<JobList>
   │  └─ JobsSection
   │     └─ JobCard (horizontal scroll)
   ├─ AnalyticsSection
   │  └─ AnalyticsCard ×4
   ├─ StreamBuilder<AIInsights>
   │  └─ AIInsightsSection
   │     └─ AIInsightCard ×N
   ├─ StreamBuilder<ActivityList>
   │  └─ ActivityFeed
   │     └─ ActivityItemWidget ×N
   └─ QuickActions
      └─ QuickActionPill ×5
```

## Color Reference

```dart
// Main colors
AppColors.background         // #070B14 (dark background)
AppColors.surface            // #101419 (card backgrounds)
AppColors.neonAccent         // #D9FF00 (primary action)
AppColors.success            // #34C759 (online status)
AppColors.error              // #FFB4AB (alerts)
AppColors.onSurface          // #E0E2EA (text)
AppColors.onSurfaceVariant   // #C5C9AC (secondary text)

// Convenience
AppColors.divider            // white 5% opacity
```

## Spacing Reference

```dart
// Use these constants
AppColors.space4   → 4px
AppColors.space8   → 8px
AppColors.space12  → 12px
AppColors.space16  → 16px
AppColors.space20  → 20px
AppColors.space24  → 24px
AppColors.space32  → 32px
AppColors.space40  → 40px
AppColors.space48  → 48px
```

## Common Patterns

### Real-Time Update Pattern
```dart
StreamBuilder<List<BookingModel>>(
  stream: DashboardService.instance.getTodayBookings(uid),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return LoadingSkeleton();
    final jobs = snapshot.data ?? [];
    return JobsSection(bookings: jobs);
  },
)
```

### Animation Pattern
```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: targetValue),
  duration: const Duration(milliseconds: 1000),
  curve: Curves.easeOutCubic,
  builder: (context, val, child) {
    return Text('${val.toInt()}');
  },
)
```

### Status Toggle Pattern
```dart
void _toggleOnlineStatus(bool value) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  setState(() => _isOnline = value);
  FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .update({'isOnline': value});
}
```

## Performance Tips

1. **Limit Stream Subscriptions**
   - Use `.map()` to transform data before StreamBuilder
   - Don't subscribe to same stream twice

2. **Optimize Animations**
   - Use FadeTransition over Opacity
   - Limit animation count
   - Use appropriate durations

3. **Lazy Load Data**
   - Use pagination for activity feed
   - Load only visible sections
   - Unload when not in view

4. **Cache Data**
   - DashboardService handles caching
   - Metrics cached at service level
   - Refresh on manual pull-to-refresh

## Extending the Dashboard

### Add New Metric Section
```dart
// 1. Add to DashboardMetrics
class DashboardMetrics {
  final double newMetric; // Add here
}

// 2. Calculate in DashboardService
final newMetric = /* calculation */;

// 3. Create widget
class NewMetricCard extends StatelessWidget { }

// 4. Add to dashboard
NewMetricCard(metric: metrics.newMetric)
```

### Add New AI Insight
```dart
// 1. In getAIInsights() method
if (someCondition) {
  insights.add(AIInsight(
    id: 'insight_id',
    title: 'Insight Title',
    description: 'Description',
    icon: '🎯',
    category: 'category',
  ));
}
```

### Customize Colors
```dart
// Update AppColors in app_colors.dart
static const Color neonAccent = Color(0xFFD9FF00);

// Then rebuild - all components update automatically
```

## Debugging

### Check Real-Time Updates
```dart
// Add to DashboardService methods
print('🔄 Metrics updated: $metrics');

// Monitor Firebase logs
FlutterFirebase.debugger.enableDebugLogging = true;
```

### Performance Profiling
```bash
# Run with DevTools
flutter run --profile

# Check Frame timing
Ctrl+P (in DevTools) → "Frame rate"
```

### Stream Debugging
```dart
// Add debug operator to stream
stream
  .doOnData((data) => print('📊 Data: $data'))
  .doOnError((e) => print('❌ Error: $e'))
```

## Deployment Checklist

- [ ] No compilation errors: `flutter analyze`
- [ ] Tests passing: `flutter test`
- [ ] Performance profiled: `flutter run --profile`
- [ ] Firebase rules updated
- [ ] Images optimized
- [ ] Logging cleaned up
- [ ] Comments added
- [ ] Version bumped
- [ ] Changelog updated

## Support Quick Links

- **Flutter Docs**: https://flutter.dev/docs
- **Firebase Docs**: https://firebase.flutter.dev
- **Material Design 3**: https://m3.material.io
- **Code Repository**: DomFix on GitHub

---

**Last Updated**: June 3, 2026  
**Version**: 1.0.0  
**Maintainer**: DomFix Team
