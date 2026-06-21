import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../screens/chat_screen.dart';
import '../screens/find_pros_screen.dart';

void showNotificationPanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    useSafeArea: true,
    builder: (_) => const _NotificationPanel(),
  );
}

// ─── Panel shell ────────────────────────────────────────────────────────────

class _NotificationPanel extends StatefulWidget {
  const _NotificationPanel();

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _itemCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  int _tab = 0;
  static const _tabs = ['Messages', 'Bookings'];

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 440));
    _scaleAnim = Tween<double>(begin: 0.93, end: 1.0).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _itemCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _enterCtrl.forward().then((_) => _itemCtrl.forward());
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _itemCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int i) {
    setState(() => _tab = i);
    _itemCtrl.reset();
    _itemCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        alignment: Alignment.bottomCenter,
        child: Container(
          height: h * 0.86,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, -8)),
            ],
          ),
          child: Column(children: [
            _handle(),
            _header(),
            const SizedBox(height: 16),
            _tabRow(),
            _divider(),
            Expanded(child: _body()),
          ]),
        ),
      ),
    );
  }

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 16, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notifications',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: -0.3)),
            StreamBuilder<int>(
              stream: NotificationService.instance.watchUnreadCount(),
              builder: (_, s) {
                final n = s.data ?? 0;
                return Text(
                  n == 0 ? "You're all caught up" : '$n unread',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: n == 0
                        ? AppColors.onSurfaceVariant.withValues(alpha: 0.5)
                        : AppColors.primaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ]),
        ),
        TextButton(
          onPressed: () => NotificationService.instance.markAllAsRead(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Mark all read',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryContainer)),
        ),
      ]),
    );
  }

  Widget _tabRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final sel = _tab == i;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _switchTab(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primaryContainer
                        : AppColors.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: AppColors.primaryContainer
                                    .withValues(alpha: 0.28),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ]
                        : [],
                  ),
                  child: Text(_tabs[i],
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? AppColors.background
                              : AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.7))),
                ),
              ),
            );
          }),
        ),
      );

  Widget _divider() => Container(
      height: 1,
      margin: const EdgeInsets.only(top: 12),
      color: AppColors.glassBorder);

  Widget _body() => _tab == 0 ? _messagesTab() : _bookingsTab();

  // ─── Messages tab: real chats from ChatService ──────────────────────────

  Widget _messagesTab() {
    final chatService = ChatService();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: chatService.getUserChats(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _skeletons();
        }
        if (snap.hasError) return _empty('Could not load messages');

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _empty('No messages yet');

        // Filter to chats with at least one message
        final chats = docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['lastMessage'] != null &&
                ((d.data() as Map<String, dynamic>)['lastMessage'] as String)
                    .isNotEmpty)
            .toList();

        if (chats.isEmpty) return _empty('No messages yet');

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          itemCount: chats.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final data = chats[i].data() as Map<String, dynamic>;
            final participants =
                List<String>.from(data['participants'] ?? []);
            final otherUid = participants.firstWhere(
                (id) => id != currentUid,
                orElse: () => '');
            final unread = chatService.getUnreadCount(data);

            return _AnimatedItem(
              index: i,
              controller: _itemCtrl,
              child: _ChatCard(
                chatData: data,
                otherUid: otherUid,
                unreadCount: unread,
                onTap: () => _openChat(otherUid, data),
              ),
            );
          },
        );
      },
    );
  }

  void _openChat(String otherUid, Map<String, dynamic> chatData) async {
    if (otherUid.isEmpty) return;
    final nav = Navigator.of(context);
    nav.pop();

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .get();
    final name = doc.data()?['name'] as String? ??
        doc.data()?['displayName'] as String? ??
        'User';
    final role = doc.data()?['role'] as String?;

    if (!mounted) return;
    nav.push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        otherUserId: otherUid,
        otherUserName: name,
        otherUserRole: role,
      ),
    ));
  }

  // ─── Bookings tab: notifications collection ─────────────────────────────

  Widget _bookingsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NotificationService.instance.getUserNotifications(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _skeletons();
        }
        if (snap.hasError) return _empty('Could not load notifications');

        final docs = snap.data?.docs ?? [];
        final filtered = docs.where((d) {
          final type = d.data()['type'] as String? ?? '';
          return type.contains('booking') ||
              type.contains('job') ||
              type.contains('technician');
        }).toList();

        if (filtered.isEmpty) return _empty('No booking activity yet');

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _AnimatedItem(
            index: i,
            controller: _itemCtrl,
            child: _BookingCard(
              data: filtered[i].data(),
              docId: filtered[i].id,
              onTap: () async {
                final nav = Navigator.of(context);
                await NotificationService.instance
                    .markAsRead(filtered[i].id);
                if (!mounted) return;
                nav.pop();
                nav.push(MaterialPageRoute(
                    builder: (_) => const FindProsScreen()));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _skeletons() => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _SkeletonCard(index: i),
      );

  Widget _empty(String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                size: 32),
          ),
          SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.55))),
          SizedBox(height: 6),
          Text("You're all caught up",
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4))),
        ]),
      );
}

