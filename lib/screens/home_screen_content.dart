import 'dart:math' show sin, pi;
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../models/user_device.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/notification_panel.dart';
import '../widgets/scroll_reveal.dart';
import 'ai_chat_screen.dart';
import 'chat_screen.dart';
import 'main_layout.dart';
import 'nearby_technicians_map_screen.dart';
import 'technician_profile_screen.dart';

/// HomeScreenContent — the client home tab.
///
/// Everything here is wired to live data and real navigation:
///  • Header greeting + avatar from FirebaseAuth, live unread badge from chats.
///  • Search bar jumps to the Find Pro tab.
///  • My Devices section streams from `users/{uid}/devices`.
///  • Top Technicians stream from Firestore (`users` where role == technician).
///  • Recent Conversations stream from the user's chats.
class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  late final AnimationController _floatController;
  late final ScrollController _scrollController;

  String _userName = 'there';
  String? _userPhotoUrl;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _scrollController = ScrollController();
    _loadUserData();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final user = _auth.currentUser;
    if (user == null) return;
    final name = user.displayName?.trim();
    final fallback = user.email?.split('@').first;
    setState(() {
      _userName = (name != null && name.isNotEmpty)
          ? name
          : (fallback != null && fallback.isNotEmpty ? fallback : 'there');
      _userPhotoUrl = user.photoURL;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ─── Navigation helpers ───────────────────────────────────
  void _goToTab(int index) => MainLayoutScope.maybeOf(context)?.selectTab(index);

  void _openAI() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AIChatScreen()),
      );

  void _openMap() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NearbyTechniciansMapScreen()),
      );

  void _openTechnicianProfile(String id, String name) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TechnicianProfileScreen(technicianId: id, initialName: name),
        ),
      );

  void _openChat(String id, String name) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: id,
            otherUserName: name,
            otherUserRole: 'technician',
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _FloatingAIButton(
        controller: _floatController,
        onTap: _openAI,
      ),
      body: Stack(
        children: [
          // Parallax ambient glow: moves upward at 0.3× scroll speed,
          // creating a sense of depth as the user scrolls down.
          AnimatedBuilder(
            animation: _scrollController,
            builder: (_, child) {
              final dy = _scrollController.hasClients
                  ? -(_scrollController.offset * 0.30).clamp(0.0, 120.0)
                  : 0.0;
              return Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: child,
                ),
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 1.6,
                  colors: [Color(0x18CDF200), Color(0x00000000)],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            color: AppColors.neonAccent,
            backgroundColor: AppColors.surface,
            onRefresh: () async {
              _loadUserData();
              await Future<void>.delayed(const Duration(milliseconds: 600));
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Header: immediate — always visible on load.
                SliverToBoxAdapter(child: _buildHeader()),
                // Remaining sections cascade in with staggered delays.
                SliverToBoxAdapter(
                  child: RevealItem(
                    delay: const Duration(milliseconds: 60),
                    child: _buildSearchBar(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealItem(
                    delay: const Duration(milliseconds: 130),
                    child: _buildMyDevices(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealItem(
                    delay: const Duration(milliseconds: 210),
                    child: _buildMapBanner(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealItem(
                    delay: const Duration(milliseconds: 290),
                    child: _buildTechniciansSection(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealItem(
                    delay: const Duration(milliseconds: 370),
                    child: _buildRecentChatsSection(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.of(context).padding.top + 16, 24, 16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              // Avatar → Settings tab.
              GestureDetector(
                onTap: () => _goToTab(4),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    color: AppColors.surfaceContainerHigh,
                  ),
                  child: ClipOval(
                    child: (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty)
                        ? Image.network(
                            _userPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatarFallback(),
                          )
                        : _avatarFallback(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()},',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Notification / messages bell with live unread dot.
              _buildNotificationBell(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : '?';
    return Container(
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.neonAccent,
        ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    return GestureDetector(
      onTap: () => showNotificationPanel(context),
      child: StreamBuilder<int>(
        stream: NotificationService.instance.watchUnreadCount(),
        builder: (context, snapshot) {
          final unread = snapshot.data ?? 0;
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  unread > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_outlined,
                  size: 20,
                  color: unread > 0 ? AppColors.neonAccent : AppColors.onSurface,
                ),
                if (unread > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.neonAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.background,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── SEARCH ───────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: GestureDetector(
        onTap: () => _goToTab(2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  size: 20,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(width: 12),
              Text(
                'Search for a service or pro…',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── MY DEVICES (live, from Control tab's Firestore collection) ──
  Widget _buildMyDevices() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final devicesRef = _fs
        .collection('users')
        .doc(uid)
        .collection('devices')
        .orderBy('createdAt', descending: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('My Devices'),
              GestureDetector(
                onTap: () => _goToTab(3),
                child: Text(
                  'Manage',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neonAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: devicesRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _deviceLoadingRow();
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => _goToTab(3),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.neonAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.add_rounded,
                              color: AppColors.neonAccent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No devices yet',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to add your home devices',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.4)),
                      ],
                    ),
                  ),
                ),
              );
            }

            final devices = docs.map(UserDevice.fromDoc).toList();

            return HorizontalFadeHint(
              color: AppColors.background,
              child: SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: devices.length + 1, // +1 for "Add" button
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  // Last item → "Add" shortcut
                  if (i == devices.length) {
                    return GestureDetector(
                      onTap: () => _goToTab(3),
                      child: Container(
                        width: 72,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.neonAccent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.neonAccent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.add_rounded,
                                  size: 20, color: AppColors.neonAccent),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neonAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final d = devices[i];
                  final isOn = d.status == DeviceStatus.online;
                  return GestureDetector(
                    onTap: () => _goToTab(3),
                    child: Container(
                      width: 84,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isOn
                              ? AppColors.neonAccent.withValues(alpha: 0.25)
                              : AppColors.divider,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                d.type.icon,
                                size: 22,
                                color: isOn
                                    ? AppColors.neonAccent
                                    : AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOn
                                      ? AppColors.success
                                      : AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.3),
                                  boxShadow: isOn
                                      ? [
                                          BoxShadow(
                                            color: AppColors.success
                                                .withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              d.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),   // SizedBox
          );     // HorizontalFadeHint
          },
        ),
      ],
    );
  }

  Widget _deviceLoadingRow() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 84,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
        ),
      ),
    );
  }

  // ─── MAP BANNER ───────────────────────────────────────────
  Widget _buildMapBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: GestureDetector(
        onTap: _openMap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neonAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.map_rounded, color: AppColors.neonAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live map',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See technicians available near you',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TOP TECHNICIANS (live) ───────────────────────────────
  Widget _buildTechniciansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('Top Technicians'),
              GestureDetector(
                onTap: () => _goToTab(2),
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neonAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'technician')
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _techLoadingRow();
            }
            if (snapshot.hasError) {
              return _inlineMessage('Could not load technicians');
            }

            final currentUid = _auth.currentUser?.uid;
            final docs = (snapshot.data?.docs ?? [])
                .where((d) => d.id != currentUid)
                .toList();

            // Highest-rated first (sorted client-side to avoid an index).
            docs.sort((a, b) {
              final ra = _asDouble((a.data() as Map<String, dynamic>)['rating']);
              final rb = _asDouble((b.data() as Map<String, dynamic>)['rating']);
              return rb.compareTo(ra);
            });

            if (docs.isEmpty) {
              return _inlineMessage('No technicians available yet');
            }

            return HorizontalFadeHint(
              color: AppColors.background,
              child: SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return RevealItem(
                    delay: Duration(milliseconds: i * 80),
                    child: _TechnicianCard(
                    id: docs[i].id,
                    name: _techName(data),
                    speciality: (data['speciality'] as String?)?.trim().isNotEmpty == true
                        ? data['speciality'] as String
                        : 'Specialist',
                    rating: _asDouble(data['rating']),
                    photoUrl: (data['profileImage'] ?? data['photoUrl']) as String?,
                    isOnline: data['isOnline'] == true,
                    onProfile: () => _openTechnicianProfile(docs[i].id, _techName(data)),
                    onChat: () => _openChat(docs[i].id, _techName(data)),
                    ),   // _TechnicianCard
                  );     // RevealItem
                },
              ),           // ListView.separated
              ),           // SizedBox
            );             // HorizontalFadeHint
          },
        ),
      ],
    );
  }

  // ─── RECENT CONVERSATIONS (live) ──────────────────────────
  Widget _buildRecentChatsSection() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('Recent Conversations'),
              GestureDetector(
                onTap: () => _goToTab(1),
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neonAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: _chatService.getUserChats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _inlineMessage('Loading…');
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 36,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),
                      Text(
                        'No conversations yet',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Find a pro to get started',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final visible = docs.take(3).toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  for (final doc in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RecentChatTile(
                        chatData: doc.data() as Map<String, dynamic>,
                        currentUserId: currentUid,
                        chatService: _chatService,
                        onTap: (id, name) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              otherUserId: id,
                              otherUserName: name,
                              otherUserRole: 'user',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Shared small pieces ──────────────────────────────────
  Widget _techLoadingRow() {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Container(
          width: 220,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
        ),
      ),
    );
  }

  Widget _inlineMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static String _techName(Map<String, dynamic> data) {
    final full = (data['fullName'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final name = (data['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = (data['email'] as String?)?.split('@').first;
    return (email != null && email.isNotEmpty) ? email : 'Technician';
  }
}

// ─── Section title ──────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
        letterSpacing: -0.4,
      ),
    );
  }
}

// ─── Technician card ────────────────────────────────────────
class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.id,
    required this.name,
    required this.speciality,
    required this.rating,
    required this.photoUrl,
    required this.isOnline,
    required this.onProfile,
    required this.onChat,
  });

  final String id;
  final String name;
  final String speciality;
  final double rating;
  final String? photoUrl;
  final bool isOnline;
  final VoidCallback onProfile;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onProfile,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: (photoUrl != null && photoUrl!.isNotEmpty)
                            ? Image.network(
                                photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _fallback(),
                              )
                            : _fallback(),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: -3,
                        right: -3,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: AppColors.neonAccent),
                      const SizedBox(width: 3),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              speciality,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.neonAccent,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.neonAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Contact',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onProfile,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Icon(Icons.person_outline_rounded,
                        size: 18, color: AppColors.onSurface),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.neonAccent,
        ),
      ),
    );
  }
}

