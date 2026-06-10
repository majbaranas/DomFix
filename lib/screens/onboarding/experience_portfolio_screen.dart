import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/technician_onboarding_data.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 – Experience & Portfolio
// ─────────────────────────────────────────────────────────────────────────────

class ExperiencePortfolioScreen extends StatefulWidget {
  final TechnicianOnboardingData onboardingData;

  const ExperiencePortfolioScreen({
    super.key,
    required this.onboardingData,
  });

  @override
  State<ExperiencePortfolioScreen> createState() =>
      ExperiencePortfolioScreenState();
}

class ExperiencePortfolioScreenState extends State<ExperiencePortfolioScreen>
    with SingleTickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  double _yearsSlider = 0;

  // Certifications
  bool _certUploading = false;
  String? _certError;

  // Portfolio
  bool _portfolioUploading = false;
  String? _portfolioError;

  final _picker = ImagePicker();

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _yearsSlider = widget.onboardingData.yearsOfExperience.toDouble();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Certification upload
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickAndUploadCertification() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _certUploading = true;
        _certError = null;
      });

      HapticFeedback.lightImpact();
      final file = File(picked.path);
      final cloudinaryService = CloudinaryService();
      final url = await cloudinaryService.uploadImage(
        imageFile: file,
        chatId: 'certifications',
        compress: false,
      );
      final fileName = picked.name;

      if (!mounted) return;
      setState(() {
        _certUploading = false;
        widget.onboardingData.certifications.add(
          UploadedFile(url: url, fileName: fileName),
        );
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _certUploading = false;
        _certError = 'Upload failed. Please try again.';
      });
    }
  }

  void _removeCertification(int index) {
    HapticFeedback.lightImpact();
    setState(
        () => widget.onboardingData.certifications.removeAt(index));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Portfolio upload
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickAndUploadPortfolio() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (picked == null) return;

      setState(() {
        _portfolioUploading = true;
        _portfolioError = null;
      });

      HapticFeedback.lightImpact();
      final file = File(picked.path);
      final cloudinaryService = CloudinaryService();
      final url = await cloudinaryService.uploadImage(
        imageFile: file,
        chatId: 'portfolio',
        compress: true,
      );
      final fileName = picked.name;

      if (!mounted) return;
      setState(() {
        _portfolioUploading = false;
        widget.onboardingData.portfolioImages.add(
          UploadedFile(url: url, fileName: fileName),
        );
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _portfolioUploading = false;
        _portfolioError = 'Upload failed. Please try again.';
      });
    }
  }

  void _removePortfolioImage(int index) {
    HapticFeedback.lightImpact();
    setState(
        () => widget.onboardingData.portfolioImages.removeAt(index));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────────

  bool validate() {
    if (_certUploading || _portfolioUploading) {
      _showSnackBar('Please wait for uploads to complete.', isError: true);
      return false;
    }
    return true;
  }

  void save() {
    widget.onboardingData.yearsOfExperience = _yearsSlider.round();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor:
            isError ? const Color(0xFF93000A) : AppColors.primaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _yearsLabel(double value) {
    final v = value.round();
    if (v == 0) return 'Entry Level';
    if (v >= 30) return '30+ yrs';
    return '$v${v > 11 ? "+" : ""} yr${v == 1 ? "" : "s"}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            _buildExperienceSection(),
            const SizedBox(height: 28),
            _buildCertificationsSection(),
            const SizedBox(height: 28),
            _buildPortfolioSection(),
          ],
        ),
      ),
    );
  }

  // ── Experience slider ─────────────────────────────────────────────────────

  Widget _buildExperienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, color: AppColors.primaryContainer, size: 20),
            const SizedBox(width: 8),
            Text(
              'EXPERIENCE & EXPERTISE',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF181C21),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2A2E35), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    flex: 1,
                    child: Text(
                      'YEARS IN FIELD',
                      style: GoogleFonts.inter(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _yearsLabel(_yearsSlider),
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.primaryContainer,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: AppColors.primaryContainer.withValues(alpha: 0.4),
                              blurRadius: 16,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primaryContainer,
                  inactiveTrackColor: const Color(0xFF2A2E35),
                  thumbColor: AppColors.primaryContainer,
                  overlayColor: AppColors.primaryContainer.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12, elevation: 6),
                  trackHeight: 6,
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 24),
                ),
                child: Slider(
                  value: _yearsSlider,
                  min: 0,
                  max: 30,
                  divisions: 30,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _yearsSlider = v);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  'ENTRY LEVEL',
                  'MID LEVEL',
                  'SENIOR EXPERT',
                ].map((label) {
                  return Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Certifications ────────────────────────────────────────────────────────

  Widget _buildCertificationsSection() {
    final certs = widget.onboardingData.certifications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload card
        GestureDetector(
          onTap: _certUploading ? null : _pickAndUploadCertification,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF181C21),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _certError != null
                    ? const Color(0xFFFFB4AB)
                    : const Color(0xFF31353B).withValues(alpha: 0.5),
                style: BorderStyle.solid,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: _certUploading
                      ? Padding(
                          padding: const EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryContainer),
                          ),
                        )
                      : Icon(Icons.upload_file,
                          color: AppColors.primaryContainer, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  _certUploading
                      ? 'UPLOADING...'
                      : 'UPLOAD CERTIFICATIONS',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap to select professional licenses\nor PDF certifications.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                if (_certError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _certError!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFB4AB),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),

        // Uploaded certs list
        if (certs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'RECENT UPLOADS',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...certs.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _UploadedFileRow(
                file: entry.value,
                onRemove: () => _removeCertification(entry.key),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ── Portfolio gallery ─────────────────────────────────────────────────────

  Widget _buildPortfolioSection() {
    final images = widget.onboardingData.portfolioImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view,
                    color: AppColors.primaryContainer, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PAST PROJECT PORTFOLIO',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            if (images.isNotEmpty)
              GestureDetector(
                onTap: _portfolioUploading ? null : _pickAndUploadPortfolio,
                child: Text(
                  'ADD MORE',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.primaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPortfolioGrid(images),
        if (_portfolioError != null) ...[
          const SizedBox(height: 8),
          Text(
            _portfolioError!,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFB4AB),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPortfolioGrid(List<UploadedFile> images) {
    // Build a grid: image thumbnails + "add" tile
    final allTiles = [
      ...images.asMap().entries.map((e) => _ImageTile(
            file: e.value,
            onRemove: () => _removePortfolioImage(e.key),
          )),
      _AddPhotoTile(
        isLoading: _portfolioUploading,
        onTap: _portfolioUploading ? null : _pickAndUploadPortfolio,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: allTiles,
    );
  }


}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _UploadedFileRow extends StatelessWidget {
  final UploadedFile file;
  final VoidCallback onRemove;

  const _UploadedFileRow({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF31353B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.description,
                color: AppColors.primaryContainer, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  style: GoogleFonts.inter(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'UPLOADED',
                  style: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close,
                color: AppColors.onSurfaceVariant, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Portfolio image tile ──────────────────────────────────────────────────────

class _ImageTile extends StatelessWidget {
  final UploadedFile file;
  final VoidCallback onRemove;

  const _ImageTile({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            file.url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFF262A30),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryContainer),
                  ),
                ),
              );
            },
          ),
        ),

        // Dark overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),

        // Remove button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Add photo tile ────────────────────────────────────────────────────────────

class _AddPhotoTile extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _AddPhotoTile({required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181C21),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF31353B).withValues(alpha: 0.5),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryContainer),
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: AppColors.onSurfaceVariant, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'ADD PROJECT',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
