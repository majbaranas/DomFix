import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/booking_service.dart';
import '../services/review_service.dart';
import '../services/technician_profile_service.dart';
import '../services/cloudinary_service.dart';
import '../models/review_model.dart';
import '../models/technician_profile_model.dart';
import '../theme/app_colors.dart';

import '../widgets/live_status_badge.dart';
import 'chat_screen.dart';
import 'booking_flow_screen.dart';

class PremiumTechnicianProfileScreen extends StatefulWidget {
  final String technicianId;
  final bool isTechnicianMode;

  const PremiumTechnicianProfileScreen({
    super.key,
    required this.technicianId,
    this.isTechnicianMode = false,
  });

  @override
  State<PremiumTechnicianProfileScreen> createState() => _PremiumTechnicianProfileScreenState();
}

class _PremiumTechnicianProfileScreenState extends State<PremiumTechnicianProfileScreen> with SingleTickerProviderStateMixin {
  TechnicianProfileModel? _profile;
  List<TechnicianReview> _reviews = [];
  List<CompletedJobPhoto> _workPhotos = [];
  bool _loading = true;
  String? _error;
  bool _openingChat = false;
  bool _updating = false;

  final _profileService = TechnicianProfileService();
  late ScrollController _scrollController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animationController.forward();
    _fetchProfile();
    
    // Background Self-Healing Sync
    if (widget.isTechnicianMode) {
      _profileService.syncTechnicianStats(widget.technicianId);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await _profileService.getProfile(widget.technicianId);
      if (profile == null) {
        if (mounted) setState(() { _error = 'Technician not found.'; _loading = false; });
        return;
      }
      
      final reviewsSnapshot = await ReviewService.instance
          .watchTechnicianReviews(widget.technicianId, limit: 10)
          .first;
          
      final photosSnapshot = await ReviewService.instance
          .watchTechnicianWorkPhotos(widget.technicianId, limit: 12)
          .first;
          
      if (mounted) setState(() {
        _profile = profile;
        _reviews = reviewsSnapshot;
        _workPhotos = photosSnapshot;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load profile.'; _loading = false; });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Inline Editing Logic (Technician Mode Only) — ALL PRESERVED AS-IS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _editBio() async {
    if (!widget.isTechnicianMode || _profile == null) return;
    final controller = TextEditingController(text: _profile!.bio);
    final newBio = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Edit About', style: GoogleFonts.spaceGrotesk(color: AppColors.onSurface)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: GoogleFonts.inter(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'Tell clients about yourself...',
            hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Save', style: GoogleFonts.inter(color: AppColors.neonAccent))),
        ],
      ),
    );

