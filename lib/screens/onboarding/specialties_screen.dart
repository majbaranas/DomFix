import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/technician_onboarding_data.dart';
import '../../theme/app_colors.dart';
import '../../utils/technician_specialty_catalog.dart';

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

  const SpecialtiesScreen({
    super.key,
    required this.onboardingData,
  });

  @override
  State<SpecialtiesScreen> createState() => SpecialtiesScreenState();
}

class SpecialtiesScreenState extends State<SpecialtiesScreen>
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
    final normalized = TechnicianSpecialtyCatalog.normalize(text);
    if (normalized == null) {
      _showSnackBar('Choose a smart-home or electrical specialty from the list.', isError: true);
      _customController.clear();
      return;
    }
    if (_customSkills.contains(normalized)) {
      _customController.clear();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _customSkills.add(normalized);
      _customController.clear();
    });
  }

  void _removeCustomSkill(String skill) {
    HapticFeedback.lightImpact();
    setState(() => _customSkills.remove(skill));
  }

  bool validate() {
    final totalSelected = _selected.length + _customSkills.length;
    if (totalSelected == 0) {
      _showSnackBar('Please select at least one specialty.', isError: true);
      return false;
    }
    return true;
  }

  void save() {
    widget.onboardingData
      ..specialties = TechnicianSpecialtyCatalog.normalizeList(_selected)
      ..customSkills = TechnicianSpecialtyCatalog.normalizeList(_customSkills);
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
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
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
    );
  }



  // ── Skill list ────────────────────────────────────────────────────────────

  Widget _buildSkillList() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.9,
      children: _predefinedSkills.map((skill) {
        final isSelected = _selected.contains(skill.name);
        return _SkillChip(
          skill: skill,
          isSelected: isSelected,
          onTap: () => _toggle(skill.name),
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
          'ADDITIONAL SPECIALTY',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 12),
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
                  hintText: 'Type an approved specialty...',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.outlineVariant, width: 1.5),
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
            SizedBox(width: 8),
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
              SizedBox(width: 6),
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
          SizedBox(width: 12),
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryContainer.withValues(alpha: 0.8)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryContainer.withValues(alpha: 0.15)
                        : const Color(0xFF2A2E35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    skill.icon,
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('check'),
                          color: AppColors.primaryContainer,
                          size: 24,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          key: const ValueKey('add'),
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                          size: 24,
                        ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (skill.badge != null) ...[
                  SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer.withValues(alpha: 0.2)
                          : const Color(0xFF31353B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      skill.badge!.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: isSelected
                            ? AppColors.primaryContainer
                            : AppColors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
