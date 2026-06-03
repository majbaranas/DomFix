import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/dashboard_metrics.dart';
import '../models/booking_model.dart';

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DashboardMetrics> getDashboardMetrics(String technicianId) {
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? bookingsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? jobsSub;

    Map<String, dynamic>? userData;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingDocs = const [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobDocs = const [];

    late final StreamController<DashboardMetrics> controller;

    Future<void> emitMetrics() async {
      if (userData == null) return;

      final isOnline = userData?['isOnline'] ?? false;
      final rating = (userData?['rating'] as num?)?.toDouble() ?? 4.5;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

      double todayEarnings = 0;
      double weeklyEarnings = 0;
      int activeJobs = 0;
      int completedJobs = 0;
      int totalJobs = 0;

      for (final doc in bookingDocs) {
        final booking = BookingModel.fromFirestore(doc);
        totalJobs++;

        if (booking.isActive) activeJobs++;
        if (booking.status == 'completed') completedJobs++;

        if (booking.scheduledAt.isAfter(todayStart)) {
          todayEarnings += booking.technicianFee;
        }
        if (booking.scheduledAt.isAfter(weekStart)) {
          weeklyEarnings += booking.technicianFee;
        }
      }

      for (final doc in jobDocs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? 'pending').toLowerCase();
        final isActiveJob =
            status == 'pending' || status == 'accepted' || status == 'in_progress';
        if (isActiveJob) activeJobs++;
        totalJobs++;
      }

      final completionRate = totalJobs > 0 ? (completedJobs / totalJobs * 100) : 0.0;
      final performanceBadge = _getPerformanceBadge(completionRate, rating);
      final weeklyData = await _getWeeklyEarningsData(technicianId, weekStart);

      if (!controller.isClosed) {
        controller.add(DashboardMetrics(
          todayEarnings: todayEarnings,
          weeklyEarnings: weeklyEarnings,
          activeJobsCount: activeJobs,
          completedJobsCount: completedJobs,
          completionRate: completionRate,
          customerRating: rating,
          responseTimeMinutes: 0,
          cancellationRate: totalJobs > 0 ? ((totalJobs - completedJobs) / totalJobs * 100) : 0,
          weeklyEarningsData: weeklyData,
          isOnline: isOnline,
          performanceBadge: performanceBadge,
          lastUpdated: DateTime.now(),
        ));
      }
    }

    controller = StreamController<DashboardMetrics>.broadcast(
      onListen: () {
        userSub = _firestore.collection('users').doc(technicianId).snapshots().listen((userDoc) async {
          userData = userDoc.data();
          await emitMetrics();
        });

        bookingsSub = _firestore
            .collection('bookings')
            .where('technicianId', isEqualTo: technicianId)
            .snapshots()
            .listen((snapshot) async {
          bookingDocs = snapshot.docs;
          await emitMetrics();
        });

        jobsSub = _firestore
            .collection('jobs')
            .where('technicianId', isEqualTo: technicianId)
            .snapshots()
            .listen((snapshot) async {
          jobDocs = snapshot.docs;
          await emitMetrics();
        });
      },
      onCancel: () async {
        await userSub?.cancel();
        await bookingsSub?.cancel();
        await jobsSub?.cancel();
        await controller.close();
      },
    );

    return controller.stream;
  }

  Stream<List<BookingModel>> getTodayBookings(String technicianId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(Duration(days: 1));

    return _firestore
        .collection('bookings')
        .where('technicianId', isEqualTo: technicianId)
        .where('status', whereIn: ['pending', 'confirmed', 'accepted'])
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs
              .map((doc) => BookingModel.fromFirestore(doc))
              .where((b) => b.scheduledAt.isAfter(todayStart) && b.scheduledAt.isBefore(tomorrowStart))
              .toList();
          bookings.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          return bookings;
        });
  }

  Stream<List<ActivityItem>> getRecentActivity(String technicianId) async* {
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? bookingsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? jobsSub;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingDocs = const [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobDocs = const [];

    late final StreamController<List<ActivityItem>> controller;

    void emitActivity() {
      final activities = <ActivityItem>[];

      for (final doc in bookingDocs) {
        final booking = BookingModel.fromFirestore(doc);
        final updatedAt = booking.updatedAt ?? booking.createdAt;
        activities.add(ActivityItem(
          id: 'booking_${booking.id}',
          type: booking.status == 'completed' ? 'booking' : 'booking',
          title: booking.status == 'completed' ? 'Job completed' : 'Booking request',
          description: booking.serviceName.isNotEmpty
              ? booking.serviceName
              : booking.description,
          timestamp: updatedAt,
          metadata: '\$${booking.technicianFee.toStringAsFixed(0)}',
        ));
      }

      for (final doc in jobDocs) {
        final data = doc.data();
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final status = (data['status'] as String? ?? 'pending').toLowerCase();
        final urgency = (data['urgency'] as String? ?? 'Standard');
        activities.add(ActivityItem(
          id: 'job_${doc.id}',
          type: status == 'accepted' ? 'booking' : 'message',
          title: status == 'accepted'
              ? 'Request accepted'
              : 'New booking request',
          description: (data['problemDescription'] as String? ?? 'Technician request'),
          timestamp: createdAt,
          metadata: urgency,
        ));
      }

      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (!controller.isClosed) {
        controller.add(activities.take(5).toList());
      }
    }

    controller = StreamController<List<ActivityItem>>.broadcast(
      onListen: () {
        bookingsSub = _firestore
            .collection('bookings')
            .where('technicianId', isEqualTo: technicianId)
            .snapshots()
            .listen((snapshot) {
          bookingDocs = snapshot.docs;
          emitActivity();
        });

        jobsSub = _firestore
            .collection('jobs')
            .where('technicianId', isEqualTo: technicianId)
            .snapshots()
            .listen((snapshot) {
          jobDocs = snapshot.docs;
          emitActivity();
        });
      },
      onCancel: () async {
        await bookingsSub?.cancel();
        await jobsSub?.cancel();
        await controller.close();
      },
    );

    yield* controller.stream;
  }

  Stream<List<AIInsight>> getAIInsights(String technicianId) async* {
    final metricsStream = getDashboardMetrics(technicianId);
    await for (final metrics in metricsStream) {
      final insights = <AIInsight>[];

      if (metrics.activeJobsCount > 3) {
        insights.add(AIInsight(
          id: 'high_demand',
          title: 'High Demand Detected',
          description: 'Multiple bookings in your area right now',
          icon: '⚡',
          category: 'opportunity',
          metric: metrics.activeJobsCount.toDouble(),
        ));
      }

      if (metrics.completionRate > 95) {
        insights.add(AIInsight(
          id: 'excellent_performance',
          title: 'Excellent Performance',
          description: 'You\'re performing better than 95% of technicians',
          icon: '🏆',
          category: 'performance',
          metric: metrics.completionRate,
        ));
      }

      if (metrics.todayEarnings > 200) {
        insights.add(AIInsight(
          id: 'great_earnings',
          title: 'Great Earning Day',
          description: 'You\'re on track for your best day this week',
          icon: '💰',
          category: 'earnings',
          metric: metrics.todayEarnings,
        ));
      }

      if (metrics.customerRating >= 4.8) {
        insights.add(AIInsight(
          id: 'top_rated',
          title: 'Top Rated Technician',
          description: 'Your customer satisfaction is excellent',
          icon: '⭐',
          category: 'rating',
          metric: metrics.customerRating,
        ));
      }

      yield insights;
    }
  }

  String _getPerformanceBadge(double completionRate, double rating) {
    if (completionRate >= 98 && rating >= 4.9) return 'Elite';
    if (completionRate >= 95 && rating >= 4.7) return 'Professional';
    if (completionRate >= 90 && rating >= 4.5) return 'Experienced';
    return 'Active';
  }

  Future<List<double>> _getWeeklyEarningsData(String technicianId, DateTime weekStart) async {
    final data = List<double>.filled(7, 0.0);
    final bookings = await _firestore
        .collection('bookings')
        .where('technicianId', isEqualTo: technicianId)
        .where('status', isEqualTo: 'completed')
        .get();

    for (final doc in bookings.docs) {
      final booking = BookingModel.fromFirestore(doc);
      if (booking.updatedAt != null && booking.updatedAt!.isAfter(weekStart)) {
        final dayIndex = booking.updatedAt!.difference(weekStart).inDays;
        if (dayIndex >= 0 && dayIndex < 7) {
          data[dayIndex] += booking.technicianFee;
        }
      }
    }

    return data;
  }
}
