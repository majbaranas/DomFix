import 'dart:math' show cos, sqrt, asin;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

// ─── DATA MODEL (unchanged) ─────────────────────────────
class TechnicianProfile {
  final String id, name, job, bio, replyTime;
  final String? photoUrl;
  final double rating;
  final int reviewCount, jobsCompleted, experienceYears;
  final double? distanceKm;
  final bool isAvailable;
  final List<PortfolioItem> portfolio;
  final List<ReviewItem> reviews;

  const TechnicianProfile({
    required this.id, required this.name, this.photoUrl, required this.job,
    required this.bio, required this.rating, required this.reviewCount,
    required this.jobsCompleted, required this.experienceYears, required this.replyTime,
    this.distanceKm, required this.isAvailable, required this.portfolio, required this.reviews,
  });

  factory TechnicianProfile.fromFirestore(String id, Map<String, dynamic> data) {
    final rawPortfolio = data['portfolio'] as List<dynamic>? ?? [];
    final portfolio = rawPortfolio.map((e) => PortfolioItem(imageUrl: e['imageUrl'] ?? '', title: e['title'] ?? '')).toList();
    final rawReviews = data['reviews'] as List<dynamic>? ?? [];
    final reviews = rawReviews.map((e) => ReviewItem(
      reviewerName: e['reviewerName'] ?? 'Anonymous', reviewerPhoto: e['reviewerPhoto'],
      rating: (e['rating'] as num?)?.toInt() ?? 5, comment: e['comment'] ?? '', timeAgo: e['timeAgo'] ?? '',
    )).toList();
    String job = data['speciality'] ?? data['job'] ?? '';
    if (job.isEmpty) { final specs = data['specialties'] as List<dynamic>?; if (specs != null && specs.isNotEmpty) job = specs.first.toString(); }
    if (job.isEmpty) job = 'Technician';
    return TechnicianProfile(
      id: id, name: data['fullName'] ?? data['name'] ?? 'Unknown', photoUrl: data['profileImage'] ?? data['photoUrl'],
      job: job, bio: data['bio'] ?? 'Professional technician with expertise in home services.',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5, reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      jobsCompleted: (data['jobsCompleted'] as num?)?.toInt() ?? 0, experienceYears: (data['experienceYears'] as num?)?.toInt() ?? 1,
      replyTime: data['replyTime'] ?? '< 30m', distanceKm: (data['distance'] as num?)?.toDouble(),
      isAvailable: data['isAvailable'] ?? false, portfolio: portfolio, reviews: reviews,
    );
  }
}

class PortfolioItem { final String imageUrl, title; const PortfolioItem({required this.imageUrl, required this.title}); }
class ReviewItem {
  final String reviewerName, comment, timeAgo; final String? reviewerPhoto; final int rating;
  const ReviewItem({required this.reviewerName, this.reviewerPhoto, required this.rating, required this.comment, required this.timeAgo});
}

