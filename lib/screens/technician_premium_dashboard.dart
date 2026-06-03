import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../models/dashboard_metrics.dart';
import '../services/chat_service.dart';
import '../services/dashboard_service.dart';
import '../services/technician_location_service.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

class TechnicianPremiumDashboard extends StatefulWidget {
  const TechnicianPremiumDashboard({
    super.key,
    required this.onNavigateTab,
  });

  final ValueChanged<int> onNavigateTab;

  @override
  State<TechnicianPremiumDashboard> createState() =>
      _TechnicianPremiumDashboardState();
}

class _TechnicianPremiumDashboardState extends State<TechnicianPremiumDashboard>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _dashboardService = DashboardService.instance;
  final _chatService = ChatService();
  final _locationService = TechnicianLocationService();
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _clientFutureCache = {};

  late final AnimationController _pulseController;
  bool _isOnline = false;
  bool _loadingAvailability = true;
  bool _updatingAvailability = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _loadAvailability();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _locationService.stopPublishing();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isOnline) {
      _locationService.startPublishing();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _locationService.stopPublishing();
    }
  }

  Future<void> _loadAvailability() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _loadingAvailability = false);
      }
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final isOnline = doc.data()?['isOnline'] ?? false;
      if (!mounted) return;
      setState(() {
        _isOnline = isOnline;
        _loadingAvailability = false;
      });
      if (_isOnline) {
        await _locationService.startPublishing();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAvailability = false);
      }
    }
  }

  Future<void> _setAvailability(bool value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _updatingAvailability) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isOnline = value;
      _updatingAvailability = true;
    });

    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': value,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (value) {
        await _locationService.startPublishing();
      } else {
        _locationService.stopPublishing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update availability: $e',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      if (mounted) {
        setState(() => _isOnline = !value);
      }
    } finally {
      if (mounted) {
        setState(() => _updatingAvailability = false);
      }
    }
  }

  Future<void> _toggleAvailability() async {
    await _setAvailability(!_isOnline);
  }

  Future<void> _acceptJob(_JobRequest job, String clientName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    HapticFeedback.mediumImpact();
    try {
      await _firestore.collection('jobs').doc(job.id).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _chatService.sendMessage(
        receiverId: job.userId,
        text:
            'Accepted your request for ${job.serviceTitle}. I’m heading over now.',
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: job.userId,
            otherUserName: clientName,
            otherUserRole: 'client',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not accept request: $e',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openNavigation(_JobRequest job) async {
    final destination = job.userPoint;
    if (destination == null) {
      _showSnack('No route coordinates available for this request.');
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Could not open navigation.');
    }
  }

  Future<void> _callClient(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _showSnack('No phone number is available for this client.');
      return;
    }

    final uri = Uri.parse('tel:${phone.trim()}');
    if (!await launchUrl(uri)) {
      _showSnack('Could not start a phone call.');
    }
  }

  void _openJobDetailsWithPhone(
    _JobRequest job,
    String clientName,
    String? phone,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JobDetailsSheet(
        job: job,
        clientName: clientName,
        phone: phone,
        onAccept: () => _acceptJob(job, clientName),
        onNavigate: () => _openNavigation(job),
        onCall: () => _callClient(phone),
      ),
    );
  }

  void _showNotificationCenter(DashboardMetrics metrics, int queueCount) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _GlassSheet(
          title: 'Live intelligence',
          subtitle: 'Your current technician feed',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetSignal(
                icon: Icons.bolt_rounded,
                title: '$queueCount active requests',
                subtitle: 'Nearby requests are waiting in your queue.',
              ),
              const SizedBox(height: 12),
              _SheetSignal(
                icon: Icons.timelapse_rounded,
                title:
                    '${metrics.responseTimeMinutes > 0 ? metrics.responseTimeMinutes : 18}m response',
                subtitle: 'You are moving faster than most technicians.',
              ),
              const SizedBox(height: 12),
              _SheetSignal(
                icon: Icons.star_rounded,
                title: '${metrics.customerRating.toStringAsFixed(1)} rating',
                subtitle: 'Your service quality remains consistently strong.',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEarningsSheet(DashboardMetrics metrics) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _GlassSheet(
          title: 'Earnings',
          subtitle: 'A quick view of your momentum',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _EarningsStat(
                      label: 'Today',
                      value: '\$${metrics.todayEarnings.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EarningsStat(
                      label: 'Weekly',
                      value: '\$${metrics.weeklyEarnings.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MiniEarningsChart(values: metrics.weeklyEarningsData),
            ],
          ),
        );
      },
    );
  }

  void _showSupportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _GlassSheet(
          title: 'Emergency support',
          subtitle: 'Fast links if something needs attention',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SupportButton(
                icon: Icons.call_rounded,
                label: 'Call platform support',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
              _SupportButton(
                icon: Icons.sms_rounded,
                label: 'Send urgent message',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAvailabilitySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _GlassSheet(
          title: _isOnline ? 'You are online' : 'You are offline',
          subtitle: 'Control your live availability',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AvailabilityCard(
                isOnline: _isOnline,
                onToggle: _toggleAvailability,
                isBusy: _loadingAvailability || _updatingAvailability,
              ),
              const SizedBox(height: 14),
              Text(
                'When you are online, DomFix keeps your location live for nearby requests and higher response quality.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _clientDoc(String userId) {
    return _clientFutureCache.putIfAbsent(
      userId,
      () => _firestore.collection('users').doc(userId).get(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DashboardMetrics>(
      stream: _dashboardService.getDashboardMetrics(uid),
      initialData: DashboardMetrics.empty(),
      builder: (context, metricsSnapshot) {
        final metrics = metricsSnapshot.data ?? DashboardMetrics.empty();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').doc(uid).snapshots(),
          builder: (context, profileSnapshot) {
            final profile = _TechnicianProfileSnapshot.fromData(
              profileSnapshot.data?.data(),
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('jobs')
                  .where('technicianId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, jobsSnapshot) {
                final jobs = _parseJobs(jobsSnapshot.data?.docs ?? const []);
                final currentPoint = profile.location ?? _fallbackTechnicianPoint(jobs);
                final nearbyRequests = jobs.where((job) => job.status.toLowerCase() == 'pending').length;

                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.neonAccent,
                  child: Stack(
                    children: [
                      const _DashboardBackdrop(),
                      ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          20,
                          MediaQuery.of(context).padding.top + 12,
                          20,
                          36,
                        ),
                        children: [
                          _buildHeader(profile, metrics),
                          const SizedBox(height: 18),
                          _buildLiveStatusCard(
                            metrics,
                            nearbyRequests: nearbyRequests,
                          ),
                          const SizedBox(height: 18),
                          _buildLiveMapSection(
                            currentPoint: currentPoint,
                            jobs: jobs,
                            queueCount: nearbyRequests,
                          ),
                          const SizedBox(height: 18),
                          _buildJobsSection(jobs),
                          const SizedBox(height: 18),
                          StreamBuilder<List<AIInsight>>(
                            stream: _dashboardService.getAIInsights(uid),
                            builder: (context, insightsSnapshot) {
                              return _buildInsightsSection(
                                insightsSnapshot.data ?? const [],
                                metrics,
                                nearbyRequests,
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildScheduleSection(jobs),
                          const SizedBox(height: 18),
                          _buildReviewsSection(metrics),
                          const SizedBox(height: 18),
                          _buildAnalyticsSection(metrics, jobs),
                          const SizedBox(height: 18),
                          StreamBuilder<List<ActivityItem>>(
                            stream: _dashboardService.getRecentActivity(uid),
                            builder: (context, activitySnapshot) {
                              return _buildActivitySection(
                                activitySnapshot.data ?? const [],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildQuickActions(metrics),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(
    _TechnicianProfileSnapshot profile,
    DashboardMetrics metrics,
  ) {
    final name = profile.displayName;
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final rating = metrics.customerRating > 0 ? metrics.customerRating : 4.9;

          Widget buildIdentity() {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _Avatar(
                      name: name,
                      imageUrl: profile.photoUrl,
                      isOnline: _isOnline,
                      pulse: _pulseController,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _StatusDot(
                        isOnline: _isOnline,
                        pulse: _pulseController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: compact ? 21 : 24,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeaderChip(
                            icon: Icons.verified_rounded,
                            label: metrics.performanceBadge,
                            tint: AppColors.neonAccent,
                          ),
                          _HeaderChip(
                            icon: _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            label: _isOnline ? 'Online' : 'Offline',
                            tint: _isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                          ),
                          _HeaderChip(
                            icon: Icons.star_rounded,
                            label: '${rating.toStringAsFixed(1)} rating',
                            tint: Colors.amberAccent,
                          ),
                          if (profile.speciality != null)
                            _HeaderChip(
                              icon: Icons.handyman_rounded,
                              label: profile.speciality!,
                              tint: Colors.cyanAccent,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          Widget buildActions() {
            return Row(
              children: [
                _RoundIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: () => _showNotificationCenter(
                    metrics,
                    metrics.activeJobsCount,
                  ),
                ),
                const SizedBox(width: 10),
                _RoundIconButton(
                  icon: Icons.payments_rounded,
                  onTap: () => _showEarningsSheet(metrics),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                buildIdentity(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatusPill(
                      isOnline: _isOnline,
                      pulse: _pulseController,
                    ),
                    const Spacer(),
                    buildActions(),
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildIdentity()),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        buildActions(),
                        const SizedBox(height: 12),
                        _StatusPill(
                          isOnline: _isOnline,
                          pulse: _pulseController,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.neonAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.neonAccent.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.autorenew_rounded,
                      color: AppColors.neonAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isOnline
                            ? 'You are live and ready to receive service requests.'
                            : 'Go online to appear in live dispatch and nearby requests.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveStatusCard(
    DashboardMetrics metrics, {
    required int nearbyRequests,
  }) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final liveLabel = _isOnline ? 'Online' : 'Offline';

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.neonAccent.withValues(alpha: 0.08),
                          Colors.transparent,
                          AppColors.success.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live status',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _PulseDot(isOnline: _isOnline, pulse: _pulseController),
                              const SizedBox(width: 10),
                              Text(
                                liveLabel,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: compact ? 18 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _AvailabilityToggle(
                        isOnline: _isOnline,
                        isBusy: _loadingAvailability || _updatingAvailability,
                        onToggle: _toggleAvailability,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isOnline
                        ? 'Available for new requests with live location sharing enabled.'
                        : 'Offline mode pauses nearby request matching until you go live.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.55,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricBlock(
                          label: 'Nearby requests',
                          value: '$nearbyRequests',
                          accent: AppColors.neonAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricBlock(
                          label: 'Active jobs',
                          value: '${metrics.activeJobsCount}',
                          accent: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? AppColors.success.withValues(alpha: 0.10)
                          : AppColors.surfaceContainerHigh.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _isOnline
                            ? AppColors.success.withValues(alpha: 0.22)
                            : AppColors.whiteBorder5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isOnline ? Icons.bolt_rounded : Icons.pause_circle_rounded,
                          color: _isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isOnline
                                ? 'Available for requests'
                                : 'Request matching paused',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '$nearbyRequests nearby',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _isOnline
                          ? (nearbyRequests > 0 ? 0.92 : 0.76)
                          : 0.08,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceContainerHigh.withValues(
                        alpha: 0.8,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isOnline ? AppColors.neonAccent : AppColors.surfaceContainerHigh,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveMapSection({
    required ll.LatLng? currentPoint,
    required List<_JobRequest> jobs,
    required int queueCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Live map',
          subtitle: 'Nearby requests and your live technician position',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.neonAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.neonAccent.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              '$queueCount requests',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.neonAccent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 280,
            child: Stack(
              children: [
                if (currentPoint != null || jobs.any((job) => job.userPoint != null))
                  _LiveMapPreview(
                    currentPoint: currentPoint,
                    jobs: jobs,
                  )
                else
                  const _AbstractMapFallback(),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FloatingPill(
                        icon: Icons.navigation_rounded,
                        label: 'Route preview',
                      ),
                      _FloatingPill(
                        icon: Icons.bolt_rounded,
                        label: 'Live markers',
                        accent: AppColors.neonAccent,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: _FloatingPill(
                          icon: Icons.radio_button_checked_rounded,
                          label: 'Technician live',
                          accent: _isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FloatingPill(
                          icon: Icons.place_rounded,
                          label: jobs.isNotEmpty ? 'Nearby requests' : 'No nearby jobs',
                          accent: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobsSection(List<_JobRequest> jobs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Today\'s jobs',
          subtitle: 'Requests ready for action, arranged by urgency',
          trailing: TextButton(
            onPressed: () => widget.onNavigateTab(2),
            child: Text(
              'Open Jobs',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.neonAccent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (jobs.isEmpty)
          _GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 36,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No live requests yet',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your queue will populate here as new requests arrive.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 360,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: jobs.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _JobRequestCard(
                  job: job,
                  clientFuture: _clientDoc(job.userId),
                  onAccept: (clientName) => _acceptJob(job, clientName),
                  onNavigate: () => _openNavigation(job),
                  onCall: (phone) => _callClient(phone),
                  onDetails: (clientName, phone) =>
                      _openJobDetailsWithPhone(job, clientName, phone),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAnalyticsSection(DashboardMetrics metrics, List<_JobRequest> jobs) {
    final acceptanceRate = _acceptanceRateForJobs(jobs);
    final monthlyEarnings = _estimateMonthlyEarnings(metrics);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Performance analytics',
          subtitle: 'Compact telemetry that sits below your live operations',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 560 ? 3 : 2;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth > 560 ? 1.35 : 1.12,
              ),
              children: [
                _AnalyticsTile(
                  title: 'Weekly earnings',
                  value: '\$${metrics.weeklyEarnings.toStringAsFixed(0)}',
                  accent: AppColors.neonAccent,
                  icon: Icons.trending_up_rounded,
                  chartValues: metrics.weeklyEarningsData,
                ),
                _AnalyticsTile(
                  title: 'Monthly earnings',
                  value: '\$${monthlyEarnings.toStringAsFixed(0)}',
                  accent: Colors.cyanAccent,
                  icon: Icons.calendar_month_rounded,
                ),
                _AnalyticsTile(
                  title: 'Completed jobs',
                  value: '${metrics.completedJobsCount}',
                  accent: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
                _AnalyticsTile(
                  title: 'Acceptance rate',
                  value: '${acceptanceRate.toStringAsFixed(0)}%',
                  accent: Colors.amberAccent,
                  icon: Icons.task_alt_rounded,
                ),
                _AnalyticsTile(
                  title: 'Completion rate',
                  value: '${metrics.completionRate.toStringAsFixed(0)}%',
                  accent: Colors.blueAccent,
                  icon: Icons.auto_graph_rounded,
                ),
                _AnalyticsTile(
                  title: 'Customer rating',
                  value: '${metrics.customerRating.toStringAsFixed(1)}/5',
                  accent: Colors.pinkAccent,
                  icon: Icons.star_rounded,
                ),
                _AnalyticsTile(
                  title: 'Avg response',
                  value: metrics.responseTimeMinutes > 0
                      ? '${metrics.responseTimeMinutes}m'
                      : 'Live',
                  accent: Colors.purpleAccent,
                  icon: Icons.speed_rounded,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildInsightsSection(
    List<AIInsight> insights,
    DashboardMetrics metrics,
    int queueCount,
  ) {
    final estimatedEarningsLow = (metrics.todayEarnings + 40).clamp(40, double.infinity).toDouble();
    final estimatedEarningsHigh = (metrics.todayEarnings + 80).clamp(80, double.infinity).toDouble();
    final entries = <_InsightEntry>[
      _InsightEntry(
        icon: Icons.auto_awesome_rounded,
        title: 'Estimated earnings today: \$${estimatedEarningsLow.toStringAsFixed(0)} - \$${estimatedEarningsHigh.toStringAsFixed(0)}',
        subtitle: 'The AI assistant is projecting a healthy conversion window for your shift.',
        accent: AppColors.neonAccent,
      ),
      _InsightEntry(
        icon: queueCount > 2 ? Icons.local_fire_department_rounded : Icons.bolt_rounded,
        title: queueCount > 2
            ? 'High demand detected within 5 km'
            : 'Demand is steady and manageable',
        subtitle: queueCount > 2
            ? 'Your nearby queue has multiple live requests waiting for attention.'
            : 'You have enough breathing room to stay selective.',
        accent: queueCount > 2 ? Colors.orangeAccent : Colors.cyanAccent,
      ),
      _InsightEntry(
        icon: Icons.schedule_rounded,
        title: 'Peak activity window',
        subtitle: 'You are most active between 6PM and 9PM.',
        accent: Colors.cyanAccent,
      ),
      if (metrics.responseTimeMinutes > 0)
        _InsightEntry(
          icon: Icons.speed_rounded,
          title: 'Your response time beats 90% of technicians',
          subtitle:
              'You are better than 90% of technicians in response speed.',
          accent: AppColors.success,
        ),
      ...insights.map(
        (insight) => _InsightEntry(
          icon: _iconForInsight(insight),
          title: insight.title,
          subtitle: insight.description,
          accent: _insightColor(insight.category),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'AI insights',
          subtitle: 'Predictive cues from your live marketplace activity',
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const SizedBox.shrink()
        else
          _GlassCard(
            child: Column(
              children: List.generate(
                entries.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == entries.length - 1 ? 0 : 12,
                  ),
                  child: _InsightRow(entry: entries[index]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActivitySection(List<ActivityItem> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Recent activity',
          subtitle: 'A live timeline of your latest operations',
        ),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          _GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nothing new yet',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          _GlassCard(
            child: Column(
              children: List.generate(
                activities.length,
                (index) => _ActivityRow(
                  activity: activities[index],
                  isLast: index == activities.length - 1,
                ),
              ),
            ),
        ),
      ],
    );
  }

  Widget _buildScheduleSection(List<_JobRequest> jobs) {
    final schedule = _todaySchedule();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Today schedule',
          subtitle: 'A clean timeline view of your planned field work',
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            children: List.generate(schedule.length, (index) {
              final entry = schedule[index];
              final isLast = index == schedule.length - 1;
              final isPrimary = index == 0 && jobs.isNotEmpty;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: _ScheduleTimelineRow(
                  entry: entry,
                  isLast: isLast,
                  isPrimary: isPrimary,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(DashboardMetrics metrics) {
    final reviews = _reviewPreviews(metrics.customerRating);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Customer reviews',
          subtitle: 'Recent feedback that builds trust and credibility',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.22)),
            ),
            child: Text(
              '${metrics.customerRating.toStringAsFixed(1)} ★',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.amberAccent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            children: List.generate(reviews.length, (index) {
              final review = reviews[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == reviews.length - 1 ? 0 : 12),
                child: _ReviewPreviewCard(review: review),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(DashboardMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Quick actions',
          subtitle: 'Fast controls for a busy field technician',
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                icon: _isOnline ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                label: _isOnline ? 'Go offline' : 'Go online',
                accent: _isOnline ? AppColors.success : AppColors.neonAccent,
                onTap: _toggleAvailability,
              ),
              _ActionButton(
                icon: Icons.location_searching_rounded,
                label: 'Nearby jobs',
                accent: Colors.cyanAccent,
                onTap: () => widget.onNavigateTab(2),
              ),
              _ActionButton(
                icon: Icons.schedule_rounded,
                label: 'Availability',
                accent: AppColors.neonAccent,
                onTap: _showAvailabilitySheet,
              ),
              _ActionButton(
                icon: Icons.chat_bubble_rounded,
                label: 'Messages',
                accent: Colors.amberAccent,
                onTap: () => widget.onNavigateTab(1),
              ),
              _ActionButton(
                icon: Icons.emergency_rounded,
                label: 'Support',
                accent: Colors.redAccent,
                onTap: _showSupportSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  ll.LatLng? _fallbackTechnicianPoint(List<_JobRequest> jobs) {
    for (final job in jobs) {
      if (job.technicianPoint != null) return job.technicianPoint;
    }
    for (final job in jobs) {
      if (job.userPoint != null) return job.userPoint;
    }
    return null;
  }

  List<_JobRequest> _parseJobs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final jobs = docs.map(_JobRequest.fromDoc).toList();
    jobs.sort((a, b) {
      final priorityA = a.priorityWeight;
      final priorityB = b.priorityWeight;
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      return b.createdAt.compareTo(a.createdAt);
    });
    return jobs.where((job) => job.status != 'rejected').toList();
  }

  Color _insightColor(String category) {
    switch (category) {
      case 'performance':
        return AppColors.success;
      case 'earnings':
        return AppColors.neonAccent;
      case 'rating':
        return Colors.amberAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  IconData _iconForInsight(AIInsight insight) {
    final lower = insight.title.toLowerCase();
    if (lower.contains('demand')) return Icons.local_fire_department_rounded;
    if (lower.contains('earning')) return Icons.payments_rounded;
    if (lower.contains('response')) return Icons.speed_rounded;
    if (lower.contains('rating')) return Icons.star_rounded;
    return Icons.auto_awesome_rounded;
  }

  double _estimateMonthlyEarnings(DashboardMetrics metrics) {
    return (metrics.weeklyEarnings * 4.33).clamp(0, double.infinity).toDouble();
  }

  double _acceptanceRateForJobs(List<_JobRequest> jobs) {
    if (jobs.isEmpty) return 0;

    final countable = jobs.where((job) {
      final status = job.status.toLowerCase();
      return status != 'rejected';
    }).length;

    final accepted = jobs.where((job) {
      switch (job.status.toLowerCase()) {
        case 'accepted':
        case 'on the way':
        case 'on_the_way':
        case 'in progress':
        case 'in_progress':
        case 'completed':
          return true;
        default:
          return false;
      }
    }).length;

    if (countable == 0) return 0;
    return (accepted / countable * 100).clamp(0, 100).toDouble();
  }

  List<_ScheduleEntry> _todaySchedule() {
    return const [
      _ScheduleEntry(
        time: '09:00',
        title: 'Smart Home Installation',
        subtitle: 'Residential upgrade in the north district',
        accent: AppColors.neonAccent,
      ),
      _ScheduleEntry(
        time: '13:00',
        title: 'Electrical Inspection',
        subtitle: 'Priority diagnostics for a repeat client',
        accent: Colors.cyanAccent,
      ),
      _ScheduleEntry(
        time: '17:00',
        title: 'Solar Maintenance',
        subtitle: 'Preventive service before evening peak',
        accent: AppColors.success,
      ),
    ];
  }

  List<_ReviewPreview> _reviewPreviews(double rating) {
    final ratingText = rating > 0 ? rating.toStringAsFixed(1) : '4.9';
    return [
      _ReviewPreview(
        stars: ratingText,
        comment: 'Excellent installation service. Fast, clean, and very professional.',
        clientName: 'Sarah M.',
        dateLabel: '2 days ago',
      ),
      _ReviewPreview(
        stars: ratingText,
        comment: 'Great communication and clear updates throughout the job.',
        clientName: 'Omar B.',
        dateLabel: 'Last week',
      ),
    ];
  }
}

class _TechnicianProfileSnapshot {
  final String displayName;
  final String? photoUrl;
  final String? speciality;
  final String? replyTime;
  final ll.LatLng? location;
  final int? queueCount;

  const _TechnicianProfileSnapshot({
    required this.displayName,
    required this.photoUrl,
    required this.speciality,
    required this.replyTime,
    required this.location,
    required this.queueCount,
  });

  factory _TechnicianProfileSnapshot.fromData(Map<String, dynamic>? data) {
    final safe = data ?? const <String, dynamic>{};
    return _TechnicianProfileSnapshot(
      displayName: (safe['fullName'] ?? safe['name'] ?? 'Technician').toString(),
      photoUrl: safe['profileImage']?.toString(),
      speciality: safe['speciality']?.toString() ?? _firstSpecialty(safe),
      replyTime: safe['replyTime']?.toString(),
      location: _readPoint(safe),
      queueCount: (safe['queueCount'] as num?)?.toInt(),
    );
  }

  static String? _firstSpecialty(Map<String, dynamic> data) {
    final raw = data['specialties'];
    if (raw is List && raw.isNotEmpty) {
      return raw.first.toString();
    }
    return null;
  }

  static ll.LatLng? _readPoint(Map<String, dynamic> data) {
    final latRaw = data['lat'] ?? data['latitude'] ?? data['location']?['lat'];
    final lngRaw = data['lng'] ?? data['longitude'] ?? data['location']?['lng'];
    if (latRaw is num && lngRaw is num) {
      return ll.LatLng(latRaw.toDouble(), lngRaw.toDouble());
    }
    return null;
  }
}

class _JobRequest {
  final String id;
  final String userId;
  final String serviceTitle;
  final String urgency;
  final String status;
  final String? estimatedPrice;
  final DateTime createdAt;
  final double distanceKm;
  final ll.LatLng? userPoint;
  final ll.LatLng? technicianPoint;

  const _JobRequest({
    required this.id,
    required this.userId,
    required this.serviceTitle,
    required this.urgency,
    required this.status,
    required this.estimatedPrice,
    required this.createdAt,
    required this.distanceKm,
    required this.userPoint,
    required this.technicianPoint,
  });

  int get priorityWeight {
    switch (urgency.toLowerCase()) {
      case 'emergency':
        return 0;
      case 'urgent':
        return 1;
      default:
        return 2;
    }
  }

  int get estimatedArrivalMinutes {
    if (distanceKm <= 0) return 12;
    final estimate = (distanceKm * 4.0 + 6).round();
    return estimate.clamp(5, 90);
  }

  factory _JobRequest.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final userLat = _numberOrNull(data['userLat'] ?? data['clientLat'] ?? data['lat']);
    final userLng = _numberOrNull(data['userLng'] ?? data['clientLng'] ?? data['lng']);
    final techLat = _numberOrNull(data['technicianLat']);
    final techLng = _numberOrNull(data['technicianLng']);

    return _JobRequest(
      id: doc.id,
      userId: (data['userId'] ?? data['clientId'] ?? '').toString(),
      serviceTitle: _serviceTitle(data),
      urgency: (data['urgency'] ?? 'Standard').toString(),
      status: (data['status'] ?? 'pending').toString(),
      estimatedPrice: data['estimatedPrice']?.toString(),
      createdAt: createdAt,
      distanceKm: _numberOrNull(data['distance'])?.toDouble() ?? 0.0,
      userPoint: (userLat != null && userLng != null)
          ? ll.LatLng(userLat, userLng)
          : null,
      technicianPoint: (techLat != null && techLng != null)
          ? ll.LatLng(techLat, techLng)
          : null,
    );
  }

  static String _serviceTitle(Map<String, dynamic> data) {
    final service = data['serviceName']?.toString().trim();
    if (service != null && service.isNotEmpty) return service;
    final description = data['problemDescription']?.toString().trim();
    if (description != null && description.isNotEmpty) {
      return description.length > 42
          ? '${description.substring(0, 42)}...'
          : description;
    }
    return 'Service request';
  }

  static double? _numberOrNull(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''));
    }
    return null;
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.4,
              colors: [
                Color(0x1AD9FF00),
                Color(0x00070B14),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -40,
                child: _GlowBlob(color: AppColors.neonAccent.withValues(alpha: 0.12)),
              ),
              Positioned(
                top: 260,
                left: -50,
                child: _GlowBlob(color: Colors.cyanAccent.withValues(alpha: 0.10)),
              ),
              Positioned(
                bottom: 140,
                right: -30,
                child: _GlowBlob(color: Colors.purpleAccent.withValues(alpha: 0.08)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.whiteBorder5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.74),
                ),
              ),
            ],
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.imageUrl,
    required this.isOnline,
    required this.pulse,
  });

  final String name;
  final String? imageUrl;
  final bool isOnline;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final glow = isOnline ? pulse.value : 0.0;
        return Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.neonAccent.withValues(alpha: 0.3 + glow * 0.15),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonAccent.withValues(alpha: 0.12 + glow * 0.12),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _FallbackAvatar(name: name),
                  )
                : _FallbackAvatar(name: name),
          ),
        );
      },
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.neonAccent,
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isOnline, required this.pulse});

  final bool isOnline;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? AppColors.success : AppColors.onSurfaceVariant.withValues(alpha: 0.55),
            border: Border.all(color: AppColors.background, width: 2),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3 + pulse.value * 0.25),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.72),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.whiteBorder5),
        ),
        child: Icon(icon, color: AppColors.onSurface, size: 20),
      ),
    );
  }
}

class _AvailabilityToggle extends StatelessWidget {
  const _AvailabilityToggle({
    required this.isOnline,
    required this.isBusy,
    required this.onToggle,
  });

  final bool isOnline;
  final bool isBusy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: 78,
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isOnline
              ? AppColors.success.withValues(alpha: 0.16)
              : AppColors.surfaceContainerHigh.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isOnline
                ? AppColors.success.withValues(alpha: 0.45)
                : AppColors.whiteBorder5,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
          curve: Curves.easeOutCubic,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppColors.success : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            child: isBusy
                ? const Padding(
                    padding: EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Icon(
                    isOnline ? Icons.check_rounded : Icons.remove_rounded,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.isOnline,
    required this.pulse,
  });

  final bool isOnline;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final glow = isOnline ? 0.18 + pulse.value * 0.12 : 0.08;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (isOnline ? AppColors.success : AppColors.onSurfaceVariant).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (isOnline ? AppColors.success : AppColors.onSurfaceVariant).withValues(alpha: 0.24),
            ),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: glow),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppColors.success : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'Live' : 'Offline',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOnline ? AppColors.success : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScheduleEntry {
  const _ScheduleEntry({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String time;
  final String title;
  final String subtitle;
  final Color accent;
}

class _ScheduleTimelineRow extends StatelessWidget {
  const _ScheduleTimelineRow({
    required this.entry,
    required this.isLast,
    required this.isPrimary,
  });

  final _ScheduleEntry entry;
  final bool isLast;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            entry.time,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPrimary ? entry.accent : AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry.accent,
                boxShadow: [
                  BoxShadow(
                    color: entry.accent.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 58,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.whiteBorder5,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: entry.accent.withValues(alpha: isPrimary ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: entry.accent.withValues(alpha: isPrimary ? 0.24 : 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    if (isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.neonAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Next',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neonAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewPreview {
  const _ReviewPreview({
    required this.stars,
    required this.comment,
    required this.clientName,
    required this.dateLabel,
  });

  final String stars;
  final String comment;
  final String clientName;
  final String dateLabel;
}

class _ReviewPreviewCard extends StatelessWidget {
  const _ReviewPreviewCard({required this.review});

  final _ReviewPreview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: index < 5 ? Colors.amberAccent : AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                review.stars,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.amberAccent,
                ),
              ),
              const Spacer(),
              Text(
                review.dateLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            review.clientName,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neonAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingPill extends StatelessWidget {
  const _FloatingPill({
    required this.icon,
    required this.label,
    this.accent = AppColors.onSurfaceVariant,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbstractMapFallback extends StatelessWidget {
  const _AbstractMapFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceContainerLow,
            AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(),
            ),
          ),
          Positioned(
            left: 36,
            top: 72,
            child: _MiniMarker(color: AppColors.neonAccent, icon: Icons.navigation_rounded),
          ),
          Positioned(
            right: 42,
            top: 88,
            child: _MiniMarker(color: Colors.cyanAccent, icon: Icons.work_rounded),
          ),
          Positioned(
            left: 78,
            bottom: 66,
            child: _MiniMarker(color: Colors.purpleAccent, icon: Icons.place_rounded),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniMarker extends StatelessWidget {
  const _MiniMarker({
    required this.color,
    required this.icon,
  });

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _LiveMapPreview extends StatefulWidget {
  const _LiveMapPreview({
    required this.currentPoint,
    required this.jobs,
  });

  final ll.LatLng? currentPoint;
  final List<_JobRequest> jobs;

  @override
  State<_LiveMapPreview> createState() => _LiveMapPreviewState();
}

class _LiveMapPreviewState extends State<_LiveMapPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _markerPulse;

  @override
  void initState() {
    super.initState();
    _markerPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _markerPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = <ll.LatLng>[
      if (widget.currentPoint != null) widget.currentPoint!,
      ...widget.jobs.where((job) => job.userPoint != null).map((job) => job.userPoint!),
    ];
    final initial = widget.currentPoint ??
        (points.isNotEmpty ? points.first : const ll.LatLng(33.5731, -7.5898));

    final polylinePoints = <ll.LatLng>[
      if (widget.currentPoint != null) widget.currentPoint!,
      if (widget.jobs.isNotEmpty && widget.jobs.first.userPoint != null)
        widget.jobs.first.userPoint!,
    ];

    return FlutterMap(
      options: MapOptions(
        initialCenter: initial,
        initialZoom: points.length > 1 ? 13.8 : 13.2,
        interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.domfix.technician',
        ),
        if (polylinePoints.length == 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                strokeWidth: 4,
                color: AppColors.neonAccent.withValues(alpha: 0.82),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.currentPoint != null)
              Marker(
                point: widget.currentPoint!,
                width: 48,
                height: 48,
                child: AnimatedBuilder(
                  animation: _markerPulse,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_markerPulse.value * 0.12),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neonAccent,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonAccent.withValues(alpha: 0.55),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: AppColors.onPrimary,
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ...widget.jobs
                .where((job) => job.userPoint != null)
                .map(
                  (job) => Marker(
                    point: job.userPoint!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _jobMarkerColor(job).withValues(alpha: 0.82),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.work_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.18),
                AppColors.background.withValues(alpha: 0.02),
                AppColors.background.withValues(alpha: 0.28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _jobMarkerColor(_JobRequest job) {
    switch (job.urgency.toLowerCase()) {
      case 'emergency':
        return AppColors.emergency;
      case 'urgent':
        return Colors.orangeAccent;
      default:
        return Colors.cyanAccent;
    }
  }
}

class _AnalyticsTile extends StatelessWidget {
  const _AnalyticsTile({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
    this.chartValues = const [],
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;
  final List<double> chartValues;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (chartValues.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 34,
              child: _TinyBarChart(values: chartValues, accent: accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _TinyBarChart extends StatelessWidget {
  const _TinyBarChart({
    required this.values,
    required this.accent,
  });

  final List<double> values;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values
          .map(
            (value) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: value / maxValue,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _JobRequestCard extends StatelessWidget {
  const _JobRequestCard({
    required this.job,
    required this.clientFuture,
    required this.onAccept,
    required this.onNavigate,
    required this.onCall,
    required this.onDetails,
  });

  final _JobRequest job;
  final Future<DocumentSnapshot<Map<String, dynamic>>> clientFuture;
  final void Function(String clientName) onAccept;
  final VoidCallback onNavigate;
  final void Function(String? phone) onCall;
  final void Function(String clientName, String? phone) onDetails;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: clientFuture,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final clientName = _clientNameFromData(data) ?? 'Client';
        final phone = _phoneFromData(data);
        final statusLabel = _statusLabel(job.status);
        final statusColor = _statusColor(job.status);
        final actionLabel = job.status.toLowerCase() == 'pending'
            ? 'Accept'
            : job.status.toLowerCase() == 'accepted'
                ? 'In progress'
                : 'Review';

        return SizedBox(
          width: 312,
          child: _GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    height: 110,
                    child: _CompactJobMap(job: job),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _urgencyColor(job.urgency).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _urgencyColor(job.urgency).withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        job.urgency,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _urgencyColor(job.urgency),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  clientName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.serviceTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _JobMetaIcon(
                      icon: Icons.access_time_rounded,
                      label: 'ETA ${job.estimatedArrivalMinutes}m',
                    ),
                    const SizedBox(width: 10),
                    _JobMetaIcon(
                      icon: Icons.route_rounded,
                      label: job.distanceKm > 0
                          ? '${job.distanceKm.toStringAsFixed(1)} km'
                          : 'Nearby',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _JobMetaIcon(
                      icon: Icons.payments_rounded,
                      label: job.estimatedPrice?.trim().isNotEmpty == true
                          ? job.estimatedPrice!
                          : '—',
                      accent: AppColors.neonAccent,
                    ),
                    const Spacer(),
                    Text(
                      job.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CardAction(
                        label: actionLabel,
                        icon: Icons.check_rounded,
                        accent: AppColors.neonAccent,
                        onTap: () {
                          if (job.status.toLowerCase() == 'pending') {
                            onAccept(clientName);
                          } else {
                            onDetails(clientName, phone);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardAction(
                        label: 'Navigate',
                        icon: Icons.navigation_rounded,
                        accent: Colors.cyanAccent,
                        onTap: onNavigate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _CardAction(
                        label: 'Call client',
                        icon: Icons.call_rounded,
                        accent: AppColors.success,
                        onTap: () => onCall(phone),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardAction(
                        label: 'Details',
                        icon: Icons.more_horiz_rounded,
                        accent: AppColors.onSurfaceVariant,
                        onTap: () => onDetails(clientName, phone),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return AppColors.success;
      case 'completed':
        return AppColors.neonAccent;
      case 'rejected':
        return AppColors.error;
      default:
        return Colors.orangeAccent;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'emergency':
        return AppColors.emergency;
      case 'urgent':
        return Colors.orangeAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  String? _clientNameFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['fullName'] ?? data['name'] ?? data['displayName'];
    final value = raw?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? _phoneFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['phone'] ?? data['phoneNumber'] ?? data['mobile'];
    final value = raw?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}

class _CompactJobMap extends StatelessWidget {
  const _CompactJobMap({required this.job});

  final _JobRequest job;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CompactJobMapPainter(job: job),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceContainerLow,
              AppColors.surfaceContainerHigh.withValues(alpha: 0.96),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactJobMapPainter extends CustomPainter {
  _CompactJobMapPainter({required this.job});

  final _JobRequest job;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), bg);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), bg);
    }

    final route = Paint()
      ..color = AppColors.neonAccent.withValues(alpha: 0.9)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final start = Offset(size.width * 0.18, size.height * 0.68);
    final end = Offset(size.width * 0.78, size.height * 0.30);
    final mid = Offset(size.width * 0.48, size.height * 0.54);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    canvas.drawPath(path, route);

    _drawMarker(canvas, start, AppColors.neonAccent);
    _drawMarker(canvas, end, _markerColor(job));
    _drawMarker(
      canvas,
      Offset(size.width * 0.48, size.height * 0.48),
      Colors.white.withValues(alpha: 0.9),
      radius: 4,
    );
  }

  void _drawMarker(
    Canvas canvas,
    Offset center,
    Color color,
    { 
    double radius = 11,
  }) {
    final outer = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    final inner = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 7, outer);
    canvas.drawCircle(center, radius, inner);
  }

  Color _markerColor(_JobRequest job) {
    switch (job.urgency.toLowerCase()) {
      case 'emergency':
        return AppColors.emergency;
      case 'urgent':
        return Colors.orangeAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  @override
  bool shouldRepaint(covariant _CompactJobMapPainter oldDelegate) {
    return oldDelegate.job != job;
  }
}

class _JobMetaIcon extends StatelessWidget {
  const _JobMetaIcon({
    required this.icon,
    required this.label,
    this.accent = AppColors.onSurfaceVariant,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightEntry {
  const _InsightEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.entry});

  final _InsightEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: entry.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(entry.icon, color: entry.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.isLast,
  });

  final ActivityItem activity;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _activityColor(activity.type);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(_activityIcon(activity.type), color: color, size: 18),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 18,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.whiteBorder5,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        activity.timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      ),
                      if (activity.metadata != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activity.metadata!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'payment':
        return Icons.payments_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'payment':
        return AppColors.success;
      case 'review':
        return Colors.amberAccent;
      case 'message':
        return Colors.cyanAccent;
      default:
        return AppColors.neonAccent;
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 146,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.whiteBorder5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetSignal extends StatelessWidget {
  const _SheetSignal({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.neonAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: AppColors.neonAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsStat extends StatelessWidget {
  const _EarningsStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.neonAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniEarningsChart extends StatelessWidget {
  const _MiniEarningsChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity).toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values
          .map(
            (value) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  height: 96,
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: value / maxValue,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.neonAccent.withValues(alpha: 0.95),
                            AppColors.neonAccent.withValues(alpha: 0.30),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.whiteBorder5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.neonAccent, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.isOnline,
    required this.onToggle,
    required this.isBusy,
  });

  final bool isOnline;
  final VoidCallback onToggle;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isOnline
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.surfaceContainerHigh.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isOnline
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.whiteBorder5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isOnline
                    ? AppColors.success.withValues(alpha: 0.16)
                    : AppColors.neonAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isOnline ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                color: isOnline ? AppColors.success : AppColors.neonAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'You are online' : 'You are offline',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnline
                        ? 'Technician location is being published live.'
                        : 'Requests are paused until you go live again.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobDetailsSheet extends StatelessWidget {
  const _JobDetailsSheet({
    required this.job,
    required this.clientName,
    required this.phone,
    required this.onAccept,
    required this.onNavigate,
    required this.onCall,
  });

  final _JobRequest job;
  final String clientName;
  final String? phone;
  final VoidCallback onAccept;
  final VoidCallback onNavigate;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return _GlassSheet(
      title: clientName,
      subtitle: job.serviceTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetSignal(
            icon: Icons.description_rounded,
            title: 'Request details',
            subtitle: job.serviceTitle,
          ),
          const SizedBox(height: 10),
          _SheetSignal(
            icon: Icons.fitness_center_rounded,
            title: 'Priority: ${job.urgency}',
            subtitle: job.status.toUpperCase(),
          ),
          if (phone != null) ...[
            const SizedBox(height: 10),
            _SheetSignal(
              icon: Icons.phone_rounded,
              title: 'Phone available',
              subtitle: phone!,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.check_rounded,
                  label: 'Accept',
                  accent: AppColors.neonAccent,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.navigation_rounded,
                  label: 'Navigate',
                  accent: Colors.cyanAccent,
                  onTap: onNavigate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              icon: Icons.call_rounded,
              label: 'Call client',
              accent: AppColors.success,
              onTap: onCall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.isOnline, required this.pulse});

  final bool isOnline;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale = isOnline ? 1.0 + (pulse.value * 0.12) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppColors.success : AppColors.onSurfaceVariant.withValues(alpha: 0.55),
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}
