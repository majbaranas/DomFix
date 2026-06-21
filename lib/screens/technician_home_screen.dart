import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import '../services/technician_location_service.dart';
import '../services/dashboard_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../services/chat_service.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../models/dashboard_metrics.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/live_status_card.dart';
import '../widgets/dashboard/job_card.dart';
import '../widgets/dashboard/analytics_card.dart';
import '../widgets/dashboard/ai_insights_card.dart';
import '../widgets/dashboard/activity_feed.dart';
import '../widgets/dashboard/quick_actions.dart';
import '../widgets/job_completion_dialog.dart';
import 'technician_premium_dashboard.dart';
import 'settings_screen.dart';
import 'messages_screen.dart';
import 'technician_review_screen.dart';
import 'booking_details_screen.dart';
import 'chat_screen.dart';

class TechnicianHomeScreen extends StatefulWidget {
  const TechnicianHomeScreen({super.key});
  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() { super.initState(); _pageController = PageController(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { _pageController.dispose(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  void _onPageChanged(int index) { if (_currentIndex != index) { setState(() => _currentIndex = index); HapticFeedback.lightImpact(); } }
  void _onNavItemTapped(int index) { if (_currentIndex != index) { HapticFeedback.lightImpact(); _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } }

  List<Widget> get _screens => [
    TechnicianPremiumDashboard(onNavigateTab: _onNavItemTapped),
    const MessagesScreen(),
    const TechnicianJobsScreen(),
    const TechnicianProfileScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(controller: _pageController, onPageChanged: _onPageChanged, physics: const BouncingScrollPhysics(), children: _screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.divider))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _navItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard', 0),
            _navItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Messages', 1),
            _navItem(Icons.work_outline_rounded, Icons.work_rounded, 'Jobs', 2),
            _navItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', 3),
            _navItem(Icons.settings_outlined, Icons.settings_rounded, 'Settings', 4),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final sel = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(sel ? activeIcon : icon, color: sel ? AppColors.neonAccent : AppColors.onSurfaceVariant.withValues(alpha: 0.5), size: 22),
          SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.neonAccent : AppColors.onSurfaceVariant.withValues(alpha: 0.5))),
        ]),
      ),
    );
  }
}

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});
  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> with WidgetsBindingObserver {
  final _locationService = TechnicianLocationService();
  String _liveStatus = 'offline';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.startLocationTracking();
    _loadOnlineStatus();
  }

  @override
  void dispose() {
    _locationService.stopLocationTracking();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _locationService.startLocationTracking();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _locationService.stopLocationTracking();
        break;
    }
  }

  Future<void> _loadOnlineStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() => _liveStatus = doc.data()?['liveStatus'] ?? 'offline');
    }
  }

  void _toggleOnlineStatus(bool value) {
    final status = value ? 'online' : 'offline';
    setState(() => _liveStatus = status);
    _locationService.updateLiveStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return SafeArea(
      child: StreamBuilder(
        stream: DashboardService.instance.getDashboardMetrics(uid),
        initialData: DashboardMetrics.empty(),
        builder: (context, metricsSnapshot) {
          final metrics = metricsSnapshot.data ?? DashboardMetrics.empty();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardHeader(
                  technicianId: uid,
                  performanceBadge: metrics.performanceBadge,
                  isOnline: _liveStatus != 'offline',
                ),
                const SizedBox(height: AppSpacing.space24),
                LiveStatusCard(
                  metrics: metrics,
                  onStatusToggle: _toggleOnlineStatus,
                ),
                const SizedBox(height: AppSpacing.space24),
                StreamBuilder<List<BookingModel>>(
                  stream: DashboardService.instance.getTodayBookings(uid),
                  builder: (context, jobsSnapshot) {
                    final jobs = jobsSnapshot.data ?? [];
                    return JobsSection(bookings: jobs);
                  },
                ),
                const SizedBox(height: AppSpacing.space24),
                AnalyticsSection(metrics: metrics),
                const SizedBox(height: AppSpacing.space24),
                StreamBuilder<List<AIInsight>>(
                  stream: DashboardService.instance.getAIInsights(uid),
                  builder: (context, insightsSnapshot) {
                    final insights = insightsSnapshot.data ?? [];
                    return AIInsightsSection(insights: insights);
                  },
                ),
                const SizedBox(height: AppSpacing.space24),
                StreamBuilder<List<ActivityItem>>(
                  stream: DashboardService.instance.getRecentActivity(uid),
                  builder: (context, activitySnapshot) {
                    final activities = activitySnapshot.data ?? [];
                    return ActivityFeed(activities: activities);
                  },
                ),
                const SizedBox(height: AppSpacing.space24),
                QuickActions(
                  isOnline: _liveStatus != 'offline',
                  onGoOnline: () => _toggleOnlineStatus(_liveStatus == 'offline'),
                  onViewNearbyJobs: () {},
                  onUpdateAvailability: () {},
                  onOpenMessages: () {},
                  onEmergencySupport: () {},
                ),
                const SizedBox(height: AppSpacing.space40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TechnicianJobsScreen extends StatefulWidget {
  const TechnicianJobsScreen({super.key});
  @override
  State<TechnicianJobsScreen> createState() => _TechnicianJobsScreenState();
}

class _TechnicianJobsScreenState extends State<TechnicianJobsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _clientFutureCache = {};

  Future<DocumentSnapshot<Map<String, dynamic>>> _clientDoc(String userId) {
    return _clientFutureCache.putIfAbsent(
      userId,
      () => _firestore.collection('users').doc(userId).get(),
    );
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _statusLabel(String status) {
    switch (_normalizeStatus(status)) {
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
      case 'inspection_requested':
        return 'Inspection Req.';
      case 'inspection_accepted':
        return 'Inspection Appr.';
      case 'inspection_completed':
        return 'Pending Quote';
      default:
        return 'Pending';
    }
  }

  int _urgencyPriority(String urgency) {
    switch (urgency.toLowerCase().trim()) {
      case 'emergency':
        return 0;
      case 'high':
      case 'urgent':
        return 1;
      case 'medium':
      case 'normal':
      case 'standard':
        return 2;
      case 'low':
        return 3;
      default:
        return 2;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase().trim()) {
      case 'emergency':
        return AppColors.emergency;
      case 'high':
      case 'urgent':
        return Colors.orangeAccent;
      case 'medium':
      case 'standard':
      case 'normal':
        return AppColors.neonAccent;
      case 'low':
        return Colors.cyanAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  String _normalizeStatus(String status) {
    final lower = status.toLowerCase().trim();
    if (lower == 'in progress') return 'in_progress';
    if (lower == 'on the way') return 'on_the_way';
    if (lower == 'pending_quote') return 'pending_quote';
    if (lower == 'quote_sent') return 'quote_sent';
    if (lower == 'inspection_requested') return 'inspection_requested';
    if (lower == 'inspection_accepted') return 'inspection_accepted';
    if (lower == 'inspection_completed') return 'inspection_completed';
    return lower;
  }

  bool _isPending(_TechnicianQueueItem item) {
    final normalized = _normalizeStatus(item.status);
    return normalized == 'pending' ||
        normalized == 'pending_quote' ||
        normalized == 'inspection_requested' ||
        normalized == 'inspection_completed';
  }

  bool _isActive(_TechnicianQueueItem item) {
    final normalized = _normalizeStatus(item.status);
    if (item.isBooking) {
      return normalized == 'accepted' ||
          normalized == 'confirmed' ||
          normalized == 'on_the_way' ||
          normalized == 'arrived' ||
          normalized == 'in_progress' ||
          normalized == 'inspection_accepted';
    }
    return normalized == 'accepted' ||
        normalized == 'on_the_way' ||
        normalized == 'arrived' ||
        normalized == 'in_progress' ||
        normalized == 'confirmed';
  }

  int _compareRequests(_TechnicianQueueItem a, _TechnicianQueueItem b) {
    final urgencyA = _urgencyPriority(a.urgency);
    final urgencyB = _urgencyPriority(b.urgency);
    if (urgencyA != urgencyB) return urgencyA.compareTo(urgencyB);

    final statusA = a.workflowPriority;
    final statusB = b.workflowPriority;
    if (statusA != statusB) return statusA.compareTo(statusB);

    return b.updatedAt.compareTo(a.updatedAt);
  }

  Future<void> _acceptRequest(_TechnicianQueueItem item) async {
    if (item.isBooking) {
      await _updateBookingStatus(item.booking!, 'accepted');
    } else {
      await _updateJobStatus(item, 'accepted');
    }
  }

  Future<void> _declineRequest(_TechnicianQueueItem item) async {
    if (item.isBooking) {
      await _updateBookingStatus(item.booking!, 'rejected');
    } else {
      await _updateJobStatus(item, 'rejected');
    }
  }

  Future<void> _advanceRequest(_TechnicianQueueItem item) async {
    if (item.isBooking) {
      final current = _normalizeStatus(item.status);
      
      // If it's a pending quote or inspection completed, navigate to review screen
      if (current == 'pending_quote' || current == 'inspection_completed') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TechnicianReviewScreen(
              booking: item.booking!,
              distanceKm: item.distanceKm,
            ),
          ),
        );
        return;
      }

      final next = switch (current) {
        'pending' => 'accepted',
        'accepted' || 'confirmed' || 'inspection_accepted' => 'on_the_way',
        'on_the_way' => 'arrived',
        'arrived' => item.booking?.isInspectionFlow == true ? 'inspection_completed' : 'in_progress',
        'in_progress' => 'completed_pending_confirmation', // New completion flow
        _ => current,
      };
      if (next == current) return;
      
      // Show completion dialog before marking as completed
      if (next == 'completed_pending_confirmation') {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => JobCompletionDialog(
            booking: item.booking!,
            onComplete: () async {
              await _updateBookingStatus(item.booking!, 'completed_pending_confirmation');
            },
          ),
        );
      } else if (next == 'inspection_completed') {
        await BookingService.instance.completeInspection(
          bookingId: item.booking!.id,
          clientId: item.clientId,
          technicianId: FirebaseAuth.instance.currentUser!.uid,
          technicianName: 'Technician', // Will use existing name
          serviceName: item.serviceTitle,
        );
      } else {
        await _updateBookingStatus(item.booking!, next);
      }
    } else {
      final current = _normalizeStatus(item.status);
      final next = switch (current) {
        'pending' => 'accepted',
        'accepted' => 'in_progress',
        'in_progress' => 'completed',
        _ => current,
      };
      if (next == current) return;
      await _updateJobStatus(item, next);
    }
  }

  Future<void> _updateJobStatus(_TechnicianQueueItem item, String status) async {
    final normalized = _normalizeStatus(status);
    await _firestore.collection('jobs').doc(item.id).update({
      'status': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _updateLiveStatusForJob(normalized);

    final technicianId = FirebaseAuth.instance.currentUser?.uid;
    if (technicianId != null && technicianId.isNotEmpty) {
      final chatId = ChatService.generateChatId(item.clientId, technicianId);
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [item.clientId, technicianId],
        'bookingStatus': normalized,
        'accessLevel': normalized == 'rejected' ? 'limited' : 'full',
        'canShareImages': normalized != 'rejected',
        'canUseVoiceNotes': normalized != 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _sendQueueNotification(
      recipientId: item.clientId,
      senderId: FirebaseAuth.instance.currentUser?.uid ?? item.clientId,
      type: 'job_$normalized',
      title: _statusLabel(normalized),
      body: item.serviceTitle,
      jobId: item.id,
      status: normalized,
      serviceName: item.serviceTitle,
      urgency: item.urgency,
    );
  }

  Future<void> _updateBookingStatus(BookingModel booking, String status) async {
    final normalized = _normalizeStatus(status);
    await _firestore.collection('bookings').doc(booking.id).update({
      'status': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _updateLiveStatusForJob(normalized);

    await _firestore.collection('chats').doc(booking.chatId).set({
      'participants': [booking.clientId, booking.technicianId],
      'bookingId': booking.id,
      'bookingStatus': normalized,
      'accessLevel': normalized == 'rejected' ? 'limited' : 'full',
      'canShareImages': normalized != 'rejected',
      'canUseVoiceNotes': normalized != 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _sendQueueNotification(
      recipientId: booking.clientId,
      senderId: FirebaseAuth.instance.currentUser?.uid ?? booking.technicianId,
      type: 'booking_$normalized',
      title: _statusLabel(normalized),
      body: booking.serviceName,
      bookingId: booking.id,
      chatId: booking.chatId,
      status: normalized,
      serviceName: booking.serviceName,
      urgency: booking.urgency,
      metadata: {
        'scheduledAt': booking.scheduledAt.toIso8601String(),
        'scheduledTimeLabel': booking.scheduledTimeLabel,
      },
    );
  }

  Future<void> _sendQueueNotification({
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
      debugPrint('[TechnicianJobsScreen] Notification write failed: $e');
    }
  }

  void _updateLiveStatusForJob(String normalizedStatus) {
    if (normalizedStatus == 'accepted' || normalizedStatus == 'confirmed') {
      TechnicianLocationService().updateLiveStatus('busy');
    } else if (normalizedStatus == 'on_the_way' || 
               normalizedStatus == 'arrived' || 
               normalizedStatus == 'in_progress') {
      TechnicianLocationService().updateLiveStatus('on_job');
    } else if (normalizedStatus == 'completed' || 
               normalizedStatus == 'rejected' || 
               normalizedStatus == 'cancelled') {
      TechnicianLocationService().updateLiveStatus('online');
    }
  }

  void _openChat(String clientId, String clientName) {
    if (clientId.isEmpty) return;
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

  List<_TechnicianQueueItem> _mergeRequests(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingDocs,
    LatLng? techLocation,
  ) {
    final items = <_TechnicianQueueItem>[
      ...jobDocs.map(_TechnicianQueueItem.fromJobDoc),
      ...bookingDocs.map((doc) => _TechnicianQueueItem.fromBooking(
            BookingModel.fromFirestore(doc),
            techLocation,
          )),
    ];
    items.sort(_compareRequests);
    return items;
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<_TechnicianQueueItem> items,
    required bool emptyIsActive,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
              SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                emptyIsActive ? 'No active jobs yet.' : 'No requests right now.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _QueueCard(
                item: item,
                clientFuture: _clientDoc(item.clientId),
                timeAgo: _timeAgo(item.updatedAt),
                statusLabel: _statusLabel(item.status),
                urgencyLabel: item.urgency,
                urgencyColor: _urgencyColor(item.urgency),
                onAccept: () => _acceptRequest(item),
                onDecline: () => _declineRequest(item),
                onPrimaryAction: () => _advanceRequest(item),
                primaryActionLabel: _primaryActionLabel(item),
                primaryActionIcon: _primaryActionIcon(item),
                onMessage: (name) => _openChat(item.clientId, name),
              );
            },
          ),
      ],
    );
  }

  String _primaryActionLabel(_TechnicianQueueItem item) {
    final status = _normalizeStatus(item.status);
    if (!item.isBooking) {
      switch (status) {
        case 'pending':
          return 'Accept';
        case 'accepted':
          return 'Start job';
        case 'in_progress':
          return 'Complete';
        default:
          return 'Update';
      }
    }

    switch (status) {
      case 'pending':
        return 'Accept';
      case 'accepted':
      case 'confirmed':
      case 'inspection_accepted':
        return 'On the way';
      case 'on_the_way':
        return 'Arrived';
      case 'arrived':
        return item.booking?.isInspectionFlow == true ? 'Finish Inspect' : 'Start job';
      case 'in_progress':
        return 'Complete';
      default:
        return 'Update';
    }
  }

  IconData _primaryActionIcon(_TechnicianQueueItem item) {
    final status = _normalizeStatus(item.status);
    if (!item.isBooking) {
      switch (status) {
        case 'pending':
          return Icons.check_rounded;
        case 'accepted':
          return Icons.play_arrow_rounded;
        case 'in_progress':
          return Icons.check_circle_rounded;
        default:
          return Icons.sync_rounded;
      }
    }

    switch (status) {
      case 'pending':
        return Icons.check_rounded;
      case 'accepted':
      case 'confirmed':
      case 'inspection_accepted':
        return Icons.navigation_rounded;
      case 'on_the_way':
        return Icons.location_on_rounded;
      case 'arrived':
        return item.booking?.isInspectionFlow == true ? Icons.fact_check_rounded : Icons.play_arrow_rounded;
      case 'in_progress':
        return Icons.check_circle_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jobs',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Live requests update automatically. Emergency jobs appear first.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('technician_locations').doc(uid).snapshots(),
              builder: (context, techLocSnapshot) {
                LatLng? techLocation;
                final techData = techLocSnapshot.data?.data();
                if (techData != null) {
                  final lat = (techData['lat'] as num?)?.toDouble() ?? (techData['location']?['lat'] as num?)?.toDouble();
                  final lng = (techData['lng'] as num?)?.toDouble() ?? (techData['location']?['lng'] as num?)?.toDouble();
                  if (lat != null && lng != null) {
                    techLocation = LatLng(lat, lng);
                  }
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore
                      .collection('jobs')
                      .where('technicianId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, jobsSnapshot) {
                    final jobDocs = jobsSnapshot.data?.docs ?? const [];
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestore
                          .collection('bookings')
                          .where('technicianId', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, bookingsSnapshot) {
                        final bookingDocs = bookingsSnapshot.data?.docs ?? const [];
                        final items = _mergeRequests(jobDocs, bookingDocs, techLocation);
                        final pending = items.where(_isPending).toList();
                        final active = items.where(_isActive).toList();
                        final allEmpty = pending.isEmpty && active.isEmpty;

                        if (jobsSnapshot.connectionState == ConnectionState.waiting &&
                            bookingsSnapshot.connectionState ==
                                ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppColors.neonAccent,
                        ),
                      );
                    }

                    if (allEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 48,
                              color: AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.2),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No requests yet',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        _buildSection(
                          title: 'Active Jobs',
                          subtitle: 'Work that needs attention right now',
                          items: active,
                          emptyIsActive: true,
                        ),
                        const SizedBox(height: 18),
                        _buildSection(
                          title: 'New Requests',
                          subtitle: 'Accept or decline with one tap',
                          items: pending,
                          emptyIsActive: false,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    ],
  ),
);
  }
}

class _TechnicianQueueItem {
  final String id;
  final bool isBooking;
  final BookingModel? booking;
  final Map<String, dynamic>? jobData;
  final String clientId;
  final String serviceTitle;
  final String urgency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double distanceKm;
  final String? estimatedPrice;
  final String description;
  final List<String> imageUrls;

  const _TechnicianQueueItem._({
    required this.id,
    required this.isBooking,
    required this.clientId,
    required this.serviceTitle,
    required this.urgency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.distanceKm,
    required this.estimatedPrice,
    required this.description,
    required this.imageUrls,
    this.booking,
    this.jobData,
  });

  factory _TechnicianQueueItem.fromJobDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ??
        (data['updatedAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? createdAt;
    return _TechnicianQueueItem._(
      id: doc.id,
      isBooking: false,
      jobData: data,
      clientId: (data['userId'] ?? data['clientId'] ?? '').toString(),
      serviceTitle: (data['serviceName'] ??
              data['problemDescription'] ??
              'Service request')
          .toString(),
      urgency: (data['urgency'] ?? 'Medium').toString(),
      status: (data['status'] ?? 'pending').toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      distanceKm: (data['distance'] as num?)?.toDouble() ?? 0.0,
      estimatedPrice: data['estimatedPrice']?.toString(),
      description: data['problemDescription']?.toString() ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? const []),
    );
  }

  factory _TechnicianQueueItem.fromBooking(BookingModel booking, LatLng? techLocation) {
    double distance = 0.0;
    if (techLocation != null && booking.clientLat != null && booking.clientLng != null) {
      distance = TechnicianLocationService.distanceKmPublic(
        techLocation,
        LatLng(booking.clientLat!, booking.clientLng!),
      );
    }

    return _TechnicianQueueItem._(
      id: booking.id,
      isBooking: true,
      booking: booking,
      clientId: booking.clientId,
      serviceTitle: booking.serviceName,
      urgency: booking.urgency,
      status: booking.status,
      createdAt: booking.createdAt,
      updatedAt: booking.updatedAt ?? booking.createdAt,
      distanceKm: distance,
      estimatedPrice: booking.technicianFee > 0
          ? booking.technicianFee.toStringAsFixed(0)
          : null,
      description: booking.description,
      imageUrls: booking.imageUrls,
    );
  }

  int get urgencyPriority {
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

  int get workflowPriority {
    final normalized = status.toLowerCase().trim();
    if (isBooking) {
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

    return switch (normalized) {
      'in_progress' => 0,
      'accepted' => 1,
      'pending' => 4,
      _ => 5,
    };
  }

  bool get isPending {
    final normalized = status.toLowerCase().trim();
    return normalized == 'pending' ||
        normalized == 'pending_quote' ||
        normalized == 'inspection_requested' ||
        normalized == 'inspection_completed';
  }

  bool get isActive {
    final normalized = status.toLowerCase().trim();
    if (isBooking) {
      return normalized == 'accepted' ||
          normalized == 'quote_sent' ||
          normalized == 'confirmed' ||
          normalized == 'on_the_way' ||
          normalized == 'arrived' ||
          normalized == 'in_progress' ||
          normalized == 'inspection_accepted';
    }
    return normalized == 'accepted' || normalized == 'in_progress';
  }

  int get etaMinutes {
    if (distanceKm <= 0) return 0;
    return ((distanceKm / 30.0) * 60).round();
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.item,
    required this.clientFuture,
    required this.timeAgo,
    required this.statusLabel,
    required this.urgencyLabel,
    required this.urgencyColor,
    required this.onAccept,
    required this.onDecline,
    required this.onPrimaryAction,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onMessage,
  });

  final _TechnicianQueueItem item;
  final Future<DocumentSnapshot<Map<String, dynamic>>> clientFuture;
  final String timeAgo;
  final String statusLabel;
  final String urgencyLabel;
  final Color urgencyColor;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onPrimaryAction;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final void Function(String clientName) onMessage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: clientFuture,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final clientName = (data?['fullName'] ?? data?['name'] ?? 'Client')
            .toString();
        final phone = (data?['phone'] ?? data?['phoneNumber'] ?? '')
            .toString();
        final priceText = item.isBooking
            ? (item.estimatedPrice != null
                ? '${item.estimatedPrice} MAD'
                : 'Estimate pending')
            : (item.estimatedPrice?.isNotEmpty == true
                ? item.estimatedPrice!
                : 'Estimate pending');
        final secondaryText = item.isBooking
            ? (item.booking?.scheduledTimeLabel ?? 'Scheduled')
            : (item.distanceKm > 0
                ? '${item.distanceKm.toStringAsFixed(1)} km'
                : 'Nearby');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
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
                          item.serviceTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          clientName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      urgencyLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: urgencyColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(icon: Icons.schedule_rounded, label: timeAgo),
                  _Pill(icon: Icons.circle_outlined, label: statusLabel),
                  if (item.distanceKm > 0)
                    _Pill(icon: Icons.location_on_rounded, label: '${item.distanceKm.toStringAsFixed(1)} km'),
                  if (item.etaMinutes > 0)
                    _Pill(icon: Icons.directions_car_rounded, label: '${item.etaMinutes} min'),
                  if (item.imageUrls.isNotEmpty)
                    _Pill(icon: Icons.photo_camera_rounded, label: '${item.imageUrls.length} photos'),
                  if (!item.isPending && priceText != 'Estimate pending')
                    _Pill(icon: Icons.payments_rounded, label: priceText),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Message',
                      icon: Icons.chat_bubble_rounded,
                      color: Colors.cyanAccent,
                      onTap: () => onMessage(clientName),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (item.isPending) ...[
                    Expanded(
                      child: _ActionButton(
                        label: 'Decline',
                        icon: Icons.close_rounded,
                        color: AppColors.error,
                        onTap: onDecline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: (item.status.toLowerCase().trim() == 'pending_quote' || item.status.toLowerCase().trim() == 'inspection_completed') ? 'Review Request' : 'Accept',
                        icon: (item.status.toLowerCase().trim() == 'pending_quote' || item.status.toLowerCase().trim() == 'inspection_completed') ? Icons.visibility_rounded : Icons.check_rounded,
                        color: AppColors.neonAccent,
                        filled: true,
                        onTap: (item.status.toLowerCase().trim() == 'pending_quote' || item.status.toLowerCase().trim() == 'inspection_completed') ? onPrimaryAction : onAccept,
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: _ActionButton(
                        label: primaryActionLabel,
                        icon: primaryActionIcon,
                        color: AppColors.neonAccent,
                        filled: true,
                        onTap: onPrimaryAction,
                      ),
                    ),
                  ],
                ],
              ),
              if (phone.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  phone,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? color : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? AppColors.onPrimary : color,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled ? AppColors.onPrimary : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TechnicianProfileScreen extends StatelessWidget {
  const TechnicianProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('My Profile', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      SizedBox(height: 24),
      Center(child: Column(children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
          child: Icon(Icons.person_rounded, size: 40, color: AppColors.onSurfaceVariant)),
        SizedBox(height: 12),
        Text('Professional Technician', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
      ])),
    ])));
  }
}