// ─── SCREEN ─────────────────────────────────────────────
class TechnicianProfileScreen extends StatefulWidget {
  final String technicianId;
  final String? initialName;
  const TechnicianProfileScreen({super.key, required this.technicianId, this.initialName});
  @override
  State<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  TechnicianProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _fetchProfile(); }

  Future<void> _fetchProfile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.technicianId).get();
      if (!doc.exists) { if (mounted) setState(() { _error = 'Technician not found.'; _loading = false; }); return; }
      final profile = TechnicianProfile.fromFirestore(doc.id, doc.data()!);
      if (mounted) setState(() { _profile = profile; _loading = false; });
    } catch (e) {
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
        // Header
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
                if (p.portfolio.isNotEmpty) ...[_buildPortfolio(p), const SizedBox(height: 24)],
                _buildReviews(p),
              ],
            ),
          ),
        ),
        _buildActionBar(p),
      ],
    );
  }

  Widget _buildHero(TechnicianProfile p) {
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
                  child: p.photoUrl != null
                    ? Image.network(p.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar(p.name))
                    : _defaultAvatar(p.name),
                ),
              ),
              if (p.isAvailable)
                Positioned(bottom: 2, right: 2, child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success,
                    border: Border.all(color: AppColors.background, width: 3)),
                )),
            ],
          ),
          const SizedBox(height: 16),
          Text(p.name, style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const SizedBox(height: 4),
          Text(p.job, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, size: 16, color: AppColors.neonAccent),
              const SizedBox(width: 4),
              Text(p.rating.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              Text(' (${p.reviewCount})', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
              if (p.distanceKm != null) ...[
                Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4))),
                Icon(Icons.location_on_outlined, size: 14, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 2),
                Text('${p.distanceKm!.toStringAsFixed(1)} km', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(TechnicianProfile p) {
    return Row(
      children: [
        Expanded(child: _StatCard(value: p.jobsCompleted > 0 ? '${p.jobsCompleted}+' : '—', label: 'Jobs')),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(value: p.experienceYears > 0 ? '${p.experienceYears}yr' : '—', label: 'Experience')),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(value: p.replyTime, label: 'Reply')),
      ],
    );
  }

  Widget _buildBio(TechnicianProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        const SizedBox(height: 8),
        Text(p.bio, style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildPortfolio(TechnicianProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Work', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal, itemCount: p.portfolio.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = p.portfolio[i];
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 220,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.imageUrl.isNotEmpty
                        ? Image.network(item.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: AppColors.surface, child: Icon(Icons.image_outlined, color: AppColors.onSurfaceVariant, size: 32)))
                        : Container(color: AppColors.surface, child: Icon(Icons.image_outlined, color: AppColors.onSurfaceVariant, size: 32)),
                      Positioned(left: 0, right: 0, bottom: 0, child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC000000)])),
                        child: Text(item.title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
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

  Widget _buildReviews(TechnicianProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        const SizedBox(height: 12),
        if (p.reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
            child: Center(child: Text('No reviews yet', style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant))),
          )
        else
          ...p.reviews.map((r) => Container(
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
                      child: ClipOval(child: r.reviewerPhoto != null
                        ? Image.network(r.reviewerPhoto!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _reviewInitial(r.reviewerName))
                        : _reviewInitial(r.reviewerName))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.reviewerName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                      Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 12, color: AppColors.neonAccent))),
                    ])),
                    if (r.timeAgo.isNotEmpty) Text(r.timeAgo, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  ],
                ),
                if (r.comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('"${r.comment}"', style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, height: 1.5, color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          )),
      ],
    );
  }

  Widget _buildActionBar(TechnicianProfile p) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: p.id, otherUserName: p.name, otherUserRole: 'technician'))),
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
              onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (context) => _BookingBottomSheet(technician: p)),
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

class _BookingBottomSheet extends StatefulWidget {
  final TechnicianProfile technician;
  const _BookingBottomSheet({required this.technician});
  @override
  State<_BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<_BookingBottomSheet> {
  final _problemController = TextEditingController();
  final _priceController = TextEditingController();
  String _urgency = 'Standard';
  bool _submitting = false;

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295; var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _submitRequest() async {
    if (_problemController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");
      final prefs = await SharedPreferences.getInstance();
      final userLat = prefs.getDouble('cachedLat') ?? 0.0;
      final userLng = prefs.getDouble('cachedLng') ?? 0.0;
      final techDoc = await FirebaseFirestore.instance.collection('users').doc(widget.technician.id).get();
      final techData = techDoc.data() ?? {};
      final dynamic latRaw = techData['lat'] ?? techData['location']?['lat'];
      final dynamic lngRaw = techData['lng'] ?? techData['location']?['lng'];
      final techLat = (latRaw as num?)?.toDouble() ?? 0.0;
      final techLng = (lngRaw as num?)?.toDouble() ?? 0.0;
      final distance = _calculateDistance(userLat, userLng, techLat, techLng);
      final jobRef = FirebaseFirestore.instance.collection('jobs').doc();
      await jobRef.set({
        'jobId': jobRef.id, 'userId': user.uid, 'technicianId': widget.technician.id,
        'problemDescription': _problemController.text.trim(), 'urgency': _urgency, 'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(), 'userLat': userLat, 'userLng': userLng,
        'technicianLat': techLat, 'technicianLng': techLng, 'distance': distance,
        if (_priceController.text.trim().isNotEmpty) 'estimatedPrice': _priceController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request sent to ${widget.technician.name}!'),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.divider)),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Book ${widget.technician.name}', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant)),
          ]),
          const SizedBox(height: 16),
          Text('Problem Description', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _problemController, maxLines: 3,
            style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe what needs fixing...', hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          // Urgency chips
          Text('Urgency', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: ['Standard', 'Urgent', 'Emergency'].map((u) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _urgency = u),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _urgency == u ? AppColors.neonAccent : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _urgency == u ? AppColors.neonAccent : AppColors.divider),
                ),
                child: Text(u, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _urgency == u ? AppColors.onPrimary : AppColors.onSurfaceVariant)),
              ),
            ),
          )).toList()),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonAccent, foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2))
                : Text('Send Request', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
