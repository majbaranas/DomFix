import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/technician_onboarding_data.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step 6 – Profile Audit Complete (Final Screen)
// ─────────────────────────────────────────────────────────────────────────────

class ProfileAuditScreen extends StatefulWidget {
  final TechnicianOnboardingData onboardingData;

  /// Called when the user taps "Finish & Go to Dashboard".
  final VoidCallback? onFinish;

  /// Called when user taps BACK.
  final VoidCallback? onBack;

  const ProfileAuditScreen({
    super.key,
    required this.onboardingData,
    this.onFinish,
    this.onBack,
  });

  @override
  State<ProfileAuditScreen> createState() => _ProfileAuditScreenState();
}

class _ProfileAuditScreenState extends State<ProfileAuditScreen>
    with TickerProviderStateMixin {
  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _fadeController;
  late AnimationController _arcController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _arcAnim;
  late Animation<double> _checklistAnim;

  // ── Computed profile score ─────────────────────────────────────────────────
  late double _strengthPercent;
  late List<_CheckItem> _checkItems;
  late List<_TipCard> _tips;

  @override
  void initState() {
    super.initState();
    _computeStrength();

    // Fade + slide in
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController, curve: Curves.easeOut));

    // Arc counter animation
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _arcAnim = Tween<double>(begin: 0, end: _strengthPercent / 100).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeOut));
    _checklistAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _arcController,
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
    super.dispose();
  }

  // ── Profile strength computation ───────────────────────────────────────────

  void _computeStrength() {
    final d = widget.onboardingData;
    int score = 0;
    int maxScore = 0;

    // Each section has a max contribution
    _checkItems = [];
    _tips = [];

    // Profile photo (20pts)
    maxScore += 20;
    if (d.profilePhotoUrl != null && d.profilePhotoUrl!.isNotEmpty) {
      score += 20;
      _checkItems.add(const _CheckItem(label: 'Profile Photo', done: true));
    } else {
      _checkItems.add(const _CheckItem(label: 'Profile Photo', done: false));
      _tips.add(const _TipCard(
        tag: 'Action Needed',
        boost: '+20%',
        title: 'Add Profile Photo',
        description: 'Profiles with photos receive 3x more client views.',
        cta: 'Upload Photo',
      ));
    }

    // Specialties (20pts)
    maxScore += 20;
    final hasSkills = d.specialties.isNotEmpty || d.customSkills.isNotEmpty;
    if (hasSkills) {
      score += 20;
      _checkItems.add(const _CheckItem(label: 'Skills Verified', done: true));
    } else {
      _checkItems.add(const _CheckItem(label: 'Skills Verified', done: false));
      _tips.add(const _TipCard(
        tag: 'Action Needed',
        boost: '+20%',
        title: 'Select Specialties',
        description: 'Select at least 3 specialties to be matched faster.',
        cta: 'Add Skills',
      ));
    }

    // Experience / portfolio (20pts)
    maxScore += 20;
    final hasExperience =
        d.yearsOfExperience > 0 || d.portfolioImages.isNotEmpty;
    if (hasExperience) {
      score += 20;
      _checkItems.add(
          const _CheckItem(label: 'Experience Logs', done: true));
    } else {
      _checkItems.add(
          const _CheckItem(label: 'Experience Logs', done: false));
      _tips.add(const _TipCard(
        tag: 'Recommendation',
        boost: '+15%',
        title: 'Add Certifications',
        description:
            'Users with valid HVAC or Electrical certs receive 2.4x more invitations.',
        cta: 'Upload Now',
      ));
    }

    // Identity verification (20pts)
    maxScore += 20;
    if (d.identityDocumentUrl != null) {
      score += 20;
      _checkItems
          .add(const _CheckItem(label: 'Identity Verification', done: true));
    } else {
      _checkItems
          .add(const _CheckItem(label: 'Identity Verification', done: false));
      _tips.add(const _TipCard(
        tag: 'Action Needed',
        boost: '+15%',
        title: 'Verify Identity',
        description:
            'Verified techs rank 40% higher in search results.',
        cta: 'Verify Now',
      ));
    }

    // Availability (20pts)
    maxScore += 20;
    if (d.availableDays.isNotEmpty) {
      score += 20;
    } else {
      _tips.add(const _TipCard(
        tag: 'Recommendation',
        boost: '+10%',
        title: 'Complete Availability',
        description:
            'Setting your weekly schedule helps our AI match you with instant jobs.',
        cta: 'Open Calendar',
      ));
    }

    // If no tips, add a generic boost tip
    if (_tips.isEmpty) {
      _tips.add(const _TipCard(
        tag: 'Pro Tip',
        boost: '+5%',
        title: 'Request Client Reviews',
        description:
            'After your first job, ask clients for a review to boost your rank.',
        cta: 'Learn More',
      ));
    }

    _strengthPercent =
        maxScore > 0 ? (score / maxScore * 100).clamp(0, 100) : 0;
  }

  String get _tierLabel {
    if (_strengthPercent >= 90) return 'Gold Tier';
    if (_strengthPercent >= 60) return 'Silver Tier';
    return 'Bronze Tier';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background glow decorations
          _buildBackgroundGlow(),

          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                      children: [
                        _buildProgressBar(),
                        const SizedBox(height: 28),
                        _buildHeroHeader(),
                        const SizedBox(height: 32),
                        _buildStrengthCard(),
                        const SizedBox(height: 20),
                        _buildChecklist(),
                        const SizedBox(height: 28),
                        _buildBoostPanel(),
                        const SizedBox(height: 24),
                        _buildFinishCTA(),
                        const SizedBox(height: 12),
                        _buildTermsNote(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Background glow ────────────────────────────────────────────────────────

  Widget _buildBackgroundGlow() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2,
              left: -60,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withValues(alpha: 0.025),
                ),
              ),
            ),
            Positioned(
              bottom: 80, right: -40,
              child: Container(
                width: 240, height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withValues(alpha: 0.015),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 16, bottom: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); widget.onBack?.call(); },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.arrow_back,
                  color: AppColors.primaryContainer, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Text('DOMFIX_CORE',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1,
            )),
          const Spacer(),
          Text('STEP 6 / 6',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 2,
            )),
          const SizedBox(width: 12),
          Icon(Icons.more_vert, color: AppColors.onSurface, size: 22),
        ],
      ),
    );
  }

  // ── 100% progress bar ──────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.4),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'SYSTEM READY.\n',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white, fontSize: 36,
                  fontWeight: FontWeight.w800, height: 1.1,
                ),
              ),
              TextSpan(
                text: 'PROFILE AUDIT\nCOMPLETE',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.primaryContainer, fontSize: 36,
                  fontWeight: FontWeight.w800, height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your professional profile is calibrated for the DOMFIX network. Finish the final optimization steps to maximize job visibility.',
          style: GoogleFonts.inter(
            color: AppColors.onSurfaceVariant, fontSize: 14, height: 1.65),
        ),
      ],
    );
  }

  // ── Radial strength card ───────────────────────────────────────────────────

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
              width: 120, height: 120,
              child: CustomPaint(
                painter: _ArcPainter(progress: _arcAnim.value),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_arcAnim.value * 100).round()}%',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('STRENGTH',
                        style: GoogleFonts.inter(
                          color: AppColors.onSurfaceVariant, fontSize: 8,
                          letterSpacing: 1.5, fontWeight: FontWeight.w600,
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
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5,
                  )),
                const SizedBox(height: 8),
                Text(
                  'You\'ve surpassed the required 60% threshold for active bidding. You are currently in the ',
                  style: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12, height: 1.6,
                  ),
                ),
                Text(_tierLabel,
                  style: GoogleFonts.inter(
                    color: AppColors.onSurface, fontSize: 12,
                    fontStyle: FontStyle.italic, fontWeight: FontWeight.w600,
                  )),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2025),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Text('Priority Status: Active',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.primaryContainer, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Completion checklist ───────────────────────────────────────────────────

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
                color: item.done ? AppColors.onSurface : AppColors.onSurfaceVariant,
                fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5,
              )),
          ),
        ],
      ),
    );
  }

  // ── Boost your impact panel ────────────────────────────────────────────────

  Widget _buildBoostPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF262A30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF454932).withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: AppColors.primaryContainer, size: 20),
              const SizedBox(width: 8),
              Text('BOOST YOUR IMPACT',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.onSurface, fontSize: 13,
                  fontWeight: FontWeight.w800, letterSpacing: 1,
                )),
            ],
          ),
          const SizedBox(height: 16),
          ..._tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTipCard(tip),
          )),
        ],
      ),
    );
  }

  Widget _buildTipCard(_TipCard tip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.06), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tip.tag.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.primaryContainer, fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 2,
                )),
              Text(tip.boost,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.primaryContainer, fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
            ],
          ),
          const SizedBox(height: 6),
          Text(tip.title,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w700,
            )),
          const SizedBox(height: 4),
          Text(tip.description,
            style: GoogleFonts.inter(
              color: AppColors.onSurfaceVariant, fontSize: 12, height: 1.55)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(tip.cta.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.primaryContainer, fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5,
                )),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward,
                  color: AppColors.primaryContainer, size: 12),
            ],
          ),
        ],
      ),
    );
  }

  // ── Finish CTA ─────────────────────────────────────────────────────────────

  Widget _buildFinishCTA() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onFinish?.call();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              blurRadius: 30, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text('FINISH & GO TO DASHBOARD',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF181E00),
              fontWeight: FontWeight.w800,
              fontSize: 13, letterSpacing: 2.5,
            )),
        ),
      ),
    );
  }

  Widget _buildTermsNote() {
    return Center(
      child: Text(
        'TERMS & VERIFICATION CONDITIONS APPLY',
        style: GoogleFonts.inter(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: Border(top: BorderSide(
          color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); widget.onBack?.call(); },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left,
                    color: Colors.white.withValues(alpha: 0.6), size: 22),
                const SizedBox(height: 2),
                Text('BACK',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10, fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  )),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onFinish?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  blurRadius: 20, offset: const Offset(0, 6),
                )],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: const Color(0xFF2B3400), size: 20),
                  const SizedBox(height: 2),
                  Text('FINISH',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF2B3400),
                      fontWeight: FontWeight.w800,
                      fontSize: 11, letterSpacing: 2,
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom arc painter for the radial strength chart
// ─────────────────────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0

  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = -math.pi / 2; // top
    final sweepAngle = 2 * math.pi * progress;

    // Background track
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = const Color(0xFF31353B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Glow
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false,
        Paint()
          ..color = const Color(0xFFD9FF00).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Foreground arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false,
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

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class _CheckItem {
  final String label;
  final bool done;
  const _CheckItem({required this.label, required this.done});
}

class _TipCard {
  final String tag;
  final String boost;
  final String title;
  final String description;
  final String cta;
  const _TipCard({
    required this.tag,
    required this.boost,
    required this.title,
    required this.description,
    required this.cta,
  });
}
