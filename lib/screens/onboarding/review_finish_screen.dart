import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/technician_onboarding_data.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';

enum _DocUploadState { idle, uploading, success, error }

class ReviewFinishScreen extends StatefulWidget {
  final TechnicianOnboardingData onboardingData;

  const ReviewFinishScreen({
    super.key,
    required this.onboardingData,
  });

  @override
  State<ReviewFinishScreen> createState() => ReviewFinishScreenState();
}

class ReviewFinishScreenState extends State<ReviewFinishScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  bool _phoneVerified = false;
  bool _verifyingPhone = false;

  _DocUploadState _idUploadState = _DocUploadState.idle;
  String? _idDocLabel; // "Passport" or "ID Card"
  String? _idError;

  final _picker = ImagePicker();

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _fadeController;
  late AnimationController _arcController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _arcAnim;
  late Animation<double> _checklistAnim;

  late double _strengthPercent;
  late List<_CheckItem> _checkItems;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.onboardingData.phoneNumber ?? '';
    _phoneVerified = widget.onboardingData.isPhoneVerified;

    if (widget.onboardingData.identityDocumentUrl != null) {
      _idUploadState = _DocUploadState.success;
    }

    _computeStrength();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _arcAnim = Tween<double>(begin: 0, end: _strengthPercent / 100).animate(
        CurvedAnimation(parent: _arcController, curve: Curves.easeOut));
    _checklistAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _arcController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _arcController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _arcController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _computeStrength() {
    final d = widget.onboardingData;
    int score = 0;
    int maxScore = 0;

    _checkItems = [];

    // Profile photo (20pts)
    maxScore += 20;
    if (d.profilePhotoUrl != null && d.profilePhotoUrl!.isNotEmpty) {
      score += 20;
      _checkItems.add(const _CheckItem(label: 'Profile Photo', done: true));
    } else {
      _checkItems.add(const _CheckItem(label: 'Profile Photo', done: false));
    }

    // Specialties (20pts)
    maxScore += 20;
    final hasSkills = d.specialties.isNotEmpty || d.customSkills.isNotEmpty;
    if (hasSkills) {
      score += 20;
      _checkItems.add(const _CheckItem(label: 'Skills Verified', done: true));
    } else {
      _checkItems.add(const _CheckItem(label: 'Skills Verified', done: false));
    }

    // Experience / portfolio (20pts)
    maxScore += 20;
    final hasExperience =
        d.yearsOfExperience > 0 || d.portfolioImages.isNotEmpty;
    if (hasExperience) {
      score += 20;
      _checkItems.add(const _CheckItem(label: 'Experience Logs', done: true));
    } else {
      _checkItems.add(const _CheckItem(label: 'Experience Logs', done: false));
    }

    // Identity verification (20pts)
    maxScore += 20;
    if (_idUploadState == _DocUploadState.success) {
      score += 20;
      _checkItems
          .add(const _CheckItem(label: 'Identity Verification', done: true));
    } else {
      _checkItems
          .add(const _CheckItem(label: 'Identity Verification', done: false));
    }

    // Availability (20pts)
    maxScore += 20;
    if (d.availableDays.isNotEmpty) {
      score += 20;
    }

    _strengthPercent =
        maxScore > 0 ? (score / maxScore * 100).clamp(0, 100) : 0;
  }

  String get _tierLabel {
    if (_strengthPercent >= 90) return 'Gold Tier';
    if (_strengthPercent >= 60) return 'Silver Tier';
    return 'Bronze Tier';
  }

  // ── Methods ──────────────────────────────────────────────────────────────

  Future<void> _uploadIdDocument(String docType) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _idUploadState = _DocUploadState.uploading;
        _idDocLabel = docType;
        _idError = null;
      });
      HapticFeedback.lightImpact();

      final cloudinaryService = CloudinaryService();
      final url = await cloudinaryService.uploadImage(
        imageFile: File(picked.path),
        chatId: 'identity_documents',
        compress: false,
      );

      if (!mounted) return;
      setState(() {
        _idUploadState = _DocUploadState.success;
        widget.onboardingData.identityDocumentUrl = url;
        _computeStrength();
        _arcController.reset();
        _arcAnim = Tween<double>(begin: 0, end: _strengthPercent / 100).animate(
            CurvedAnimation(parent: _arcController, curve: Curves.easeOut));
        _arcController.forward();
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _idUploadState = _DocUploadState.error;
        _idError = 'Upload failed. Please try again.';
      });
    }
  }

  Future<void> _verifyPhone() async {
    final number = _phoneController.text.trim();
    if (number.isEmpty) {
      _showSnackBar('Please enter your phone number.', isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _verifyingPhone = true);
    // Stub: replace with real OTP flow
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _verifyingPhone = false;
      _phoneVerified = true;
      widget.onboardingData.isPhoneVerified = true;
      widget.onboardingData.phoneNumber = number;
    });
    _showSnackBar('Phone verified successfully!');
    HapticFeedback.lightImpact();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor:
          isError ? const Color(0xFF93000A) : AppColors.primaryContainer,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  bool validate() {
    if (_idUploadState == _DocUploadState.uploading || _verifyingPhone) {
      _showSnackBar('Please wait for verification to complete.', isError: true);
      return false;
    }
    if (_idUploadState != _DocUploadState.success) {
      _showSnackBar('Please upload an identity document.', isError: true);
      return false;
    }
    if (!_phoneVerified) {
      _showSnackBar('Please verify your phone number.', isError: true);
      return false;
    }
    return true;
  }

  void save() {
    widget.onboardingData.phoneNumber = _phoneController.text.trim();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            _buildStrengthCard(),
            const SizedBox(height: 20),
            _buildChecklist(),
            const SizedBox(height: 32),
            _buildIdentityCard(),
            const SizedBox(height: 20),
            _buildPhoneCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Animated radial arc
          AnimatedBuilder(
            animation: _arcAnim,
            builder: (context, child) => SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: _ArcPainter(progress: _arcAnim.value),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_arcAnim.value * 100).round()}%',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('STRENGTH',
                          style: GoogleFonts.inter(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 8,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PROFILE STRENGTH',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 8),
                Text(
                  'Complete verification steps to unlock maximum bidding visibility. You are currently in the ',
                  style: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                Text(_tierLabel,
                    style: GoogleFonts.inter(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2025),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Text('Verification Status: Pending',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.primaryContainer,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    return AnimatedBuilder(
      animation: _checklistAnim,
      builder: (context, child) => Column(
        children: [
          Row(
            children: [
              if (_checkItems.length > 1) ...[
                Expanded(child: _checkTile(_checkItems[0])),
                const SizedBox(width: 12),
                Expanded(child: _checkTile(_checkItems[1])),
              ],
            ],
          ),
          if (_checkItems.length > 2) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_checkItems.length > 2)
                  Expanded(child: _checkTile(_checkItems[2])),
                const SizedBox(width: 12),
                if (_checkItems.length > 3)
                  Expanded(child: _checkTile(_checkItems[3]))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _checkTile(_CheckItem item) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2025),
        borderRadius: BorderRadius.circular(12),
        border: item.done
            ? Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                width: 1)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            item.done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: item.done
                ? AppColors.primaryContainer
                : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.label,
                style: GoogleFonts.inter(
                  color: item.done
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    final isUploaded = _idUploadState == _DocUploadState.success;
    final isUploading = _idUploadState == _DocUploadState.uploading;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2025),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text('VERIFY IDENTITY',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.primaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              )),
                        ),
                        if (isUploaded) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle,
                              color: AppColors.primaryContainer, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Official document required for security audit.',
                        style: GoogleFonts.inter(
                            color: AppColors.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.shield_outlined,
                  color: AppColors.onSurfaceVariant, size: 22),
            ],
          ),
          if (isUploaded) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user,
                      color: AppColors.primaryContainer, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_idDocLabel ?? "Document"} uploaded successfully',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.primaryContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _idUploadState = _DocUploadState.idle;
                      widget.onboardingData.identityDocumentUrl = null;
                      _computeStrength();
                      _arcController.reset();
                      _arcAnim = Tween<double>(begin: 0, end: _strengthPercent / 100).animate(
                          CurvedAnimation(parent: _arcController, curve: Curves.easeOut));
                      _arcController.forward();
                    }),
                    child: Icon(Icons.close,
                        color: AppColors.onSurfaceVariant, size: 16),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _docButton(
                    icon: Icons.add_a_photo_outlined,
                    label: 'PASSPORT',
                    isLoading: isUploading && _idDocLabel == 'Passport',
                    onTap: () => _uploadIdDocument('Passport'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _docButton(
                    icon: Icons.upload_file_outlined,
                    label: 'ID CARD',
                    isLoading: isUploading && _idDocLabel == 'ID Card',
                    onTap: () => _uploadIdDocument('ID Card'),
                  ),
                ),
              ],
            ),
            if (_idError != null) ...[
              const SizedBox(height: 8),
              Text(_idError!,
                  style: GoogleFonts.inter(
                      color: const Color(0xFFFFB4AB), fontSize: 11)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _docButton({
    required IconData icon,
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF262A30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF454932).withValues(alpha: 0.2), width: 1),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFD9FF00)),
                    )))
            : Column(
                children: [
                  Icon(icon, color: const Color(0xFFB4D400), size: 26),
                  const SizedBox(height: 8),
                  Text(label,
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.onSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      )),
                ],
              ),
      ),
    );
  }

  Widget _buildPhoneCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PHONE NUMBER',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  )),
              const Spacer(),
              if (_phoneVerified)
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.primaryContainer, size: 14),
                    const SizedBox(width: 4),
                    Text('VERIFIED',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.primaryContainer,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        )),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.primaryContainer, fontSize: 18),
            cursorColor: AppColors.primaryContainer,
            enabled: !_phoneVerified,
            decoration: InputDecoration(
              hintText: '+1 (555) 000-0000',
              hintStyle: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                fontSize: 16,
              ),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF454932), width: 1.5)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: AppColors.primaryContainer, width: 2)),
              disabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: AppColors.primaryContainer.withValues(alpha: 0.4),
                      width: 1.5)),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap:
                _phoneVerified ? null : (_verifyingPhone ? null : _verifyPhone),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _phoneVerified
                    ? AppColors.primaryContainer.withValues(alpha: 0.15)
                    : const Color(0xFF31353B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _verifyingPhone
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFD9FF00)),
                          )))
                  : Center(
                      child: Text(
                        _phoneVerified ? 'VERIFIED' : 'SEND OTP CODE',
                        style: GoogleFonts.spaceGrotesk(
                          color: _phoneVerified
                              ? AppColors.primaryContainer
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
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

class _ArcPainter extends CustomPainter {
  final double progress;

  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF31353B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = const Color(0xFFD9FF00).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = const Color(0xFFD9FF00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

class _CheckItem {
  final String label;
  final bool done;
  const _CheckItem({required this.label, required this.done});
}