// ─── Recent chat tile (resolves the other participant) ──────
class _RecentChatTile extends StatelessWidget {
  const _RecentChatTile({
    required this.chatData,
    required this.currentUserId,
    required this.chatService,
    required this.onTap,
  });

  final Map<String, dynamic> chatData;
  final String currentUserId;
  final ChatService chatService;
  final void Function(String otherUserId, String name) onTap;

  @override
  Widget build(BuildContext context) {
    final participants = List<String>.from(chatData['participants'] ?? []);
    final otherUserId =
        participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    if (otherUserId.isEmpty) return const SizedBox.shrink();

    final lastMessage = (chatData['lastMessage'] as String?) ?? '';
    final unread = chatService.getUnreadCount(chatData);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = (data?['fullName'] ?? data?['name'] ?? data?['email'] ?? 'User')
            .toString();
        final photoUrl = (data?['profileImage'] ?? data?['photoUrl']) as String?;

        return GestureDetector(
          onTap: () => onTap(otherUserId, name),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
                    child: (photoUrl != null && photoUrl.isNotEmpty)
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatar(name),
                          )
                        : _avatar(name),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastMessage.isEmpty ? 'Start the conversation' : lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: unread > 0
                              ? AppColors.onSurface
                              : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.neonAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.neonAccent,
        ),
      ),
    );
  }
}

// ─── Floating AI button (functional) ────────────────────────
class _FloatingAIButton extends StatelessWidget {
  const _FloatingAIButton({required this.controller, required this.onTap});

  final AnimationController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final floatY = sin(controller.value * 2 * pi) * 6;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 72),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface.withValues(alpha: 0.85),
            border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.neonAccent.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Lottie.asset(
                    'assets/images/Welcome Animation.json',
                    fit: BoxFit.contain,
                    repeat: true,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.neonAccent,
                      size: 24,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.neonAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'AI',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
