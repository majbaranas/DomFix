import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/technician_profile_service.dart';
import '../services/review_service.dart';
import '../models/technician_profile_model.dart';
import '../models/review_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../widgets/live_status_badge.dart';
import 'settings_screen.dart';

/// Technician's own profile view — used inside the tab bar.
/// Reuses the exact same data sources as TechnicianProfileScreen
/// but removes client-only actions (Book Now / Message / back arrow).
class TechnicianMyProfileScreen extends StatefulWidget {
  const TechnicianMyProfileScreen({super.key});

  @override
  State<TechnicianMyProfileScreen> createState() =>
      _TechnicianMyProfileScreenState();
}

class _TechnicianMyProfileScreenState extends State<TechnicianMyProfileScreen> {
  TechnicianProfileModel? _profile;
  List<TechnicianReview> _reviews = [];
  List<CompletedJobPhoto> _workPhotos = [];
  bool _loading = true;
  String? _error;

  final _profileService = TechnicianProfileService();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _error = 'Not signed in.';
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _profileService.getProfile(uid);

      if (profile == null) {
        if (mounted) {
          setState(() {
            _error = 'Profile not found.';
            _loading = false;
          });
        }
        return;
      }

      // Fetch reviews
      final reviewsSnapshot = await ReviewService.instance
          .watchTechnicianReviews(uid, limit: 10)
          .first;

      // Fetch work photos
      final photosSnapshot = await ReviewService.instance
          .watchTechnicianWorkPhotos(uid, limit: 12)
          .first;

      if (mounted) {
        setState(() {
          _profile = profile;
          _reviews = reviewsSnapshot;
          _workPhotos = photosSnapshot;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[MyProfile] Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loading
            ? _buildSkeleton()
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  // ─── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent() {
    final p = _profile!;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Header bar (no back arrow — this is a tab) ──
        SliverAppBar(
          backgroundColor: AppColors.background,
          pinned: true,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'My Profile',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings_outlined,
                  color: AppColors.onSurfaceVariant),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),

        // ── Body ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHero(p),
              const SizedBox(height: 24),
              _buildAvailabilityCard(p),
              const SizedBox(height: 24),
              _buildStats(p),
              const SizedBox(height: 24),
              _buildBio(p),
              const SizedBox(height: 24),
              if (_workPhotos.isNotEmpty || p.portfolioUrls.isNotEmpty) ...[
                _buildPortfolio(p),
                const SizedBox(height: 24),
              ],
              _buildReviews(p),
            ]),
          ),
        ),
      ],
    );
  }

  // ─── Hero (avatar, name, rating — same style as TechnicianProfileScreen) ───

  Widget _buildHero(TechnicianProfileModel p) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.divider, width: 2),
                ),
                child: ClipOval(
                  child: p.profilePhotoUrl != null
                      ? Image.network(p.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _defaultAvatar(p.fullName))
                      : _defaultAvatar(p.fullName),
                ),
              ),
              if (p.isAvailable)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      border:
                          Border.all(color: AppColors.background, width: 3),
                    ),
                  ),
                ),
              if (p.isIdentityVerified)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neonAccent,
                      border:
                          Border.all(color: AppColors.background, width: 2),
                    ),
                    child: Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.background),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(p.fullName, style: AppStyles.titleLarge),
              const SizedBox(width: 8),
              LiveStatusBadge(status: p.liveStatus),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                p.primarySpecialty,
                style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant),
              ),
              if (p.profileCompletionScore >= 50) ...[
                const SizedBox(width: 8),
                _ProfileBadge(
                    tier: p.profileTier, score: p.profileCompletionScore),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, size: 16, color: AppColors.neonAccent),
              const SizedBox(width: 4),
              Text(
                p.rating.toStringAsFixed(1),
                style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              Text(' (${p.reviewCount})',
                  style: AppStyles.bodySmall
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Availability Toggle Card ──────────────────────────────────────────────

  Widget _buildAvailabilityCard(TechnicianProfileModel p) {
    return _AvailabilityToggleCard(isAvailable: p.isAvailable);
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────

  Widget _buildStats(TechnicianProfileModel p) {
    return Row(
      children: [
        Expanded(
            child: _StatCard(
                value: p.completedJobs > 0 ? '${p.completedJobs}+' : '—',
                label: 'Jobs')),
        const SizedBox(width: 8),
        Expanded(
            child: _StatCard(
                value: p.yearsOfExperience > 0
                    ? '${p.yearsOfExperience}yr'
                    : '—',
                label: 'Experience')),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(value: p.replyTime, label: 'Reply')),
      ],
    );
  }

  // ─── Bio ───────────────────────────────────────────────────────────────────

  Widget _buildBio(TechnicianProfileModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About',
            style: AppStyles.titleMedium.copyWith(fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          p.bio ?? 'Professional technician',
          style: AppStyles.bodyMedium
              .copyWith(height: 1.6, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  // ─── Portfolio ─────────────────────────────────────────────────────────────

  Widget _buildPortfolio(TechnicianProfileModel p) {
    final displayPhotos = _workPhotos.isNotEmpty
        ? _workPhotos
        : p.portfolioUrls
            .map((url) => CompletedJobPhoto(
                  id: '',
                  bookingId: '',
                  technicianId: p.id,
                  clientId: '',
                  imageUrl: url,
                  kind: 'portfolio',
                  createdAt: DateTime.now(),
                  serviceName: 'Portfolio',
                ))
            .toList();

    if (displayPhotos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Work',
            style: AppStyles.titleMedium.copyWith(fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayPhotos.length,
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
                          ? Image.network(photo.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.surface,
                                  child: Icon(Icons.image_outlined,
                                      color: AppColors.onSurfaceVariant,
                                      size: 32)))
                          : Container(
                              color: AppColors.surface,
                              child: Icon(Icons.image_outlined,
                                  color: AppColors.onSurfaceVariant,
                                  size: 32)),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(12, 24, 12, 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0xCC000000)
                              ],
                            ),
                          ),
                          child: Text(photo.serviceName,
                              style: AppStyles.caption
                                  .copyWith(color: Colors.white)),
                        ),
                      ),
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

  // ─── Reviews ───────────────────────────────────────────────────────────────

  Widget _buildReviews(TechnicianProfileModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews',
            style: AppStyles.titleMedium.copyWith(fontSize: 16)),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppStyles.standardCardDecoration
                .copyWith(borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text('No reviews yet',
                    style: AppStyles.bodyMedium
                        .copyWith(color: AppColors.onSurfaceVariant))),
          )
        else
          ..._reviews.map((r) {
            final timeAgo = _formatTimeAgo(r.createdAt);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: AppStyles.standardCardDecoration
                  .copyWith(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceContainerHigh),
                        child: ClipOval(
                          child: r.clientPhotoUrl != null
                              ? Image.network(r.clientPhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _reviewInitial(
                                          r.clientName ?? 'Anonymous'))
                              : _reviewInitial(r.clientName ?? 'Anonymous'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.clientName ?? 'Anonymous',
                                style: AppStyles.bodyMedium
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < r.rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 12,
                                  color: AppColors.neonAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (timeAgo.isNotEmpty)
                        Text(timeAgo, style: AppStyles.caption),
                    ],
                  ),
                  if (r.comment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '"${r.comment}"',
                      style: AppStyles.bodyMedium.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildSkeleton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Profile',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                Icon(Icons.settings_outlined,
                    color: AppColors.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 32),
            Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.surface)),
            const SizedBox(height: 16),
            Container(
                width: 140,
                height: 20,
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 8),
            Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6))),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Profile',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                IconButton(
                  icon: Icon(Icons.settings_outlined,
                      color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ],
            ),
          ),
          const Spacer(),
          Icon(Icons.person_off_outlined,
              size: 56,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Profile Error',
              style: AppStyles.titleLarge.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text(_error ?? '',
              style: AppStyles.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _fetchProfile,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.neonAccent,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Try Again', style: AppStyles.buttonText),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _defaultAvatar(String name) => Container(
      color: AppColors.surfaceContainerHigh,
      child: Center(
          child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppStyles.titleLarge
                  .copyWith(fontSize: 36, color: AppColors.neonAccent))));

  Widget _reviewInitial(String name) => Container(
      color: AppColors.surfaceContainerHigh,
      child: Center(
          child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.neonAccent))));
}

