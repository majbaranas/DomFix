import 'dart:math' as math;

class TechnicianRankingService {
  const TechnicianRankingService._();

  static double calculateRankScore({
    required double averageRating,
    required int totalReviews,
    required int completedJobs,
    double responseSpeedScore = 0.0,
    double profileCompletenessScore = 0.0,
    double activityScore = 0.0,
    double availabilityScore = 0.0,
    bool availabilityEnabled = true,
  }) {
    final ratingComponent = _normalize(averageRating, max: 5.0) * 35.0;
    final reviewsComponent = _logScale(totalReviews, cap: 100) * 15.0;
    final jobsComponent = _logScale(completedJobs, cap: 200) * 15.0;
    final responseComponent = _normalize(responseSpeedScore) * 10.0;
    final profileComponent = _normalize(profileCompletenessScore) * 10.0;
    final activityComponent = _normalize(activityScore) * 10.0;
    final availabilityComponent =
        availabilityEnabled ? _normalize(availabilityScore) * 5.0 : 0.0;

    return double.parse(
      (ratingComponent +
              reviewsComponent +
              jobsComponent +
              responseComponent +
              profileComponent +
              activityComponent +
              availabilityComponent)
          .toStringAsFixed(3),
    );
  }

  static double freshnessBonus(DateTime updatedAt) {
    final age = DateTime.now().difference(updatedAt);
    if (age.inMinutes <= 5) return 12.0;
    if (age.inMinutes <= 30) return 10.0;
    if (age.inHours <= 2) return 7.5;
    if (age.inHours <= 6) return 5.0;
    if (age.inHours <= 24) return 3.0;
    if (age.inDays <= 3) return 1.5;
    return 0.0;
  }

  static double _normalize(double value, {double max = 100.0}) {
    if (value.isNaN || value.isInfinite) return 0.0;
    final clamped = value.clamp(0.0, max).toDouble();
    return max <= 0 ? 0.0 : clamped / max;
  }

  static double _logScale(int value, {required int cap}) {
    if (value <= 0 || cap <= 0) return 0.0;
    final clamped = value > cap ? cap : value;
    return math.log(clamped + 1) / math.log(cap + 1);
  }
}
