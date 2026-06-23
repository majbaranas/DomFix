import re
import os

filepath = r"d:\FlutterProjects\DomFix\lib\screens\technician_premium_dashboard.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Rename 'Statistics' to 'Command Center'
content = content.replace("'Statistics',", "'Command Center',", 1)

# 2. _buildNextActionHero replacement
old_hero = """    if (activeRequest == null) {
      content = Container(
        key: const ValueKey('idle'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.whiteBorder5),
          gradient: _isOnline
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.neonAccent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                )
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isOnline
                    ? AppColors.neonAccent.withValues(alpha: 0.12)
                    : AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isOnline ? Icons.radar_rounded : Icons.wifi_off_rounded,
                color: _isOnline ? AppColors.neonAccent : AppColors.onSurfaceVariant,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isOnline ? 'Ready for Work' : 'You\\'re offline',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isOnline
                  ? 'Waiting for new requests...'
                  : 'Go online to start receiving jobs',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            if (!_isOnline) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  label: 'Go Online',
                  icon: Icons.power_settings_new_rounded,
                  color: AppColors.neonAccent,
                  filled: true,
                  onTap: _toggleAvailability,
                ),
              ),
            ],
          ],
        ),
      );
    }"""

new_hero = """    if (activeRequest == null) {
      content = Container(
        key: const ValueKey('idle'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.whiteBorder5),
          gradient: _isOnline
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.neonAccent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isOnline
                    ? AppColors.neonAccent.withValues(alpha: 0.12)
                    : AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isOnline ? Icons.radar_rounded : Icons.wifi_off_rounded,
                color: _isOnline ? AppColors.neonAccent : AppColors.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnline ? 'Ready for Work' : 'You\\'re offline',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isOnline
                        ? 'Waiting for new requests...'
                        : 'Go online to receive jobs',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isOnline) ...[
              const SizedBox(width: 16),
              _ActionButton(
                label: 'Go Online',
                icon: Icons.power_settings_new_rounded,
                color: AppColors.neonAccent,
                filled: true,
                onTap: _toggleAvailability,
              ),
            ],
          ],
        ),
      );
    }"""
content = content.replace(old_hero, new_hero)

# 3. Replacing the SliverPadding and _buildStatisticsGrid invocation
old_sliver_padding = """                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: _buildStatisticsGrid(
                          metrics: data.metrics,
                          completedToday: data.completedToday,
                          pendingCount: data.pendingCount,
                          activeCount: data.activeCount,
                        ),
                      ),"""

new_sliver_padding = """                      _buildLiveStatisticsRow(
                        metrics: data.metrics,
                        pendingCount: data.pendingCount,
                        activeCount: data.activeCount,
                      ),
                      _buildTodayOverview(
                        metrics: data.metrics,
                        completedToday: data.completedToday,
                      ),"""
content = content.replace(old_sliver_padding, new_sliver_padding)

# 4. Replace _buildStatisticsGrid definition
old_build_stats = """  Widget _buildStatisticsGrid({
    required DashboardMetrics metrics,
    required int completedToday,
    required int pendingCount,
    required int activeCount,
  }) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildListDelegate([
        _PremiumStatCard(
          label: 'Pending',
          value: '$pendingCount',
          icon: Icons.schedule_rounded,
          color: const Color(0xFFFDC830), // Yellow
        ),
        _PremiumStatCard(
          label: 'Active',
          value: '$activeCount',
          icon: Icons.play_circle_fill_rounded,
          color: const Color(0xFF00C9FF), // Cyan
        ),
        _PremiumStatCard(
          label: 'Completed',
          value: '$completedToday',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        ),
        _PremiumStatCard(
          label: 'Rating',
          value: metrics.customerRating > 0 ? metrics.customerRating.toStringAsFixed(1) : 'New',
          icon: Icons.star_rounded,
          color: const Color(0xFFFF512F), // Red/Orange
        ),
      ]),
    );
  }"""

new_build_stats = """  Widget _buildLiveStatisticsRow({
    required DashboardMetrics metrics,
    required int pendingCount,
    required int activeCount,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 110,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          physics: const BouncingScrollPhysics(),
          children: [
            _HorizontalStatCard(
              label: 'Pending',
              value: '$pendingCount',
              icon: Icons.schedule_rounded,
              color: const Color(0xFFFDC830), // Yellow
            ),
            const SizedBox(width: 12),
            _HorizontalStatCard(
              label: 'Active',
              value: '$activeCount',
              icon: Icons.play_circle_fill_rounded,
              color: const Color(0xFF00C9FF), // Cyan
            ),
            const SizedBox(width: 12),
            _HorizontalStatCard(
              label: 'Completed',
              value: '${metrics.completedJobsCount}',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
            const SizedBox(width: 12),
            _HorizontalStatCard(
              label: 'Rating',
              value: metrics.customerRating > 0 ? metrics.customerRating.toStringAsFixed(1) : '--',
              icon: Icons.star_rounded,
              color: const Color(0xFFFF512F), // Red/Orange
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayOverview({
    required DashboardMetrics metrics,
    required int completedToday,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Text(
            'Today Overview',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TodayMetricCell(
                  label: 'Today\\'s Earnings',
                  value: _money(metrics.todayEarnings),
                  icon: Icons.payments_rounded,
                  color: AppColors.neonAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TodayMetricCell(
                  label: 'Jobs Done',
                  value: '$completedToday',
                  icon: Icons.task_alt_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TodayMetricCell(
                  label: 'Acceptance',
                  value: '--%',
                  icon: Icons.thumb_up_rounded,
                  color: const Color(0xFFFF512F), // Red/Orange
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TodayMetricCell(
                  label: 'Weekly',
                  value: _money(metrics.weeklyEarnings),
                  icon: Icons.auto_graph_rounded,
                  color: const Color(0xFF00C9FF), // Cyan
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }"""
content = content.replace(old_build_stats, new_build_stats)

# 5. Fix _ActionButton mainAxisSize
old_action_button = """        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 18),"""

new_action_button = """        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 18),"""
content = content.replace(old_action_button, new_action_button)

# 6. Append new classes
append_content = """

class _HorizontalStatCard extends StatelessWidget {
  const _HorizontalStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.whiteBorder5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayMetricCell extends StatelessWidget {
  const _TodayMetricCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
"""

if "_HorizontalStatCard" not in content:
    content += append_content

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updates applied.")
