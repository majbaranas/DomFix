import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/technician_onboarding_data.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a predefined skill
// ─────────────────────────────────────────────────────────────────────────────

class _Skill {
  final String name;
  final IconData icon;
  final String? badge; // e.g. "High Demand"

  const _Skill({required this.name, required this.icon, this.badge});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SpecialtiesScreen extends StatefulWidget {
  final TechnicianOnboardingData onboardingData;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const SpecialtiesScreen({
    super.key,
    required this.onboardingData,
    this.onNext,
    this.onBack,
  });

  @override
  State<SpecialtiesScreen> createState() => _SpecialtiesScreenState();
}

class _SpecialtiesScreenState extends State<SpecialtiesScreen>
    with SingleTickerProviderStateMixin {
  // ── Predefined skills ────────────────────────────────────────────────────
  static const List<_Skill> _predefinedSkills = [
    _Skill(name: 'Smart Home', icon: Icons.nest_cam_wired_stand, badge: 'High Demand'),
    _Skill(name: 'Electrical Installation', icon: Icons.electrical_services),
    _Skill(name: 'Solar Panels', icon: Icons.solar_power, badge: 'Growing'),
    _Skill(name: 'CCTV & Security', icon: Icons.security),
    _Skill(name: 'Networking', icon: Icons.router),
    _Skill(name: 'WiFi & Routers', icon: Icons.wifi),
    _Skill(name: 'Home Automation', icon: Icons.smart_toy),
    _Skill(name: 'Lighting Systems', icon: Icons.lightbulb),
    _Skill(name: 'Energy Monitoring', icon: Icons.energy_savings_leaf),
    _Skill(name: 'IoT Systems', icon: Icons.devices_other),
    _Skill(name: 'Access Control', icon: Icons.door_front_door),
    _Skill(name: 'Intercom Systems', icon: Icons.record_voice_over),
  ];

  // ── State ────────────────────────────────────────────────────────────────
  late Set<String> _selected;
  final _customController = TextEditingController();
  late List<String> _customSkills;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.onboardingData.specialties);
    _customSkills = List.from(widget.onboardingData.customSkills);

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
    _customController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _toggle(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  void _addCustomSkill() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    if (_customSkills.contains(text)) {
      _customController.clear();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _customSkills.add(text);
      _customController.clear();
    });
  }

  void _removeCustomSkill(String skill) {
    HapticFeedback.lightImpact();
    setState(() => _customSkills.remove(skill));
  }

  void _handleNext() {
    final totalSelected = _selected.length + _customSkills.length;
    if (totalSelected == 0) {
      _showSnackBar('Please select at least one specialty.', isError: true);
      return;
    }
    widget.onboardingData
      ..specialties = _selected.toList()
      ..customSkills = List.from(_customSkills);
    HapticFeedback.mediumImpact();
    widget.onNext?.call();
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  children: [
                    _buildProgressSection(),
                    const SizedBox(height: 28),
                    _buildSkillList(),
                    const SizedBox(height: 32),
                    _buildCustomInput(),
                    if (_customSkills.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildCustomSkillChips(),
                    ],
                    const SizedBox(height: 28),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onBack?.call();
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.arrow_back,
                  color: AppColors.primaryContainer, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'DOMFIX_CORE',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.more_vert,
                  color: AppColors.onSurface, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress section ──────────────────────────────────────────────────────

  Widget _buildProgressSection() {
    final count = _selected.length + _customSkills.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP 02 OF 06',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'What are your\nspecialties?',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '33%',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.primaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count selected',
                    style: GoogleFonts.inter(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF31353B),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          FractionallySizedBox(
            widthFactor: 0.33,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Skill list ────────────────────────────────────────────────────────────

  Widget _buildSkillList() {
    return Column(
      children: _predefinedSkills.map((skill) {
        final isSelected = _selected.contains(skill.name);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SkillChip(
            skill: skill,
            isSelected: isSelected,
            onTap: () => _toggle(skill.name),
          ),
        );
      }).toList(),
    );
  }

  // ── Custom skill input ────────────────────────────────────────────────────

  Widget _buildCustomInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OTHER EXPERTISE',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                style: GoogleFonts.inter(
                    color: AppColors.onSurface, fontSize: 14),
                cursorColor: AppColors.primaryContainer,
                onSubmitted: (_) => _addCustomSkill(),
                decoration: InputDecoration(
                  hintText: 'Add custom skill...',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: Color(0xFF454932), width: 1.5),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.primaryContainer, width: 2),
                  ),
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addCustomSkill,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add,
                    color: AppColors.primaryContainer, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Custom skill chips (added) ────────────────────────────────────────────

  Widget _buildCustomSkillChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _customSkills.map((skill) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                skill,
                style: GoogleFonts.inter(
                  color: AppColors.primaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeCustomSkill(skill),
                child: Icon(Icons.close,
                    size: 14, color: AppColors.primaryContainer),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181C21),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              color: AppColors.primaryContainer, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Selecting at least 3 specialties increases your match rate by up to 45%. You can adjust these later in your profile settings.',
              style: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onBack?.call();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left,
                    color: Colors.white.withValues(alpha: 0.6), size: 22),
                const SizedBox(height: 2),
                Text(
                  'BACK',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _handleNext,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: const Color(0xFF2B3400), size: 18),
                  const SizedBox(height: 2),
                  Text(
                    'NEXT',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF2B3400),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
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
// Skill Chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _SkillChip extends StatelessWidget {
  final _Skill skill;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkillChip({
    required this.skill,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF181C21),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.12),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon container
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer.withValues(alpha: 0.15)
                    : const Color(0xFF31353B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                skill.icon,
                color: isSelected
                    ? AppColors.primaryContainer
                    : AppColors.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),

            // Name + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? AppColors.primaryContainer
                          : AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (skill.badge != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      skill.badge!.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: isSelected
                            ? AppColors.primaryContainer.withValues(alpha: 0.7)
                            : AppColors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Trailing check / add
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(
                      Icons.check_circle,
                      key: const ValueKey('check'),
                      color: AppColors.primaryContainer,
                      size: 22,
                    )
                  : Icon(
                      Icons.add_circle_outline,
                      key: const ValueKey('add'),
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                      size: 22,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
