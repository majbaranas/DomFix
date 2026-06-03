class DashboardMetrics {
  final double todayEarnings;
  final double weeklyEarnings;
  final int activeJobsCount;
  final int completedJobsCount;
  final double completionRate;
  final double customerRating;
  final int responseTimeMinutes;
  final double cancellationRate;
  final List<double> weeklyEarningsData;
  final bool isOnline;
  final String performanceBadge;
  final DateTime lastUpdated;

  const DashboardMetrics({
    required this.todayEarnings,
    required this.weeklyEarnings,
    required this.activeJobsCount,
    required this.completedJobsCount,
    required this.completionRate,
    required this.customerRating,
    required this.responseTimeMinutes,
    required this.cancellationRate,
    required this.weeklyEarningsData,
    required this.isOnline,
    required this.performanceBadge,
    required this.lastUpdated,
  });

  factory DashboardMetrics.empty() => DashboardMetrics(
    todayEarnings: 0,
    weeklyEarnings: 0,
    activeJobsCount: 0,
    completedJobsCount: 0,
    completionRate: 0,
    customerRating: 0,
    responseTimeMinutes: 0,
    cancellationRate: 0,
    weeklyEarningsData: [0, 0, 0, 0, 0, 0, 0],
    isOnline: false,
    performanceBadge: 'Professional',
    lastUpdated: DateTime.now(),
  );
}

class ActivityItem {
  final String id;
  final String type;
  final String title;
  final String description;
  final String? iconUrl;
  final DateTime timestamp;
  final String? metadata;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.iconUrl,
    required this.timestamp,
    this.metadata,
  });

  bool get isRecent {
    final diff = DateTime.now().difference(timestamp);
    return diff.inHours < 24;
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class AIInsight {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String category;
  final double? metric;

  const AIInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    this.metric,
  });
}
