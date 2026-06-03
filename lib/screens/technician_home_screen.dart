import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/technician_location_service.dart';
import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';
import '../services/chat_service.dart';
import '../models/booking_model.dart';
import '../models/dashboard_metrics.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/live_status_card.dart';
import '../widgets/dashboard/job_card.dart';
import '../widgets/dashboard/analytics_card.dart';
import '../widgets/dashboard/ai_insights_card.dart';
import '../widgets/dashboard/activity_feed.dart';
import '../widgets/dashboard/quick_actions.dart';
import 'technician_premium_dashboard.dart';
import 'settings_screen.dart';
import 'messages_screen.dart';
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
          const SizedBox(height: 4),
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
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.startPublishing();
    _loadOnlineStatus();
  }

  @override
  void dispose() {
    _locationService.stopPublishing();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _locationService.startPublishing();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _locationService.stopPublishing();
        break;
    }
  }

  Future<void> _loadOnlineStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() => _isOnline = doc.data()?['isOnline'] ?? false);
    }
  }

  void _toggleOnlineStatus(bool value) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isOnline = value);
    FirebaseFirestore.instance.collection('users').doc(uid).update({'isOnline': value});
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
                  isOnline: _isOnline,
                ),
                const SizedBox(height: AppColors.space24),
                LiveStatusCard(
                  metrics: metrics,
                  onStatusToggle: _toggleOnlineStatus,
                ),
                const SizedBox(height: AppColors.space24),
                StreamBuilder<List<BookingModel>>(
                  stream: DashboardService.instance.getTodayBookings(uid),
                  builder: (context, jobsSnapshot) {
                    final jobs = jobsSnapshot.data ?? [];
                    return JobsSection(bookings: jobs);
                  },
                ),
                const SizedBox(height: AppColors.space24),
                AnalyticsSection(metrics: metrics),
                const SizedBox(height: AppColors.space24),
                StreamBuilder<List<AIInsight>>(
                  stream: DashboardService.instance.getAIInsights(uid),
                  builder: (context, insightsSnapshot) {
                    final insights = insightsSnapshot.data ?? [];
                    return AIInsightsSection(insights: insights);
                  },
                ),
                const SizedBox(height: AppColors.space24),
                StreamBuilder<List<ActivityItem>>(
                  stream: DashboardService.instance.getRecentActivity(uid),
                  builder: (context, activitySnapshot) {
                    final activities = activitySnapshot.data ?? [];
                    return ActivityFeed(activities: activities);
                  },
                ),
                const SizedBox(height: AppColors.space24),
                QuickActions(
                  isOnline: _isOnline,
                  onGoOnline: () => _toggleOnlineStatus(!_isOnline),
                  onViewNearbyJobs: () {},
                  onUpdateAvailability: () {},
                  onOpenMessages: () {},
                  onEmergencySupport: () {},
                ),
                const SizedBox(height: AppColors.space40),
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
  String _timeAgo(Timestamp? t) {
    if (t == null) return 'Just now';
    final diff = DateTime.now().difference(t.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showJobDialog(Map<String, dynamic> data) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Review Request', style: GoogleFonts.spaceGrotesk(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
      content: Text(data['problemDescription'] ?? 'No description.', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, height: 1.5)),
      actions: [
        TextButton(onPressed: () async { Navigator.pop(ctx); await FirebaseFirestore.instance.collection('jobs').doc(data['jobId']).update({'status': 'rejected'}); },
          child: Text('Reject', style: TextStyle(color: AppColors.error))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonAccent, foregroundColor: AppColors.onPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () async {
            Navigator.pop(ctx);
            final String jobId = data['jobId'];
            await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({'status': 'accepted'});
            try { await ChatService().sendMessage(receiverId: data['userId'], text: data['problemDescription']); } catch (_) {}
            if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: data['userId'], otherUserName: 'Client', otherUserRole: 'client')));
          },
          child: const Text('Accept'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nearby Requests', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 4),
        Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('Searching for jobs', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
        ]),
      ])),
      const SizedBox(height: 16),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('jobs').where('technicianId', isEqualTo: uid).where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: AppColors.neonAccent));
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 48,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
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

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final desc = data['problemDescription'] as String? ?? 'Needs repair';
              final dist = data['distance'] as double? ?? 0.0;
              final price = data['estimatedPrice'] as String?;
              final urgency = data['urgency'] as String? ?? 'Standard';

              return GestureDetector(
                onTap: () => _showJobDialog(data),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface, height: 1.4))),
                      const SizedBox(width: 8),
                      Text(_timeAgo(data['createdAt'] as Timestamp?), style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      // Distance
                      Icon(Icons.location_on_outlined, size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${dist.toStringAsFixed(1)} km', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      const SizedBox(width: 16),
                      // Urgency
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: urgency == 'Emergency' ? AppColors.error.withValues(alpha: 0.1) : urgency == 'Urgent' ? Colors.orange.withValues(alpha: 0.1) : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4)),
                        child: Text(urgency, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                          color: urgency == 'Emergency' ? AppColors.error : urgency == 'Urgent' ? Colors.orange : AppColors.onSurfaceVariant)),
                      ),
                      if (price != null && price.isNotEmpty) ...[
                        const Spacer(),
                        Text('\$$price', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.neonAccent)),
                      ],
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      )),
    ]));
  }
}

class TechnicianProfileScreen extends StatelessWidget {
  const TechnicianProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('My Profile', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      const SizedBox(height: 24),
      Center(child: Column(children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
          child: Icon(Icons.person_rounded, size: 40, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 12),
        Text('Professional Technician', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
      ])),
    ])));
  }
}