    if (newBio != null && newBio != _profile!.bio) {
      setState(() => _updating = true);
      try {
        await _profileService.updateProfile(uid: widget.technicianId, bio: newBio);
        await _fetchProfile();
      } catch (e) {
        debugPrint('Error updating bio: $e');
      } finally {
        if (mounted) setState(() => _updating = false);
      }
    }
  }

  Future<void> _addSkill() async {
    if (!widget.isTechnicianMode || _profile == null) return;
    final controller = TextEditingController();
    final newSkill = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Add Skill', style: GoogleFonts.spaceGrotesk(color: AppColors.onSurface)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g. Pipe fitting',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('Add', style: GoogleFonts.inter(color: AppColors.neonAccent))),
        ],
      ),
    );

    if (newSkill != null && newSkill.isNotEmpty && !_profile!.specialties.contains(newSkill)) {
      setState(() => _updating = true);
      try {
        await _profileService.updateProfile(
          uid: widget.technicianId,
          specialties: [..._profile!.specialties, newSkill]
        );
        await _fetchProfile();
      } finally {
        if (mounted) setState(() => _updating = false);
      }
    }
  }

  Future<void> _removeSkill(String skill) async {
    if (!widget.isTechnicianMode || _profile == null) return;
    setState(() => _updating = true);
    try {
      await _profileService.updateProfile(
        uid: widget.technicianId,
        specialties: _profile!.specialties.where((s) => s != skill).toList()
      );
      await _fetchProfile();
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _toggleAvailability() async {
    if (!widget.isTechnicianMode || _profile == null) return;
    HapticFeedback.lightImpact();
    setState(() => _updating = true);
    final newValue = !_profile!.isAvailable;
    try {
      await _profileService.updateProfile(
        uid: widget.technicianId,
        isAvailable: newValue,
        liveStatus: newValue ? 'online' : 'offline',
        lastSeen: DateTime.now(),
      );
      await _fetchProfile();
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _editPhoto() async {
    if (!widget.isTechnicianMode || _profile == null) return;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _updating = true);
        final cloudinary = CloudinaryService();
        final newUrl = await cloudinary.uploadProfilePhoto(
          uid: widget.technicianId,
          imageFile: File(pickedFile.path),
        );
        await _profileService.updateProfile(uid: widget.technicianId, profilePhotoUrl: newUrl);
        await _fetchProfile();
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _editName() async {
    if (!widget.isTechnicianMode || _profile == null) return;
    final controller = TextEditingController(text: _profile!.fullName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Edit Name', style: GoogleFonts.spaceGrotesk(color: AppColors.onSurface)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: AppColors.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('Save', style: GoogleFonts.inter(color: AppColors.neonAccent))),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _profile!.fullName) {
      setState(() => _updating = true);
      try {
        await _profileService.updateProfile(uid: widget.technicianId, fullName: newName);
        await _fetchProfile();
      } finally {
        if (mounted) setState(() => _updating = false);
      }
    }
  }

  Future<void> _editExperience() async {
    if (!widget.isTechnicianMode || _profile == null) return;
    final controller = TextEditingController(text: _profile!.yearsOfExperience.toString());
    final newExpString = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Edit Experience', style: GoogleFonts.spaceGrotesk(color: AppColors.onSurface)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(color: AppColors.onSurface),
          decoration: InputDecoration(
            suffixText: 'years',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('Save', style: GoogleFonts.inter(color: AppColors.neonAccent))),
        ],
      ),
    );

    if (newExpString != null && newExpString.isNotEmpty) {
      final newExp = int.tryParse(newExpString);
      if (newExp != null && newExp != _profile!.yearsOfExperience) {
        setState(() => _updating = true);
        try {
          await _profileService.updateProfile(uid: widget.technicianId, yearsOfExperience: newExp);
          await _fetchProfile();
        } finally {
          if (mounted) setState(() => _updating = false);
        }
      }
    }
  }

  Future<void> _addPortfolioPhoto() async {
    if (!widget.isTechnicianMode || _profile == null) return;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _updating = true);
        final cloudinary = CloudinaryService();
        final newUrl = await cloudinary.uploadPortfolioPhoto(
          uid: widget.technicianId,
          imageFile: File(pickedFile.path),
        );
        await _profileService.updateProfile(
          uid: widget.technicianId,
          portfolioUrls: [..._profile!.portfolioUrls, newUrl],
        );
        await _fetchProfile();
      }
    } catch (e) {
      debugPrint('Error uploading portfolio photo: $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _removePortfolioPhoto(String url) async {
    if (!widget.isTechnicianMode || _profile == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove Photo?', style: GoogleFonts.spaceGrotesk(color: AppColors.onSurface)),
        content: Text('Are you sure you want to remove this photo from your portfolio?', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove', style: GoogleFonts.inter(color: AppColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _updating = true);
      try {
        await _profileService.updateProfile(
          uid: widget.technicianId,
          portfolioUrls: _profile!.portfolioUrls.where((u) => u != url).toList(),
        );
        await _fetchProfile();
      } finally {
        if (mounted) setState(() => _updating = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD — Matching the Client View Profile screenshot exactly
  // ═══════════════════════════════════════════════════════════════════════════

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
                : Stack(
                    children: [
                      Column(
                        children: [
                          // Scrollable content
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _fetchProfile,
                              color: AppColors.neonAccent,
                              backgroundColor: AppColors.surface,
                              child: CustomScrollView(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                slivers: [
                                  _buildAppBar(),
                                  SliverToBoxAdapter(child: _buildProfileHeader()),
                                  SliverToBoxAdapter(child: _buildStatBoxes()),
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                                    sliver: SliverList(
                                      delegate: SliverChildListDelegate([
                                        _buildAboutSection(),
                                        const SizedBox(height: 28),
                                        _buildSkillsSection(),
                                      ]),
                                    ),
                                  ),
                                  SliverToBoxAdapter(child: _buildRecentWorkSection()),
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                                    sliver: SliverList(
                                      delegate: SliverChildListDelegate([
                                        _buildCertificationsSection(),
                                        if (_profile!.certificationUrls.isNotEmpty) const SizedBox(height: 28),
                                        _buildReviewsSection(),
                                        const SizedBox(height: 24),
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Fixed bottom action bar (Only for clients)
                          if (!widget.isTechnicianMode) _buildBottomActionBar(),
                        ],
                      ),
                      // Loading overlay
                      if (_updating)
                        Positioned(
                          top: 0, left: 0, right: 0,
                          child: SafeArea(
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: AppColors.neonAccent,
                              minHeight: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  // ─── App Bar ─────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      pinned: true,
      centerTitle: true,
      title: Text('Profile', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onSurface, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.isTechnicianMode && _profile != null)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.onSurface),
            color: AppColors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'edit') {
                 _editBio();
              } else if (value == 'status') {
                 _toggleAvailability();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: AppColors.onSurface, size: 18),
                    const SizedBox(width: 12),
                    Text('Edit Profile', style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(
                      Icons.power_settings_new_rounded,
                      color: _profile!.isAvailable ? AppColors.onSurfaceVariant : AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _profile!.isAvailable ? 'Go Offline' : 'Go Online',
                      style: GoogleFonts.inter(
                        color: _profile!.isAvailable ? AppColors.onSurfaceVariant : AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else if (!widget.isTechnicianMode)
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.onSurface),
            onPressed: () {},
          ),
      ],
    );
  }

  // ─── Profile Header (Avatar + Name + Specialty + Rating) ─────────────────
  Widget _buildProfileHeader() {
    final p = _profile!;
    return FadeTransition(
      opacity: _animationController,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            // Avatar
            GestureDetector(
              onTap: widget.isTechnicianMode ? _editPhoto : null,
              child: Stack(
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.6), width: 2.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: p.profilePhotoUrl != null
                            ? Image.network(p.profilePhotoUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultAvatar(p.fullName))
                            : _defaultAvatar(p.fullName),
                      ),
                    ),
                  ),
                  if (widget.isTechnicianMode)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neonAccent,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                        child: Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.background),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: widget.isTechnicianMode ? _editName : null,
                  child: Text(
                    p.fullName.toLowerCase(),
                    style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                  ),
                ),
                const SizedBox(width: 10),
                LiveStatusBadge(status: p.isAvailable ? 'online' : 'offline', size: 8),
              ],
            ),
            const SizedBox(height: 8),

            // Specialty + Tier Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.primarySpecialty,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.neonAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    p.profileTier,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.neonAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, size: 16, color: AppColors.neonAccent),
                const SizedBox(width: 4),
                Text(
                  '${p.rating.toStringAsFixed(1)} (${p.reviewCount})',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── 3 Stat Boxes (Jobs / Experience / Reply) ────────────────────────────
  Widget _buildStatBoxes() {
    final p = _profile!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _statBox(
            p.completedJobs > 0 ? '${p.completedJobs}' : '—',
            'Jobs',
          )),
          const SizedBox(width: 10),
          Expanded(child: _statBox(
            p.yearsOfExperience > 0 ? '${p.yearsOfExperience}yr' : '—',
            'Experience',
            onTap: widget.isTechnicianMode ? _editExperience : null,
          )),
          const SizedBox(width: 10),
          Expanded(child: _statBox(
            p.replyTime,
            'Reply',
          )),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ─── About Section ───────────────────────────────────────────────────────
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('About', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            const Spacer(),
            if (widget.isTechnicianMode)
              GestureDetector(
                onTap: _editBio,
                child: Icon(Icons.edit_rounded, size: 18, color: AppColors.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _profile!.bio?.isNotEmpty == true ? _profile!.bio! : 'No biography provided yet.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  // ─── Skills / Specialties Section ────────────────────────────────────────
  Widget _buildSkillsSection() {
    if (_profile!.specialties.isEmpty && !widget.isTechnicianMode) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Specialties', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._profile!.specialties.map((skill) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(skill, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
                  if (widget.isTechnicianMode) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeSkill(skill),
                      child: Icon(Icons.close_rounded, size: 14, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            )),
            if (widget.isTechnicianMode)
              GestureDetector(
                onTap: _addSkill,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.neonAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: AppColors.neonAccent),
                      const SizedBox(width: 4),
                      Text('Add', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neonAccent)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─── Recent Work (Horizontal Scroll Cards) ───────────────────────────────
  Widget _buildRecentWorkSection() {
    // Combine work photos + portfolio photos
    final allPhotos = <CompletedJobPhoto>[
      ..._workPhotos,
      ..._profile!.portfolioUrls
          .where((url) => !_workPhotos.any((wp) => wp.imageUrl == url))
          .map((url) => CompletedJobPhoto(
                id: '', bookingId: '', technicianId: _profile!.id, clientId: '',
                imageUrl: url, kind: 'portfolio', createdAt: DateTime.now(),
                serviceName: 'Portfolio',
              )),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('Recent Work', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              const Spacer(),
              if (widget.isTechnicianMode)
                GestureDetector(
                  onTap: _addPortfolioPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.neonAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_rounded, size: 18, color: AppColors.neonAccent),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (allPhotos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, size: 32, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Text('No work photos yet', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: allPhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final photo = allPhotos[i];
                return GestureDetector(
                  onTap: () => _showFullscreenImage(photo.imageUrl),
                  onLongPress: widget.isTechnicianMode && photo.kind == 'portfolio'
                      ? () => _removePortfolioPhoto(photo.imageUrl)
                      : null,
                  child: SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Expanded(
                          child: Container(
                            width: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.divider),
                              image: DecorationImage(
                                image: NetworkImage(photo.imageUrl),
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Label
                        Text(
                          (photo.serviceName.isNotEmpty) ? photo.serviceName : _profile!.primarySpecialty,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  void _showFullscreenImage(String url) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      pageBuilder: (context, _, __) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Hero(
              tag: 'portfolio_$url',
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    ));
  }

  // ─── Certifications Section ──────────────────────────────────────────────
  Widget _buildCertificationsSection() {
    if (_profile!.certificationUrls.isEmpty && !widget.isTechnicianMode) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Certifications', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            const Spacer(),
            if (widget.isTechnicianMode)
              GestureDetector(
                onTap: () {},
                child: Icon(Icons.add_rounded, size: 20, color: AppColors.neonAccent),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_profile!.certificationUrls.isEmpty)
          Text('No certifications added.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant))
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, size: 28, color: AppColors.neonAccent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Verified Professional', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                      const SizedBox(height: 2),
                      Text('${_profile!.certificationUrls.length} certificate(s) on file', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Reviews Section ─────────────────────────────────────────────────────
  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const SizedBox(height: 16),
        if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No reviews yet', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
          )
        else
          ..._reviews.map((r) => _buildReviewItem(r)),
      ],
    );
  }

  Widget _buildReviewItem(TechnicianReview r) {
    // Calculate relative time
    final diff = DateTime.now().difference(r.createdAt);
    String timeAgo;
    if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar circle
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonAccent.withValues(alpha: 0.15),
            ),
            child: ClipOval(
              child: r.clientPhotoUrl != null
                  ? Image.network(r.clientPhotoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          (r.clientName ?? 'A').isNotEmpty ? (r.clientName ?? 'A')[0].toLowerCase() : 'a',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neonAccent),
                        ),
                      ))
                  : Center(
                      child: Text(
                        (r.clientName ?? 'A').isNotEmpty ? (r.clientName ?? 'A')[0].toLowerCase() : 'a',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neonAccent),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.clientName ?? 'Anonymous',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(timeAgo, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14,
                      color: AppColors.neonAccent,
                    ),
                  )),
                ),
                if (r.comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${r.comment}"',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.whiteBorder5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Message Button
            Expanded(
              child: GestureDetector(
                onTap: _openingChat ? null : _openMessageChat,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.neonAccent),
                  ),
                  child: _openingChat
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.neonAccent, strokeWidth: 2))
                      : Text('Message', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neonAccent)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Book Now Button
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_profile == null) return;
                  Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => BookingFlowScreen(
                      technicianId: _profile!.id,
                      technicianName: _profile!.fullName,
                      technicianPhotoUrl: _profile!.profilePhotoUrl,
                      technicianRole: _profile!.primarySpecialty,
                      availableServices: _profile!.specialties.isNotEmpty ? _profile!.specialties : [_profile!.primarySpecialty],
                      technicianRating: _profile!.rating,
                      experienceYears: _profile!.yearsOfExperience,
                      replyTime: _profile!.replyTime,
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)), child: child);
                    },
                  ));
                },
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.neonAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Book Now', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.background)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Utilities ───────────────────────────────────────────────────────────

  Future<void> _openMessageChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _profile == null) return;

    setState(() => _openingChat = true);
    try {
      await BookingService.instance.ensureConversationShell(
        clientId: user.uid,
        technicianId: _profile!.id,
        technicianName: _profile!.fullName,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: _profile!.id, otherUserName: _profile!.fullName, otherUserRole: 'technician')));
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Widget _buildSkeleton() => SafeArea(child: Center(child: CircularProgressIndicator(color: AppColors.neonAccent)));
  Widget _buildError() => SafeArea(child: Center(child: Text(_error ?? 'Error', style: GoogleFonts.inter(color: AppColors.error))));
  
  Widget _defaultAvatar(String name) => Container(
    color: AppColors.surfaceContainerHigh,
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.spaceGrotesk(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.neonAccent))),
  );
}
