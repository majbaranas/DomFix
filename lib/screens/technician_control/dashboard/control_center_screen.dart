import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../theme/app_colors.dart';
import '../../../services/dashboard_service.dart';
import '../../../models/dashboard_metrics.dart';
import '../../../models/booking_model.dart';
import '../../../services/technician_location_service.dart';
import '../../../widgets/premium/glass_card.dart';
import '../../../widgets/premium/animated_pulse_dot.dart';
import '../../../widgets/premium/uber_style_job_card.dart';

class ControlCenterScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;
  const ControlCenterScreen({super.key, required this.onNavigateTab});

  @override
  State<ControlCenterScreen> createState() => _ControlCenterScreenState();
}

class _ControlCenterScreenState extends State<ControlCenterScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _locationService = TechnicianLocationService();
  
  bool _isOnline = false;
  bool _updatingStatus = false;
  String _techName = 'Technician';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _techName = doc.data()?['displayName'] ?? 'Technician';
        _photoUrl = doc.data()?['photoUrl'];
        _isOnline = doc.data()?['isOnline'] ?? false;
      });
      if (_isOnline) {
        _locationService.startLocationTracking();
      }
    }
  }

  Future<void> _toggleAvailability() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _updatingStatus) return;

    HapticFeedback.lightImpact();
    setState(() => _updatingStatus = true);

    final newValue = !_isOnline;
    
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': newValue,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      if (newValue) {
        await _locationService.startLocationTracking();
      } else {
        _locationService.stopLocationTracking();
      }
      
      setState(() => _isOnline = newValue);
    } catch (e) {
      debugPrint('Error updating status: \$e');
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DashboardMetrics>(
      stream: DashboardService.instance.getDashboardMetrics(uid),
      builder: (context, metricsSnapshot) {
        final metrics = metricsSnapshot.data ?? DashboardMetrics.empty();
        
        return StreamBuilder<List<BookingModel>>(
          stream: DashboardService.instance.getTodayBookings(uid),
          builder: (context, bookingsSnapshot) {
            final activeBookings = bookingsSnapshot.data?.where((b) => b.isActive).toList() ?? [];
            activeBookings.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
            final primaryJob = activeBookings.isNotEmpty ? activeBookings.first : null;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildOnlineToggleCard(),
                      const SizedBox(height: 24),
                      _buildEarningsHUD(metrics),
                      const SizedBox(height: 32),
                      _buildNextActionHUD(primaryJob),
                      const SizedBox(height: 32),
                      _buildQuickActions(),
                      const SizedBox(height: 100), // padding for bottom nav
                    ]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background.withValues(alpha: 0.9),
      pinned: true,
      elevation: 0,
      expandedHeight: 80,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceContainerHigh,
              backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
              child: _photoUrl == null ? Icon(Icons.person, size: 16, color: AppColors.onSurface) : null,
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  _techName.split(' ').first,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineToggleCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          AnimatedPulseDot(
            color: _isOnline ? AppColors.neonAccent : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            size: 12,
            isAnimating: _isOnline,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'You\'re Online' : 'You\'re Offline',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  _isOnline ? 'Ready to accept new requests.' : 'Go online to receive jobs.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleAvailability,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _isOnline ? AppColors.neonAccent : AppColors.surfaceContainerHigh,
                border: Border.all(
                  color: _isOnline ? AppColors.neonAccent : AppColors.glassBorder,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isOnline ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsHUD(DashboardMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S EARNINGS",
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${metrics.todayEarnings.toStringAsFixed(0)}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.neonAccent,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Weekly: \$${metrics.weeklyEarnings.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
          Row(
          children: [
            Expanded(
              child: _buildStatMiniCard('Jobs Done', '${metrics.completedJobsCount}', Icons.check_circle_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatMiniCard('Rating', '${metrics.customerRating.toStringAsFixed(1)}', Icons.star_border),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatMiniCard(String label, String value, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextActionHUD(BookingModel? job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NEXT ACTION',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (job != null)
              GestureDetector(
                onTap: () => widget.onNavigateTab(1),
                child: Text(
                  'View all jobs',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neonAccent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (job == null)
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'No active jobs right now.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _firestore.collection('users').doc(job.clientId).get(),
            builder: (context, snapshot) {
              final clientData = snapshot.data?.data();
              final clientName = (clientData?['fullName'] ?? clientData?['name'] ?? 'Client').toString();
              return UberStyleJobCard(
                clientName: clientName,
                serviceType: job.serviceName,
                statusLabel: job.status.toUpperCase(),
                statusColor: AppColors.neonAccent,
                urgencyLabel: job.urgency,
                urgencyColor: AppColors.highPriority,
                timeAgo: 'Now',
                primaryActionLabel: 'Open Job Tracker',
                primaryActionIcon: Icons.open_in_new_rounded,
                onPrimaryAction: () => widget.onNavigateTab(1), // Navigates to jobs pipeline
              );
            },
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionItem(Icons.history_rounded, 'History', () {}),
            _buildActionItem(Icons.analytics_outlined, 'Analytics', () {}),
            _buildActionItem(Icons.message_outlined, 'Messages', () => widget.onNavigateTab(2)),
            _buildActionItem(Icons.help_outline_rounded, 'Help', () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(icon, color: AppColors.onSurface, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
