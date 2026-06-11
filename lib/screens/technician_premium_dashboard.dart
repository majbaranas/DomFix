import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../models/booking_model.dart';
import '../models/dashboard_metrics.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/technician_location_service.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

class TechnicianPremiumDashboard extends StatefulWidget {
  const TechnicianPremiumDashboard({super.key, required this.onNavigateTab});

  final ValueChanged<int> onNavigateTab;

  @override
  State<TechnicianPremiumDashboard> createState() =>
      _TechnicianPremiumDashboardState();
}

class _TechnicianPremiumDashboardState extends State<TechnicianPremiumDashboard>
    with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _chatService = ChatService();
  final _notificationService = NotificationService.instance;
  final _locationService = TechnicianLocationService();
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
  _userFutureCache = {};

  String? _uid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  Stream<List<BookingModel>>? _bookingsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _jobsStream;

  bool _isOnline = false;
  bool _loadingAvailability = true;
  bool _updatingAvailability = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureStreams();
    _loadAvailability();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.stopLocationTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _isOnline) {
      _locationService.startLocationTracking();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _locationService.stopLocationTracking();
    }
  }

  void _configureStreams() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == _uid) return;

    _uid = uid;
    _profileStream = _firestore.collection('users').doc(uid).snapshots();
    _bookingsStream = _firestore
        .collection('bookings')
        .where('technicianId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(BookingModel.fromFirestore).toList());
    _jobsStream = _firestore
        .collection('jobs')
        .where('technicianId', isEqualTo: uid)
        .snapshots();
  }

  Future<void> _loadAvailability() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingAvailability = false);
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
      if (isOnline) {
        await _locationService.startLocationTracking();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAvailability = false);
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
        await _locationService.startLocationTracking();
      } else {
        _locationService.stopLocationTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOnline = !value);
        _showSnack('Could not update availability: $e');
      }
    } finally {
      if (mounted) setState(() => _updatingAvailability = false);
    }
  }

  Future<void> _toggleAvailability() => _setAvailability(!_isOnline);

  Future<void> _refresh() async {
    await _loadAvailability();
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _userDoc(String userId) {
    return _userFutureCache.putIfAbsent(
      userId,
      () => _firestore.collection('users').doc(userId).get(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid != null &&
        (_uid != currentUid ||
            _profileStream == null ||
            _bookingsStream == null ||
            _jobsStream == null)) {
      _configureStreams();
    }

    final uid = _uid ?? currentUid;
    if (uid == null || _profileStream == null || _bookingsStream == null || _jobsStream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        final profile = _TechnicianProfileSnapshot.fromData(
          profileSnapshot.data?.data(),
        );

        return StreamBuilder<List<BookingModel>>(
          stream: _bookingsStream,
          initialData: const <BookingModel>[],
          builder: (context, bookingsSnapshot) {
            final bookings = bookingsSnapshot.data ?? const <BookingModel>[];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _jobsStream,
              builder: (context, jobsSnapshot) {
                final jobs = _parseJobs(
                  jobsSnapshot.data?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                );
                final metrics = _buildMetrics(
                  profileData: profileSnapshot.data?.data(),
                  jobs: jobs,
                  bookings: bookings,
                );
                final pendingJobs = jobs
                    .where((job) => job.normalizedStatus == 'pending')
                    .toList();
                final activeJobs = jobs.where((job) => job.isActive).toList();
                final pendingBookings = bookings
                    .where((booking) => _statusOf(booking.status) == 'pending')
                    .toList();
                final activeBookings = bookings
                    .where((booking) => _isActiveBooking(booking.status))
                    .toList();
                final pendingCount =
                    pendingJobs.length + pendingBookings.length;
                final activeCount = activeJobs.length + activeBookings.length;
                final completedToday =
                    _completedToday(jobs: jobs, bookings: bookings);
                final pendingRequests = _combineRequests(
                  jobs: pendingJobs,
                  bookings: pendingBookings,
                );
                final activeRequest = _pickPrimaryActive(
                  jobs: activeJobs,
                  bookings: activeBookings,
                );
                final activities =
                    _buildActivities(jobs: jobs, bookings: bookings);

                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.neonAccent,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 12,
                      20,
                      28,
                    ),
                    children: [
                      _buildHeader(
                        profile: profile,
                        pendingCount: pendingCount,
                        activeCount: activeCount,
                      ),
                      const SizedBox(height: 18),
                      _buildTodaySummary(
                        metrics: metrics,
                        completedToday: completedToday,
                        pendingCount: pendingCount,
                      ),
                      const SizedBox(height: 18),
                      _buildActiveJobSection(
                        profile: profile,
                        activeRequest: activeRequest,
                      ),
                      const SizedBox(height: 18),
                      _buildRequestsSection(
                        profile: profile,
                        requests: pendingRequests,
                      ),
                      const SizedBox(height: 18),
                      _buildWeeklyEarnings(metrics),
                      const SizedBox(height: 18),
                      _buildActivitySection(activities),
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

  Widget _buildHeader({
    required _TechnicianProfileSnapshot profile,
    required int pendingCount,
    required int activeCount,
  }) {
    return Row(
      children: [
        _Avatar(name: profile.displayName, imageUrl: profile.photoUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, ${_firstName(profile.displayName)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _loadingAvailability || _updatingAvailability
                    ? null
                    : _toggleAvailability,
                borderRadius: BorderRadius.circular(999),
                child: _StatusBadge(
                  isOnline: _isOnline,
                  isBusy: _loadingAvailability || _updatingAvailability,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _IconCircleButton(
          icon: Icons.notifications_none_rounded,
          badgeCount: pendingCount,
          onTap: () => _showNotificationSheet(pendingCount, activeCount),
        ),
      ],
    );
  }

  Widget _buildTodaySummary({
    required DashboardMetrics metrics,
    required int completedToday,
    required int pendingCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Today',
          subtitle: 'At a glance',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _SummaryCard(
                    width: 152,
                    label: 'Earnings today',
                    value: _money(metrics.todayEarnings),
                    icon: Icons.payments_rounded,
                    color: AppColors.neonAccent,
                  );
                case 1:
                  return _SummaryCard(
                    width: 152,
                    label: 'Jobs completed',
                    value: '$completedToday',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                  );
                case 2:
                  return _SummaryCard(
                    width: 152,
                    label: 'Rating',
                    value: metrics.customerRating > 0
                        ? metrics.customerRating.toStringAsFixed(1)
                        : 'New',
                    icon: Icons.star_rounded,
                    color: Colors.amberAccent,
                  );
                default:
                  return _SummaryCard(
                    width: 152,
                    label: 'Pending jobs',
                    value: '$pendingCount',
                    icon: Icons.pending_actions_rounded,
                    color: Colors.cyanAccent,
                  );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveJobSection({
    required _TechnicianProfileSnapshot profile,
    required _DashboardRequest? activeRequest,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Active job',
          subtitle: 'The next action should be obvious',
        ),
        const SizedBox(height: 10),
        if (activeRequest == null)
          const _EmptyStateCard(
            icon: Icons.work_outline_rounded,
            title: 'No active job',
            message: 'Accepted jobs and bookings will appear here.',
          )
        else
          _ActiveRequestCard(
            request: activeRequest,
            profileLocation: profile.location,
            clientFuture: _userDoc(activeRequest.clientId),
            onNavigate: (destination) => _openNavigation(destination),
            onMessage: (clientName) =>
                _openMessage(activeRequest.clientId, clientName),
            onCall: (phone) => _callClient(phone),
            primaryActionLabel: activeRequest.isJob
                ? (activeRequest.isStarted ? 'Complete job' : 'Start job')
                : _bookingPrimaryActionLabel(activeRequest.status),
            primaryActionIcon: activeRequest.isJob
                ? (activeRequest.isStarted
                      ? Icons.check_circle_rounded
                      : Icons.play_arrow_rounded)
                : _bookingPrimaryActionIcon(activeRequest.status),
            onPrimaryAction: activeRequest.isJob
                ? (activeRequest.isStarted
                      ? () => _completeJob(activeRequest.job!)
                      : () => _startJob(activeRequest.job!))
                : () => _advanceBooking(activeRequest.booking!),
          ),
      ],
    );
  }

  Widget _buildRequestsSection({
    required _TechnicianProfileSnapshot profile,
    required List<_DashboardRequest> requests,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'New requests',
          subtitle: 'Simple accept or decline actions',
          trailing: TextButton(
            onPressed: () => widget.onNavigateTab(2),
            child: Text(
              'View all',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.neonAccent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (requests.isEmpty)
          const _EmptyStateCard(
            icon: Icons.inbox_outlined,
            title: 'No new requests',
            message: 'You are clear for now.',
          )
        else
          Column(
            children: [
              ...requests.take(3).map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                        child: _RequestCard(
                          request: request,
                          profileLocation: profile.location,
                          clientFuture: _userDoc(request.clientId),
                          onAccept: request.isJob
                              ? () => _acceptJob(request.job!)
                              : () => _acceptBooking(request.booking!),
                          onDecline: request.isJob
                              ? () => _declineJob(request.job!)
                              : () => _declineBooking(request.booking!),
                      ),
                    ),
                  ),
              if (requests.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => widget.onNavigateTab(2),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'See more requests',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildWeeklyEarnings(DashboardMetrics metrics) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHeader(
                  title: 'Weekly earnings',
                  subtitle: _money(metrics.weeklyEarnings),
                ),
              ),
              _IconCircleButton(
                icon: Icons.trending_up_rounded,
                onTap: () => _showEarningsSheet(metrics),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WeeklyEarningsChart(values: metrics.weeklyEarningsData),
        ],
      ),
    );
  }

  Widget _buildActivitySection(List<ActivityItem> activities) {
    final visibleActivities = activities.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Recent activity',
          subtitle: 'Lightweight history of what happened',
        ),
        const SizedBox(height: 10),
        if (activities.isEmpty)
          const _EmptyStateCard(
            icon: Icons.history_rounded,
            title: 'No recent activity',
            message: 'Completed work and messages will appear here.',
          )
        else
          _SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: List.generate(
                visibleActivities.length,
                (index) => Column(
                  children: [
                    _ActivityRow(activity: visibleActivities[index]),
                    if (index < visibleActivities.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 48),
                        child: Divider(color: AppColors.divider, height: 18),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationSheet(int pendingCount, int activeCount) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
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
                const SizedBox(height: 16),
                Text(
                  'Notifications',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SheetMetric(
                        label: 'New requests',
                        value: '$pendingCount',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetMetric(
                        label: 'Active jobs',
                        value: '$activeCount',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _LargeActionButton(
                  icon: Icons.work_rounded,
                  label: 'Open jobs',
                  color: AppColors.neonAccent,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigateTab(2);
                  },
                ),
                const SizedBox(height: 10),
                _LargeActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Open messages',
                  color: Colors.cyanAccent,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigateTab(1);
                  },
                ),
                const SizedBox(height: 10),
                _LargeActionButton(
                  icon: _isOnline
                      ? Icons.pause_circle_rounded
                      : Icons.play_circle_rounded,
                  label: _isOnline ? 'Go offline' : 'Go online',
                  color: _isOnline ? AppColors.success : AppColors.neonAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleAvailability();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEarningsSheet(DashboardMetrics metrics) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
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
                const SizedBox(height: 16),
                Text(
                  'Weekly earnings',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SheetMetric(
                        label: 'Today',
                        value: _money(metrics.todayEarnings),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetMetric(
                        label: 'Week',
                        value: _money(metrics.weeklyEarnings),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _WeeklyEarningsChart(values: metrics.weeklyEarningsData),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _acceptJob(_JobRequest job) async {
    HapticFeedback.mediumImpact();
    try {
      await _updateJobStatus(job, 'accepted');
      await _chatService.sendMessage(
        receiverId: job.userId,
        text: 'I accepted your request for ${job.serviceTitle}.',
      );
      _showSnack('Request accepted.');
    } catch (e) {
      _showSnack('Could not accept request: $e');
    }
  }

  Future<void> _declineJob(_JobRequest job) async {
    HapticFeedback.lightImpact();
    try {
      await _updateJobStatus(job, 'rejected');
      await _chatService.sendMessage(
        receiverId: job.userId,
        text: 'I cannot take this request right now.',
      );
      _showSnack('Request declined.');
    } catch (e) {
      _showSnack('Could not decline request: $e');
    }
  }

  Future<void> _startJob(_JobRequest job) async {
    try {
      await _updateJobStatus(job, 'in_progress');
      await _chatService.sendMessage(
        receiverId: job.userId,
        text: 'I started the job for ${job.serviceTitle}.',
      );
      _showSnack('Job started.');
    } catch (e) {
      _showSnack('Could not start job: $e');
    }
  }

  Future<void> _completeJob(_JobRequest job) async {
    try {
      await _updateJobStatus(job, 'completed');
      await _chatService.sendMessage(
        receiverId: job.userId,
        text: 'The job is complete. Thank you for choosing DomFix.',
      );
      _showSnack('Job completed.');
    } catch (e) {
      _showSnack('Could not complete job: $e');
    }
  }

  Future<void> _updateJobStatus(_JobRequest job, String status) async {
    final normalizedStatus = _statusOf(status);
    await _firestore.collection('jobs').doc(job.id).update({
      'status': normalizedStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _syncChatStatus(job.userId, normalizedStatus);
    await _notifyJobStatusChange(job: job, status: normalizedStatus);
    _syncLiveStatusForJob(normalizedStatus);
  }

  Future<void> _acceptBooking(BookingModel booking) async {
    try {
      await _updateBookingStatus(booking, 'accepted');
      await _chatService.sendMessage(
        receiverId: booking.clientId,
        text: 'I accepted your booking for ${booking.serviceName}.',
      );
      _showSnack('Booking accepted.');
    } catch (e) {
      _showSnack('Could not accept booking: $e');
    }
  }

  Future<void> _declineBooking(BookingModel booking) async {
    try {
      await _updateBookingStatus(booking, 'rejected');
      await _chatService.sendMessage(
        receiverId: booking.clientId,
        text: 'I cannot take this booking right now.',
      );
      _showSnack('Booking declined.');
    } catch (e) {
      _showSnack('Could not decline booking: $e');
    }
  }

  Future<void> _advanceBooking(BookingModel booking) async {
    final currentStatus = _statusOf(booking.status);
    final nextStatus = switch (currentStatus) {
      'pending' => 'accepted',
      'accepted' || 'confirmed' => 'on_the_way',
      'on_the_way' => 'arrived',
      'arrived' => 'in_progress',
      'in_progress' => 'completed',
      _ => currentStatus,
    };

    if (nextStatus == currentStatus) {
      _showSnack('This booking is already finished.');
      return;
    }

    try {
      await _updateBookingStatus(booking, nextStatus);
      switch (nextStatus) {
        case 'accepted':
          await _chatService.sendMessage(
            receiverId: booking.clientId,
            text: 'I accepted your booking for ${booking.serviceName}.',
          );
          _showSnack('Booking accepted.');
          break;
        case 'on_the_way':
          await _chatService.sendMessage(
            receiverId: booking.clientId,
            text: 'I am on the way for ${booking.serviceName}.',
          );
          _showSnack('Marked as on the way.');
          break;
        case 'arrived':
          await _chatService.sendMessage(
            receiverId: booking.clientId,
            text: 'I have arrived for ${booking.serviceName}.',
          );
          _showSnack('Marked as arrived.');
          break;
        case 'in_progress':
          await _chatService.sendMessage(
            receiverId: booking.clientId,
            text: 'I started the job for ${booking.serviceName}.',
          );
          _showSnack('Job started.');
          break;
        case 'completed':
          await _chatService.sendMessage(
            receiverId: booking.clientId,
            text: 'The job is complete. Thank you for choosing DomFix.',
          );
          _showSnack('Job completed.');
          break;
      }
    } catch (e) {
      _showSnack('Could not update booking: $e');
    }
  }

  Future<void> _updateBookingStatus(BookingModel booking, String status) async {
    final normalizedStatus = _statusOf(status);
    await _firestore.collection('bookings').doc(booking.id).update({
      'status': normalizedStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (booking.chatId.isNotEmpty) {
      await _firestore.collection('chats').doc(booking.chatId).set({
        'bookingStatus': normalizedStatus,
        'accessLevel': normalizedStatus == 'rejected' ? 'limited' : 'full',
        'canShareImages': normalizedStatus != 'rejected',
        'canUseVoiceNotes': normalizedStatus != 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _notifyBookingStatusChange(
      booking: booking,
      status: normalizedStatus,
    );
    _syncLiveStatusForJob(normalizedStatus);
  }

  void _syncLiveStatusForJob(String normalizedStatus) {
    if (normalizedStatus == 'accepted' || normalizedStatus == 'confirmed') {
      _locationService.updateLiveStatus('busy');
    } else if (normalizedStatus == 'on_the_way' || 
               normalizedStatus == 'arrived' || 
               normalizedStatus == 'in_progress') {
      _locationService.updateLiveStatus('on_job');
    } else if (normalizedStatus == 'completed' || 
               normalizedStatus == 'rejected' || 
               normalizedStatus == 'cancelled') {
      _locationService.updateLiveStatus('online');
    }
  }

  Future<void> _syncChatStatus(String clientId, String status) async {
    final technicianId = _auth.currentUser?.uid;
    if (technicianId == null || clientId.isEmpty) return;

    final chatId = ChatService.generateChatId(clientId, technicianId);
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [clientId, technicianId],
      'bookingStatus': status,
      'accessLevel': status == 'rejected' ? 'limited' : 'full',
      'canShareImages': status != 'rejected',
      'canUseVoiceNotes': status != 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _notifyJobStatusChange({
    required _JobRequest job,
    required String status,
  }) async {
    final title = switch (status) {
      'accepted' => 'Request accepted',
      'rejected' => 'Request declined',
      'in_progress' => 'Job started',
      'completed' => 'Job completed',
      _ => 'Request updated',
    };
    final body = switch (status) {
      'accepted' => 'Your request is now being handled.',
      'rejected' => 'Your request could not be accepted right now.',
      'in_progress' => 'Work has started on your request.',
      'completed' => 'The job has been completed.',
      _ => 'Your request status has changed.',
    };

    await _sendNotification(
      recipientId: job.userId,
      senderId: _auth.currentUser?.uid ?? job.userId,
      type: 'job_$status',
      title: title,
      body: body,
      jobId: job.id,
      status: status,
      serviceName: job.serviceTitle,
      urgency: job.urgency,
      metadata: {
        'distanceKm': job.distanceKm,
      },
    );
  }

  Future<void> _notifyBookingStatusChange({
    required BookingModel booking,
    required String status,
  }) async {
    final title = switch (status) {
      'accepted' => 'Booking accepted',
      'on_the_way' => 'Technician on the way',
      'arrived' => 'Technician arrived',
      'in_progress' => 'Job started',
      'completed' => 'Job completed',
      'rejected' => 'Booking declined',
      'cancelled' => 'Booking cancelled',
      _ => 'Booking updated',
    };
    final body = switch (status) {
      'accepted' =>
        '${booking.technicianName} accepted your booking for ${booking.serviceName}.',
      'on_the_way' =>
        '${booking.technicianName} is on the way for ${booking.serviceName}.',
      'arrived' =>
        '${booking.technicianName} has arrived for ${booking.serviceName}.',
      'in_progress' => 'Work has started on your booking.',
      'completed' => 'Your booking has been completed.',
      'rejected' => 'Your booking was declined.',
      'cancelled' => 'Your booking was cancelled.',
      _ => 'Your booking status has changed.',
    };

    await _sendNotification(
      recipientId: booking.clientId,
      senderId: _auth.currentUser?.uid ?? booking.technicianId,
      type: 'booking_$status',
      title: title,
      body: body,
      bookingId: booking.id,
      chatId: booking.chatId,
      status: status,
      serviceName: booking.serviceName,
      urgency: booking.urgency,
      metadata: {
        'scheduledAt': booking.scheduledAt.toIso8601String(),
        'scheduledTimeLabel': booking.scheduledTimeLabel,
      },
    );
  }

  Future<void> _sendNotification({
    required String recipientId,
    required String senderId,
    required String type,
    required String title,
    required String body,
    String? bookingId,
    String? chatId,
    String? jobId,
    String? status,
    String? serviceName,
    String? urgency,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _notificationService.createNotification(
        recipientId: recipientId,
        senderId: senderId,
        type: type,
        title: title,
        body: body,
        bookingId: bookingId,
        chatId: chatId,
        jobId: jobId,
        status: status,
        serviceName: serviceName,
        urgency: urgency,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('[TechnicianDashboard] Notification write failed: $e');
    }
  }

  Future<void> _openNavigation(ll.LatLng? destination) async {
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

  void _openMessage(String clientId, String clientName) {
    if (clientId.isEmpty) {
      _showSnack('Client information is missing.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: clientId,
          otherUserName: clientName,
          otherUserRole: 'client',
        ),
      ),
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

  List<_JobRequest> _parseJobs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final jobs = docs.map(_JobRequest.fromDoc).toList();
    jobs.sort((a, b) {
      final priorityA = a.priorityWeight;
      final priorityB = b.priorityWeight;
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      final workflowA = a.workflowPriority;
      final workflowB = b.workflowPriority;
      if (workflowA != workflowB) return workflowA.compareTo(workflowB);
      final updatedA = a.updatedAt ?? a.createdAt;
      final updatedB = b.updatedAt ?? b.createdAt;
      return updatedB.compareTo(updatedA);
    });
    return jobs;
  }

  DashboardMetrics _buildMetrics({
    required Map<String, dynamic>? profileData,
    required List<_JobRequest> jobs,
    required List<BookingModel> bookings,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final rating = (profileData?['rating'] as num?)?.toDouble() ?? 0.0;

    double todayEarnings = 0;
    double weeklyEarnings = 0;
    int activeJobs = 0;
    int completedJobs = 0;
    int totalJobs = 0;
    final weeklyData = List<double>.filled(7, 0.0);

    for (final job in jobs) {
      totalJobs++;
      if (job.isActive) activeJobs++;
      if (job.normalizedStatus == 'completed') completedJobs++;
    }

    for (final booking in bookings) {
      totalJobs++;
      if (booking.isActive) activeJobs++;
      if (_statusOf(booking.status) == 'completed') completedJobs++;

      final effectiveDate = booking.updatedAt ?? booking.createdAt;
      if (_statusOf(booking.status) == 'completed') {
        if (effectiveDate.isAfter(todayStart)) {
          todayEarnings += booking.technicianFee;
        }
        if (effectiveDate.isAfter(weekStart)) {
          weeklyEarnings += booking.technicianFee;
          final dayIndex = effectiveDate.difference(weekStart).inDays;
          if (dayIndex >= 0 && dayIndex < 7) {
            weeklyData[dayIndex] += booking.technicianFee;
          }
        }
      }
    }

    final completionRate = totalJobs > 0
        ? (completedJobs / totalJobs * 100)
        : 0.0;

    return DashboardMetrics(
      todayEarnings: todayEarnings,
      weeklyEarnings: weeklyEarnings,
      activeJobsCount: activeJobs,
      completedJobsCount: completedJobs,
      completionRate: completionRate,
      customerRating: rating,
      responseTimeMinutes: 0,
      cancellationRate: totalJobs > 0
          ? ((totalJobs - completedJobs) / totalJobs * 100)
          : 0,
      weeklyEarningsData: weeklyData,
      isOnline: _isOnline,
      performanceBadge: _performanceBadge(completionRate, rating),
      lastUpdated: DateTime.now(),
    );
  }

  int _completedToday({
    required List<_JobRequest> jobs,
    required List<BookingModel> bookings,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var count = 0;
    for (final job in jobs) {
      final updated = job.updatedAt ?? job.createdAt;
      if (job.normalizedStatus == 'completed' && updated.isAfter(today)) {
        count++;
      }
    }
    for (final booking in bookings) {
      final updated = booking.updatedAt ?? booking.createdAt;
      if (_statusOf(booking.status) == 'completed' && updated.isAfter(today)) {
        count++;
      }
    }
    return count;
  }

  List<_DashboardRequest> _combineRequests({
    required List<_JobRequest> jobs,
    required List<BookingModel> bookings,
  }) {
    final requests = <_DashboardRequest>[
      ...jobs.map((job) => _DashboardRequest.job(job)),
      ...bookings.map((booking) => _DashboardRequest.booking(booking)),
    ];
    requests.sort((a, b) {
      final priorityA = a.priorityWeight;
      final priorityB = b.priorityWeight;
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      final workflowA = a.workflowPriority;
      final workflowB = b.workflowPriority;
      if (workflowA != workflowB) return workflowA.compareTo(workflowB);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return requests;
  }

  _DashboardRequest? _pickPrimaryActive({
    required List<_JobRequest> jobs,
    required List<BookingModel> bookings,
  }) {
    final activeRequests = <_DashboardRequest>[
      ...jobs
          .where((job) => job.isActive)
          .map((job) => _DashboardRequest.job(job)),
      ...bookings
          .where((booking) => _isActiveBooking(booking.status))
          .map((booking) => _DashboardRequest.booking(booking)),
    ];

    if (activeRequests.isEmpty) return null;
    activeRequests.sort((a, b) {
      final workflowA = a.workflowPriority;
      final workflowB = b.workflowPriority;
      if (workflowA != workflowB) return workflowA.compareTo(workflowB);
      final urgencyA = a.priorityWeight;
      final urgencyB = b.priorityWeight;
      if (urgencyA != urgencyB) return urgencyA.compareTo(urgencyB);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return activeRequests.first;
  }

  List<ActivityItem> _buildActivities({
    required List<_JobRequest> jobs,
    required List<BookingModel> bookings,
  }) {
    final items = <ActivityItem>[];

    for (final job in jobs) {
      final timestamp = job.updatedAt ?? job.createdAt;
      final status = _statusOf(job.status);
      final title = switch (status) {
        'accepted' => 'Request accepted',
        'in_progress' => 'Job started',
        'completed' => 'Job completed',
        'rejected' => 'Request declined',
        _ => 'New request',
      };

      items.add(
        ActivityItem(
          id: 'job_${job.id}',
          type: status == 'completed'
              ? 'booking'
              : status == 'rejected'
                  ? 'message'
                  : 'booking',
          title: title,
          description: job.serviceTitle,
          timestamp: timestamp,
          metadata: job.urgency,
        ),
      );
    }

    for (final booking in bookings) {
      final timestamp = booking.updatedAt ?? booking.createdAt;
      final status = _statusOf(booking.status);
      final title = switch (status) {
        'accepted' => 'Booking accepted',
        'in_progress' => 'Job started',
        'completed' => 'Job completed',
        'rejected' => 'Booking declined',
        _ => 'New booking request',
      };

      items.add(
        ActivityItem(
          id: 'booking_${booking.id}',
          type: status == 'completed'
              ? 'booking'
              : status == 'rejected'
                  ? 'message'
                  : 'booking',
          title: title,
          description: booking.serviceName.isNotEmpty
              ? booking.serviceName
              : booking.description,
          timestamp: timestamp,
          metadata: booking.technicianFee > 0
              ? _money(booking.technicianFee)
              : booking.urgency,
        ),
      );
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(4).toList();
  }

  static bool _isActiveBooking(String status) {
    switch (_statusOf(status)) {
      case 'accepted':
      case 'confirmed':
      case 'on_the_way':
      case 'arrived':
      case 'in_progress':
        return true;
      default:
        return false;
    }
  }

  static String _statusOf(String status) {
    final lower = status.toLowerCase().trim();
    if (lower == 'in progress') return 'in_progress';
    if (lower == 'on the way') return 'on_the_way';
    return lower;
  }

  static int _urgencyPriority(String urgency) {
    switch (urgency.toLowerCase().trim()) {
      case 'emergency':
        return 0;
      case 'high':
      case 'urgent':
        return 1;
      case 'medium':
      case 'standard':
      case 'normal':
        return 2;
      case 'low':
        return 3;
      default:
        return 2;
    }
  }

  String _bookingPrimaryActionLabel(String status) {
    switch (_statusOf(status)) {
      case 'pending':
        return 'Accept booking';
      case 'accepted':
      case 'confirmed':
        return 'On the way';
      case 'on_the_way':
        return 'Arrived';
      case 'arrived':
        return 'Start job';
      case 'in_progress':
        return 'Complete job';
      default:
        return 'Update status';
    }
  }

  IconData _bookingPrimaryActionIcon(String status) {
    switch (_statusOf(status)) {
      case 'pending':
        return Icons.check_rounded;
      case 'accepted':
      case 'confirmed':
        return Icons.navigation_rounded;
      case 'on_the_way':
        return Icons.location_on_rounded;
      case 'arrived':
        return Icons.play_arrow_rounded;
      case 'in_progress':
        return Icons.check_circle_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  static String _performanceBadge(double completionRate, double rating) {
    if (completionRate >= 98 && rating >= 4.9) return 'Elite';
    if (completionRate >= 95 && rating >= 4.7) return 'Professional';
    if (completionRate >= 90 && rating >= 4.5) return 'Experienced';
    return 'Active';
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Technician';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static String _money(double value) => '\$${value.toStringAsFixed(0)}';

  static String _timeLabel(BookingModel booking) {
    if (booking.scheduledTimeLabel.trim().isNotEmpty) {
      return booking.scheduledTimeLabel;
    }
    final date = booking.scheduledAt;
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  static String _bookingEarnings(BookingModel booking) {
    if (booking.technicianFee > 0) {
      return _money(booking.technicianFee);
    }
    if (booking.estimatedPriceMin > 0 || booking.estimatedPriceMax > 0) {
      return '\$${booking.estimatedPriceMin.toStringAsFixed(0)}-${booking.estimatedPriceMax.toStringAsFixed(0)}';
    }
    return 'Estimate pending';
  }

  static String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static ll.LatLng? _readPoint(Map<String, dynamic>? data) {
    if (data == null) return null;
    final latRaw = data['lat'] ?? data['latitude'] ?? data['location']?['lat'];
    final lngRaw = data['lng'] ?? data['longitude'] ?? data['location']?['lng'];
    if (latRaw is num && lngRaw is num) {
      return ll.LatLng(latRaw.toDouble(), lngRaw.toDouble());
    }
    return null;
  }

  static String? _clientNameFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['fullName'] ?? data['name'] ?? data['displayName'];
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _phoneFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['phone'] ?? data['phoneNumber'] ?? data['mobile'];
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _distanceText({
    required ll.LatLng? technicianLocation,
    required Map<String, dynamic>? clientData,
    required double? fallbackKm,
  }) {
    if (fallbackKm != null && fallbackKm > 0) {
      return '${fallbackKm.toStringAsFixed(1)} km';
    }

    final clientLocation = _readPoint(clientData);
    if (technicianLocation != null && clientLocation != null) {
      final distance = TechnicianLocationService.distanceKmPublic(
        technicianLocation,
        clientLocation,
      );
      return '${distance.toStringAsFixed(1)} km';
    }

    return 'Nearby';
  }

  static String _requestTimeText(_DashboardRequest request) {
    if (request.isJob) {
      return _timeAgo(request.updatedAt);
    }
    final booking = request.booking!;
    return _timeLabel(booking);
  }

  static String _requestEarningsText(_DashboardRequest request) {
    if (request.isJob) {
      final price = request.job!.estimatedPrice?.trim();
      if (price != null && price.isNotEmpty) return price;
      return 'Estimate pending';
    }
    return _bookingEarnings(request.booking!);
  }
}

class _TechnicianProfileSnapshot {
  final String displayName;
  final String? photoUrl;
  final ll.LatLng? location;

  const _TechnicianProfileSnapshot({
    required this.displayName,
    required this.photoUrl,
    required this.location,
  });

  factory _TechnicianProfileSnapshot.fromData(Map<String, dynamic>? data) {
    final safe = data ?? const <String, dynamic>{};
    return _TechnicianProfileSnapshot(
      displayName: (safe['fullName'] ?? safe['name'] ?? 'Technician').toString(),
      photoUrl: (safe['profileImage'] ?? safe['photoUrl'])?.toString(),
      location: _TechnicianPremiumDashboardState._readPoint(safe),
    );
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
  final DateTime? updatedAt;
  final double distanceKm;
  final ll.LatLng? userPoint;

  const _JobRequest({
    required this.id,
    required this.userId,
    required this.serviceTitle,
    required this.urgency,
    required this.status,
    required this.estimatedPrice,
    required this.createdAt,
    required this.updatedAt,
    required this.distanceKm,
    required this.userPoint,
  });

  String get normalizedStatus =>
      _TechnicianPremiumDashboardState._statusOf(status);

  bool get isActive =>
      normalizedStatus == 'accepted' ||
      normalizedStatus == 'arrived' ||
      normalizedStatus == 'on_the_way' ||
      normalizedStatus == 'in_progress' ||
      normalizedStatus == 'confirmed';

  bool get isStarted => normalizedStatus == 'in_progress';

  int get priorityWeight {
    return _TechnicianPremiumDashboardState._urgencyPriority(urgency);
  }

  int get workflowPriority {
    final normalized = normalizedStatus;
    return switch (normalized) {
      'in_progress' => 0,
      'arrived' => 1,
      'on_the_way' => 2,
      'accepted' => 3,
      'confirmed' => 3,
      'pending' => 4,
      _ => 5,
    };
  }

  factory _JobRequest.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ??
        (data['updatedAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    final userLat = _numberOrNull(data['userLat'] ?? data['clientLat'] ?? data['lat']);
    final userLng = _numberOrNull(data['userLng'] ?? data['clientLng'] ?? data['lng']);

    return _JobRequest(
      id: doc.id,
      userId: (data['userId'] ?? data['clientId'] ?? '').toString(),
      serviceTitle: _serviceTitle(data),
      urgency: (data['urgency'] ?? 'Medium').toString(),
      status: (data['status'] ?? 'pending').toString(),
      estimatedPrice: data['estimatedPrice']?.toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      distanceKm: _numberOrNull(data['distance'])?.toDouble() ?? 0.0,
      userPoint: (userLat != null && userLng != null)
          ? ll.LatLng(userLat, userLng)
          : null,
    );
  }

  static String _serviceTitle(Map<String, dynamic> data) {
    final service = data['serviceName']?.toString().trim();
    if (service != null && service.isNotEmpty) return service;
    final description = data['problemDescription']?.toString().trim();
    if (description != null && description.isNotEmpty) {
      return description.length > 52
          ? '${description.substring(0, 52)}...'
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

enum _RequestSource { job, booking }

class _DashboardRequest {
  final _RequestSource source;
  final _JobRequest? job;
  final BookingModel? booking;

  const _DashboardRequest._({
    required this.source,
    this.job,
    this.booking,
  });

  factory _DashboardRequest.job(_JobRequest job) {
    return _DashboardRequest._(source: _RequestSource.job, job: job);
  }

  factory _DashboardRequest.booking(BookingModel booking) {
    return _DashboardRequest._(source: _RequestSource.booking, booking: booking);
  }

  bool get isJob => source == _RequestSource.job;

  bool get isStarted => isJob
      ? job!.normalizedStatus == 'in_progress'
      : _TechnicianPremiumDashboardState._statusOf(booking!.status) ==
            'in_progress';

  String get id => isJob ? job!.id : booking!.id;

  String get clientId => isJob ? job!.userId : booking!.clientId;

  String get title =>
      isJob ? job!.serviceTitle : booking!.serviceName;

  String get urgency => isJob ? job!.urgency : booking!.urgency;

  String get status => isJob ? job!.status : booking!.status;

  DateTime get updatedAt =>
      isJob ? (job!.updatedAt ?? job!.createdAt) : (booking!.updatedAt ?? booking!.createdAt);

  int get priorityWeight {
    return _TechnicianPremiumDashboardState._urgencyPriority(urgency);
  }

  int get workflowPriority {
    if (!isJob) {
      final statusWeight = switch (_TechnicianPremiumDashboardState._statusOf(booking!.status)) {
        'in_progress' => 0,
        'arrived' => 1,
        'on_the_way' => 2,
        'accepted' => 3,
        'confirmed' => 3,
        _ => 4,
      };
      return statusWeight;
    }
    return switch (job!.normalizedStatus) {
      'in_progress' => 0,
      'arrived' => 1,
      'on_the_way' => 2,
      'accepted' => 3,
      'confirmed' => 3,
      _ => 4,
    };
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.whiteBorder5),
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.neonAccent,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOnline, required this.isBusy});

  final bool isOnline;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: color,
              ),
            )
          else
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          const SizedBox(width: 7),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.whiteBorder5),
            ),
            child: Icon(icon, color: AppColors.onSurface, size: 21),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.neonAccent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Center(
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _ActiveRequestCard extends StatelessWidget {
  const _ActiveRequestCard({
    required this.request,
    required this.profileLocation,
    required this.clientFuture,
    required this.onNavigate,
    required this.onMessage,
    required this.onCall,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
  });

  final _DashboardRequest request;
  final ll.LatLng? profileLocation;
  final Future<DocumentSnapshot<Map<String, dynamic>>> clientFuture;
  final void Function(ll.LatLng? destination) onNavigate;
  final void Function(String clientName) onMessage;
  final void Function(String? phone) onCall;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: clientFuture,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final clientName = _TechnicianPremiumDashboardState._clientNameFromData(
              data,
            ) ??
            'Client';
        final phone = _TechnicianPremiumDashboardState._phoneFromData(data);
        final clientLocation =
            _TechnicianPremiumDashboardState._readPoint(data);
        final destination = request.isJob
            ? request.job!.userPoint ?? clientLocation
            : clientLocation;
        final distance = _TechnicianPremiumDashboardState._distanceText(
          technicianLocation: profileLocation,
          clientData: data,
          fallbackKm: request.isJob ? request.job!.distanceKm : null,
        );
        final timeText = _TechnicianPremiumDashboardState._requestTimeText(
          request,
        );
        final earningsText =
            _TechnicianPremiumDashboardState._requestEarningsText(request);

        final isEmergency = request.urgency.toLowerCase().trim() == 'emergency';
        return _PulsingEmergencyBorder(
          isEmergency: isEmergency,
          child: _SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    _PriorityPill(
                      label: _statusLabel(request.status),
                      color: _urgencyColor(request.urgency),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  request.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetaPill(
                      icon: Icons.schedule_rounded,
                      label: timeText,
                    ),
                    _MetaPill(
                      icon: Icons.route_rounded,
                      label: distance,
                    ),
                    _MetaPill(
                      icon: Icons.priority_high_rounded,
                      label: request.urgency,
                      color: _urgencyColor(request.urgency),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MetaPill(
                  icon: Icons.payments_rounded,
                  label: earningsText,
                  color: AppColors.neonAccent,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Navigate',
                        icon: Icons.navigation_rounded,
                        color: AppColors.neonAccent,
                        filled: true,
                        onTap: () => onNavigate(destination),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: 'Message',
                        icon: Icons.chat_bubble_rounded,
                        color: Colors.cyanAccent,
                        onTap: () => onMessage(clientName),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Call',
                        icon: Icons.call_rounded,
                        color: AppColors.success,
                        onTap: () => onCall(phone),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: primaryActionLabel,
                        icon: primaryActionIcon,
                        color: request.isStarted
                            ? AppColors.success
                            : AppColors.neonAccent,
                        filled: true,
                        onTap: onPrimaryAction,
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
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.profileLocation,
    required this.clientFuture,
    required this.onAccept,
    required this.onDecline,
  });

  final _DashboardRequest request;
  final ll.LatLng? profileLocation;
  final Future<DocumentSnapshot<Map<String, dynamic>>> clientFuture;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: clientFuture,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final clientName = _TechnicianPremiumDashboardState._clientNameFromData(
              data,
            ) ??
            'Client';
        final distance = _TechnicianPremiumDashboardState._distanceText(
          technicianLocation: profileLocation,
          clientData: data,
          fallbackKm: request.isJob ? request.job!.distanceKm : null,
        );
        final earnings = _TechnicianPremiumDashboardState._requestEarningsText(
          request,
        );

        final isEmergency = request.urgency.toLowerCase().trim() == 'emergency';
        return _PulsingEmergencyBorder(
          isEmergency: isEmergency,
          child: _SurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            clientName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PriorityPill(
                      label: request.urgency,
                      color: _urgencyColor(request.urgency),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      icon: Icons.route_rounded,
                      label: distance,
                    ),
                    _MetaPill(
                      icon: Icons.payments_rounded,
                      label: earnings,
                      color: AppColors.neonAccent,
                    ),
                    _MetaPill(
                      icon: Icons.access_time_rounded,
                      label: request.isJob
                          ? _TechnicianPremiumDashboardState._timeAgo(
                              request.updatedAt,
                            )
                          : _TechnicianPremiumDashboardState._timeLabel(
                              request.booking!,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Decline',
                        icon: Icons.close_rounded,
                        color: AppColors.onSurfaceVariant,
                        onTap: onDecline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: 'Accept',
                        icon: Icons.check_rounded,
                        color: AppColors.neonAccent,
                        filled: true,
                        onTap: onAccept,
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
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? AppColors.onPrimary : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? color : color.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.neonAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tint,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.42),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyEarningsChart extends StatelessWidget {
  const _WeeklyEarningsChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final safeValues = values.isEmpty ? List<double>.filled(7, 0) : values;
    final maxValue = safeValues
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity)
        .toDouble();
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final value = index < safeValues.length ? safeValues[index] : 0.0;
          final heightFactor = (value / maxValue).clamp(0.08, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: value > 0
                                ? AppColors.neonAccent
                                : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final color = _activityColor(activity.type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(
            _activityIcon(activity.type),
            color: color,
            size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      _timeAgoFromNow(activity.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.72),
                      ),
                    ),
                    if (activity.metadata != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        activity.metadata!,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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

  String _timeAgoFromNow(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _SheetMetric extends StatelessWidget {
  const _SheetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.neonAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeActionButton extends StatelessWidget {
  const _LargeActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      label: label,
      icon: icon,
      color: color,
      filled: true,
      onTap: onTap,
    );
  }
}

String _statusLabel(String status) {
  switch (_TechnicianPremiumDashboardState._statusOf(status)) {
    case 'accepted':
      return 'Accepted';
    case 'confirmed':
      return 'Confirmed';
    case 'on_the_way':
      return 'On the way';
    case 'arrived':
      return 'Arrived';
    case 'in_progress':
      return 'In progress';
    case 'completed':
      return 'Completed';
    case 'rejected':
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Pending';
  }
}

Color _urgencyColor(String urgency) {
  switch (urgency.toLowerCase().trim()) {
    case 'emergency':
      return AppColors.emergency;
    case 'high':
    case 'urgent':
      return AppColors.highPriority;
    case 'medium':
    case 'standard':
    case 'normal':
      return AppColors.mediumPriority;
    case 'low':
      return AppColors.lowPriority;
    default:
      return AppColors.lowPriority;
  }
}

class _PulsingEmergencyBorder extends StatefulWidget {
  const _PulsingEmergencyBorder({required this.child, required this.isEmergency});

  final Widget child;
  final bool isEmergency;

  @override
  State<_PulsingEmergencyBorder> createState() => _PulsingEmergencyBorderState();
}

class _PulsingEmergencyBorderState extends State<_PulsingEmergencyBorder>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    if (widget.isEmergency) {
      _initAnimation();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.5, end: 6.0).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _PulsingEmergencyBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEmergency && _controller == null) {
      _initAnimation();
    } else if (!widget.isEmergency && _controller != null) {
      _controller!.dispose();
      _controller = null;
      _animation = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEmergency) return widget.child;

    return AnimatedBuilder(
      animation: _animation!,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.emergency.withValues(alpha: 0.4),
                blurRadius: _animation!.value,
                spreadRadius: _animation!.value / 2,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.emergency.withValues(
                  alpha: 0.6 + (_animation!.value / 15),
                ),
                width: 2.0,
              ),
            ),
            child: widget.child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