// ─── Availability Toggle Card ────────────────────────────────────────────────

class _AvailabilityToggleCard extends StatefulWidget {
  final bool isAvailable;
  const _AvailabilityToggleCard({required this.isAvailable});

  @override
  State<_AvailabilityToggleCard> createState() =>
      _AvailabilityToggleCardState();
}

class _AvailabilityToggleCardState extends State<_AvailabilityToggleCard> {
  late bool _isOnline;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.isAvailable;
  }

  Future<void> _toggle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _updating) return;

    HapticFeedback.lightImpact();
    setState(() => _updating = true);

    final newValue = !_isOnline;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnline': newValue,
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _isOnline = newValue);
    } catch (e) {
      debugPrint('Error toggling availability: $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOnline
              ? AppColors.neonAccent.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? AppColors.neonAccent : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'Available for Jobs' : 'Currently Offline',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isOnline
                      ? 'Clients can find and book you'
                      : 'Toggle to start receiving requests',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: _isOnline
                    ? AppColors.neonAccent
                    : AppColors.surfaceContainerHigh,
                border: Border.all(
                  color: _isOnline
                      ? AppColors.neonAccent
                      : AppColors.glassBorder,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment:
                    _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isOnline
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
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

// ─── Reusable Widgets (same as TechnicianProfileScreen) ──────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: AppStyles.standardCardDecoration
          .copyWith(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value,
              style:
                  AppStyles.titleMedium.copyWith(color: AppColors.neonAccent)),
          const SizedBox(height: 4),
          Text(label, style: AppStyles.caption),
        ],
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final String tier;
  final double score;
  const _ProfileBadge({required this.tier, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = tier == 'Gold'
        ? Colors.amber
        : tier == 'Silver'
            ? Colors.grey[400]
            : Colors.brown[400];
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
          Text(tier,
              style:
                  AppStyles.caption.copyWith(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}
