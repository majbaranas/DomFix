import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../services/chat_service.dart';
import '../widgets/scroll_reveal.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text('Messages', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  const Spacer(),
                  Icon(Icons.edit_note_rounded, color: AppColors.onSurfaceVariant, size: 24),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search conversations...', hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4), size: 20),
                  filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Center(child: Text('Please login', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)));

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getUserChats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: AppColors.neonAccent));
        if (snapshot.hasError) return Center(child: Text('Error loading chats', style: GoogleFonts.inter(color: AppColors.error)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No conversations yet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5))),
          ]));
        }

        final chats = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          return (data['lastMessage'] as String? ?? '').toLowerCase().contains(_searchQuery);
        }).toList();

        if (chats.isEmpty && _searchQuery.isNotEmpty) return Center(child: Text('No results', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chatData = chats[index].data() as Map<String, dynamic>;
            return RevealItem(
              delay: Duration(milliseconds: index * 45 > 180 ? 180 : index * 45),
              child: _ChatListItem(
                chatData: chatData,
                currentUserId: currentUserId,
                chatService: _chatService,
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final Map<String, dynamic> chatData;
  final String currentUserId;
  final ChatService chatService;
  const _ChatListItem({required this.chatData, required this.currentUserId, required this.chatService});

  @override
  Widget build(BuildContext context) {
    final participants = List<String>.from(chatData['participants'] ?? []);
    final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    if (otherUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) return _skeleton();
        final userData = userSnapshot.data?.exists == true ? userSnapshot.data!.data() as Map<String, dynamic> : <String, dynamic>{};
        final name = userData['name'] ?? userData['email'] ?? 'Unknown';
        final photoUrl = userData['profileImage'] ?? userData['photoUrl'];
        final lastMessage = (chatData['lastMessage'] as String?)?.trim().isNotEmpty == true
            ? chatData['lastMessage'] as String
            : 'New conversation';
        final timestamp = chatData['lastMessageTime'] as Timestamp?;
        final unreadCount = chatService.getUnreadCount(chatData);
        final isUnread = unreadCount > 0;

        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: otherUserId, otherUserName: name, otherUserRole: 'user'))),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
                  child: ClipOval(child: photoUrl != null
                    ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _avatar(name))
                    : _avatar(name)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(_formatTimestamp(timestamp), style: GoogleFonts.inter(fontSize: 11, color: isUnread ? AppColors.neonAccent : AppColors.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Expanded(child: Text(lastMessage, style: GoogleFonts.inter(fontSize: 13, fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400, color: isUnread ? AppColors.onSurface : AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.neonAccent, borderRadius: BorderRadius.circular(10)),
                        child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
                      ),
                    ],
                  ]),
                ])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatar(String name) => Container(color: AppColors.surfaceContainerHigh, child: Center(
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neonAccent))));

  Widget _skeleton() => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 100, height: 14, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 6),
      Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
    ])),
  ]));

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now(); final date = timestamp.toDate(); final diff = now.difference(date);
    if (diff.inDays == 0) { final h = date.hour > 12 ? date.hour - 12 : date.hour; final p = date.hour >= 12 ? 'PM' : 'AM'; return '${h == 0 ? 12 : h}:${date.minute.toString().padLeft(2, '0')} $p'; }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) { const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']; return days[date.weekday - 1]; }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