// ─── Animated item wrapper ───────────────────────────────────────────────────

class _AnimatedItem extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;
  const _AnimatedItem(
      {required this.index,
      required this.controller,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.08).clamp(0.0, 0.65);
    final end = (start + 0.42).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = Interval(start, end, curve: Curves.easeOutCubic)
            .transform(controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, 22 * (1 - t)), child: child),
        );
      },
    );
  }
}

// ─── Chat card (Messages tab) ────────────────────────────────────────────────

class _ChatCard extends StatelessWidget {
  final Map<String, dynamic> chatData;
  final String otherUid;
  final int unreadCount;
  final VoidCallback onTap;
  const _ChatCard(
      {required this.chatData,
      required this.otherUid,
      required this.unreadCount,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lastMsg = chatData['lastMessage'] as String? ?? '';
    final lastTime = chatData['lastMessageTime'] as Timestamp?;
    final hasUnread = unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.primaryContainer.withValues(alpha: 0.06)
              : AppColors.surfaceContainerHighest.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasUnread
                ? AppColors.primaryContainer.withValues(alpha: 0.22)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded,
                color: AppColors.primaryContainer.withValues(alpha: 0.7),
                size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUid)
                  .get(),
              builder: (_, snap) {
                final userData =
                    snap.data?.data() as Map<String, dynamic>? ?? {};
                final name = userData['name'] as String? ??
                    userData['displayName'] as String? ??
                    'User';
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (lastTime != null)
                          Text(_fmtTime(lastTime.toDate()),
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.45))),
                      ]),
                      SizedBox(height: 3),
                      Row(children: [
                        Expanded(
                          child: Text(lastMsg,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: hasUnread
                                    ? AppColors.onSurface
                                        .withValues(alpha: 0.85)
                                    : AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.primaryContainer
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6)
                              ],
                            ),
                            child: Text('$unreadCount',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.background)),
                          ),
                      ]),
                    ]);
              },
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
              size: 13),
        ]),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }
}

// ─── Booking notification card ───────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onTap;
  const _BookingCard(
      {required this.data, required this.docId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? '';
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final isRead = data['isRead'] as bool? ?? true;
    final ts = data['createdAt'] as Timestamp?;
    final (icon, color) = _style(type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isRead
              ? AppColors.surfaceContainerHighest.withValues(alpha: 0.18)
              : AppColors.primaryContainer.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead
                ? AppColors.glassBorder
                : AppColors.primaryContainer.withValues(alpha: 0.22),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primaryContainer
                                    .withValues(alpha: 0.5),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                  ]),
                  SizedBox(height: 4),
                  Text(body,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant
                              .withValues(alpha: 0.75),
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (ts != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.access_time_rounded,
                          size: 11,
                          color: AppColors.onSurfaceVariant
                              .withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(_fmtTime(ts.toDate()),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.45))),
                    ]),
                  ],
                ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
              size: 13),
        ]),
      ),
    );
  }

  (IconData, Color) _style(String t) => switch (t) {
        'booking_request' => (Icons.engineering_outlined, AppColors.highPriority),
        'booking_submitted' => (Icons.send_rounded, AppColors.primaryContainer),
        'booking_accepted' => (Icons.check_circle_rounded, AppColors.success),
        'booking_rejected' => (Icons.cancel_rounded, AppColors.emergency),
        'booking_inspection_requested' => (Icons.search_rounded, AppColors.neonAccent),
        'booking_inspection_accepted' => (Icons.event_available_rounded, AppColors.primaryContainer),
        'booking_inspection_declined' => (Icons.event_busy_rounded, AppColors.emergency),
        'booking_inspection_completed' => (Icons.fact_check_rounded, AppColors.success),
        'booking_quote_sent' => (Icons.request_quote_rounded, AppColors.neonAccent),
        'technician_on_way' => (Icons.directions_car_rounded, AppColors.statusOnTheWay),
        'job_started' => (Icons.construction_rounded, AppColors.statusInProgress),
        'job_completed' => (Icons.celebration_rounded, AppColors.success),
        _ => (Icons.notifications_rounded, AppColors.onSurfaceVariant),
      };

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Skeleton loading card ───────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  final int index;
  const _SkeletonCard({required this.index});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Opacity(
        opacity: 0.35 + 0.4 * _ctrl.value,
        child: Container(
          height: 74,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: AppColors.shimmerHighlight,
                  borderRadius: BorderRadius.circular(13)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        height: 12,
                        decoration: BoxDecoration(
                            color: AppColors.shimmerHighlight,
                            borderRadius: BorderRadius.circular(6))),
                    SizedBox(height: 8),
                    Container(
                        height: 10,
                        width: 140,
                        decoration: BoxDecoration(
                            color: AppColors.shimmerHighlight,
                            borderRadius: BorderRadius.circular(6))),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
