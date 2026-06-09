import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/booking_service.dart';
import '../services/review_service.dart';
import '../services/technician_profile_service.dart';
import '../models/review_model.dart';
import '../models/technician_profile_model.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';
import 'booking_flow_screen.dart';

/// Production-ready Technician Profile Screen
/// Displays REAL dynamic data from Firestore using TechnicianProfileService
/// No static/mock data - all information comes from onboarding + live stats
class TechnicianProfileScreen extends StatefulWidget {
  final String technicianId;
  final String? initialName;
  const TechnicianProfileScreen({super.key, required this.technicianId, this.initialName});
  @override
  State<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  TechnicianProfileModel? _profile;
  List<TechnicianReview> _reviews = [];
  List<CompletedJobPhoto> _workPhotos = [];
  bool _loading = true;
  String? _error;
  bool _openingChat = false;
  
  final _profileService = TechnicianProfileService();

  @override
  void initState() { super.initState(); _fetchProfile(); }

  Future<void> _fetchProfile() async {
    print('[TechnicianProfile] 🔵 Fetching dynamic profile...');
    print('[TechnicianProfile]   technicianId: ${widget.technicianId}');
    
    setState(() { _loading = true; _error = null; });
    
    try {
      print('[TechnicianProfile] 📋 Loading from TechnicianProfileService...');
      final profile = await _profileService.getProfile(widget.technicianId);
      
      if (profile == null) {
        print('[TechnicianProfile] ❌ Profile not found');
        if (mounted) setState(() { _error = 'Technician not found.'; _loading = false; });
        return;
      }
      
      print('[TechnicianProfile] ✅ Profile loaded: ${profile.fullName}');
      print('[TechnicianProfile]   Completion: ${profile.profileCompletionScore.toStringAsFixed(0)}%');
      print('[TechnicianProfile]   Rating: ${profile.rating}');
      print('[TechnicianProfile]   Reviews: ${profile.reviewCount}');
      print('[TechnicianProfile]   Completed Jobs: ${profile.completedJobs}');
      print('[TechnicianProfile]   Specialties: ${profile.specialties.length}');
      print('[TechnicianProfile]   Portfolio: ${profile.portfolioUrls.length} images');
      
      // Fetch reviews
      print('[TechnicianProfile] 📝 Fetching reviews...');
      final reviewsSnapshot = await ReviewService.instance
          .watchTechnicianReviews(widget.technicianId, limit: 10)
          .first;
      print('[TechnicianProfile] ✅ Reviews: ${reviewsSnapshot.length}');
      
      // Fetch work photos
      print('[TechnicianProfile] 📸 Fetching work photos...');
      final photosSnapshot = await ReviewService.instance
          .watchTechnicianWorkPhotos(widget.technicianId, limit: 12)
          .first;
      print('[TechnicianProfile] ✅ Photos: ${photosSnapshot.length}');
      
      if (mounted) setState(() {
        _profile = profile;
        _reviews = reviewsSnapshot;
        _workPhotos = photosSnapshot;
        _loading = false;
      });
    } catch (e, stackTrace) {
      print('[TechnicianProfile] ❌ ERROR: $e');
      print('[TechnicianProfile] StackTrace: $stackTrace');
      if (mounted) setState(() { _error = 'Failed to load profile.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loading ? _buildSkeleton() : _error != null ? _buildError() : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 4, 8, 8),
          color: AppColors.background,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), color: AppColors.onSurface, onPressed: () => Navigator.pop(context)),
              const Spacer(),
              Text('Profile', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.more_horiz_rounded), color: AppColors.onSurfaceVariant, onPressed: () {}),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(p),
                const SizedBox(height: 24),
                _buildStats(p),
                const SizedBox(height: 24),
                _buildBio(p),
                const SizedBox(height: 24),
                if (_workPhotos.isNotEmpty || p.portfolioUrls.isNotEmpty) ...[_buildPortfolio(p), const SizedBox(height: 24)],
                _buildReviews(p),
              ],
            ),
          ),
        ),
        _buildActionBar(p),
      ],
    );
  }

  Widget _buildHero(TechnicianProfileModel p) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface,
                  border: Border.all(color: AppColors.divider, width: 2)),
                child: ClipOval(
                  child: p.profilePhotoUrl != null
                    ? Image.network(p.profilePhotoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar(p.fullName))
                    : _defaultAvatar(p.fullName),
                ),
              ),
              if (p.isAvailable)
                Positioned(bottom: 2, right: 2, child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success,
                    border: Border.all(color: AppColors.background, width: 3)),
                )),
              // Verification badge
              if (p.isIdentityVerified)
                Positioned(top: 0, right: 0, child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neonAccent,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: Icon(Icons.verified_rounded, size: 14, color: AppColors.background),
                )),
            ],
          ),
          const SizedBox(height: 16),
          Text(p.fullName, style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(p.primarySpecialty, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
              if (p.profileCompletionScore >= 50) ...[
                const SizedBox(width: 8),
                _ProfileBadge(tier: p.profileTier, score: p.profileCompletionScore),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, size: 16, color: AppColors.neonAccent),
              const SizedBox(width: 4),
              Text(p.rating.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              Text(' (${p.reviewCount})', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(TechnicianProfileModel p) {
    return Row(
      children: [
        Expanded(child: _StatCard(value: p.completedJobs > 0 ? '${p.completedJobs}+' : '—', label: 'Jobs')),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(value: p.yearsOfExperience > 0 ? '${p.yearsOfExperience}yr' : '—', label: 'Experience')),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(value: p.replyTime, label: 'Reply')),
      ],
    );
  }

  Widget _buildBio(TechnicianProfileModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        const SizedBox(height: 8),
        Text(p.bio ?? 'Professional technician', style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildPortfolio(TechnicianProfileModel p) {
    final displayPhotos = _workPhotos.isNotEmpty
        ? _workPhotos
        : p.portfolioUrls.map((url) => CompletedJobPhoto(
            id: '', bookingId: '', technicianId: p.id, clientId: '',
            imageUrl: url, kind: 'portfolio', createdAt: DateTime.now(), serviceName: 'Portfolio',
          )).toList();
    
    if (displayPhotos.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Work', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal, itemCount: displayPhotos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final photo = displayPhotos[i];
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 220,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      photo.imageUrl.isNotEmpty
                        ? Image.network(photo.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: AppColors.surface, child: Icon(Icons.image_outlined, color: AppColors.onSurfaceVariant, size: 32)))
                        : Container(color: AppColors.surface, child: Icon(Icons.image_outlined, color: AppColors.onSurfaceVariant, size: 32)),
                      Positioned(left: 0, right: 0, bottom: 0, child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC000000)])),
                        child: Text(photo.serviceName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviews(TechnicianProfileModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
            child: Center(child: Text('No reviews yet', style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant))),
          )
        else
          ..._reviews.map((r) {
            final timeAgo = _formatTimeAgo(r.createdAt);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceContainerHigh),
                        child: ClipOval(child: r.clientPhotoUrl != null
                          ? Image.network(r.clientPhotoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _reviewInitial(r.clientName ?? 'Anonymous'))
                          : _reviewInitial(r.clientName ?? 'Anonymous'))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.clientName ?? 'Anonymous', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                        Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 12, color: AppColors.neonAccent))),
                      ])),
                      if (timeAgo.isNotEmpty) Text(timeAgo, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  if (r.comment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('"${r.comment}"', style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, height: 1.5, color: AppColors.onSurfaceVariant)),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
  
  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildActionBar(TechnicianProfileModel p) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _openingChat ? null : () => _openMessageChat(p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                child: Center(child: Text('Message', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return BookingFlowScreen(
                      technicianId: p.id,
                      technicianName: p.fullName,
                      technicianPhotoUrl: p.profilePhotoUrl,
                      technicianRole: p.primarySpecialty,
                      availableServices: p.specialties.isNotEmpty ? p.specialties : [p.primarySpecialty],
                      technicianRating: p.rating,
                      experienceYears: p.yearsOfExperience,
                      replyTime: p.replyTime,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 320),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.neonAccent, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('Book Now', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onPrimary))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMessageChat(TechnicianProfileModel p) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please sign in to message.', style: GoogleFonts.inter()), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    setState(() => _openingChat = true);
    
    try {
      await BookingService.instance.ensureConversationShell(
        clientId: user.uid,
        technicianId: p.id,
        technicianName: p.fullName,
      );

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: p.id,
            otherUserName: p.fullName,
            otherUserRole: 'technician',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Widget _buildSkeleton() {
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded), color: AppColors.onSurface, onPressed: () => Navigator.pop(context)),
      ])),
      const SizedBox(height: 32),
      Container(width: 96, height: 96, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface)),
      const SizedBox(height: 16),
      Container(width: 140, height: 20, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8))),
      const SizedBox(height: 8),
      Container(width: 80, height: 14, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6))),
    ]));
  }

  Widget _buildError() {
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded), color: AppColors.onSurface, onPressed: () => Navigator.pop(context)),
      ])),
      const Spacer(),
      Icon(Icons.person_off_outlined, size: 56, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
      const SizedBox(height: 16),
      Text('Not Found', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      const SizedBox(height: 8),
      Text(_error ?? '', style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
      const SizedBox(height: 20),
      GestureDetector(onTap: _fetchProfile, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(color: AppColors.neonAccent, borderRadius: BorderRadius.circular(10)),
        child: Text('Try Again', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onPrimary)),
      )),
      const Spacer(),
    ]));
  }

  Widget _defaultAvatar(String name) => Container(color: AppColors.surfaceContainerHigh, child: Center(
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.neonAccent))));

  Widget _reviewInitial(String name) => Container(color: AppColors.surfaceContainerHigh, child: Center(
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neonAccent))));
}

class _StatCard extends StatelessWidget {
  final String value, label;
  const _StatCard({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(children: [
        Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neonAccent)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
      ]),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final String tier;
  final double score;
  const _ProfileBadge({required this.tier, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = tier == 'Gold' ? Colors.amber : tier == 'Silver' ? Colors.grey[400] : Colors.brown[400];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color ?? Colors.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(tier, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
