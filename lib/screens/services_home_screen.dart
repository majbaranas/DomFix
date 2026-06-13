import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/marketplace_technician.dart';
import '../services/technician_profile_service.dart';

import '../widgets/expert_card.dart';
import 'find_pros_screen.dart';
import 'technician_profile_screen.dart';

class ServicesHomeScreen extends StatefulWidget {
  const ServicesHomeScreen({super.key});
  @override
  State<ServicesHomeScreen> createState() => _ServicesHomeScreenState();
}

class _ServicesHomeScreenState extends State<ServicesHomeScreen>
    with TickerProviderStateMixin {
  int _selectedProtocol = 0;
  late AnimationController _pulseCtrl;

  final List<_Protocol> _protocols = const [
    _Protocol('Electrical', Icons.bolt),
    _Protocol('Lighting', Icons.light_outlined),
    _Protocol('Security', Icons.videocam_outlined),
    _Protocol('Network', Icons.router_outlined),
    _Protocol('Solar', Icons.solar_power_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E13),
      body: Stack(
        children: [
          _ambientGlow(),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 72)),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 24),
                    _buildNodeStatus(),
                    const SizedBox(height: 24),
                    _buildProtocols(),
                    const SizedBox(height: 24),
                    _buildTechnicians(),
                    const SizedBox(height: 24),
                    _buildEmergency(),
  Widget _ambientGlow() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 300,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.2,
            colors: [Color(0x0FCDF200), Colors.transparent],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              left: 24, right: 24, bottom: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF101419).withValues(alpha: 0.7),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      color: const Color(0xFF181C21),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCePo42411FCFBCJTkXFzJtvUTDhsyiXbeQ41hPxJCwXFX2ybTdz0HtfImW7fIZEruHKfGTUNtn_A2yleUMUDpTUsZV3LeRXl3ICZq_0f5pAmwsphnRxWJ0YKc1QoI7SLslL51mOEbMwHPkAhmkCQUFP6CrY9sxvX7_Iw5hpFcq3mrqiJ-9IAllQq4O1dGyynq5Axrzt3fkazlvAbdL6CM9eSISP-KlbYWfSjTBTb-65FE4n0iDaOMmJpnDX223-Y1QL2E_zbQQLJA',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 18, color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Good evening, Aymen',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.primaryFixed.withValues(alpha: 0.4), blurRadius: 8)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('System Online',
                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurface.withValues(alpha: 0.7))),
                      ]),
                    ],
                  ),
                ]),
                GestureDetector(
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.03),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      const Icon(Icons.notifications_outlined, size: 18, color: Color(0xFFE0E2EA)),
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.primaryFixed, blurRadius: 8)],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF101419).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 32, offset: const Offset(0, 8)),
                BoxShadow(color: Colors.white.withValues(alpha: 0.06), blurRadius: 0, offset: const Offset(0, 1), spreadRadius: -1),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  top: -64, right: -64,
                  child: Container(
                    width: 192, height: 192,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Command Center',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primaryFixed)),
                    const SizedBox(height: 8),
                    Text('Need expert\nassistance?',
                        style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white, height: 1.15, letterSpacing: -0.5)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
                      child: Row(children: [
                        _statItem('Node Latency', '18ms', false),
                        const SizedBox(width: 24),
                        _statItem('Power Grid', 'Stable', true),
                        const SizedBox(width: 24),
                        _statItem('Active Sys', '24', false),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, bool accent) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
          color: accent ? AppColors.primaryFixed : Colors.white)),
    ]);
  }

  Widget _buildNodeStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(child: _nodeCard(
          icon: Icons.router_outlined,
          iconColor: Colors.white.withValues(alpha: 0.7),
          iconBg: Colors.white.withValues(alpha: 0.03),
          iconBorder: Colors.white.withValues(alpha: 0.06),
          label: 'Network',
          value: 'Optimized',
          trailing: Icon(Icons.check_circle, color: AppColors.primaryFixed, size: 18),
        )),
        const SizedBox(width: 16),
        Expanded(child: _nodeCard(
          icon: Icons.bolt,
          iconColor: AppColors.primaryFixed,
          iconBg: AppColors.primaryFixed.withValues(alpha: 0.05),
          iconBorder: AppColors.primaryFixed.withValues(alpha: 0.2),
          label: 'Energy',
          value: '+12% Load',
          trailing: null,
        )),
      ]),
    );
  }

  Widget _nodeCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color iconBorder,
    required String label,
    required String value,
    required Widget? trailing,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101419).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg,
                      border: Border.all(color: iconBorder)),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
                ]),
              ]),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocols() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Protocols',
              style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _protocols.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final active = _selectedProtocol == i;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedProtocol = i);
                },
                child: SizedBox(
                  width: 80,
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: active ? AppColors.primaryFixed : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active ? AppColors.primaryFixed : Colors.white.withValues(alpha: 0.06),
                        ),
                        boxShadow: active
                            ? [BoxShadow(color: AppColors.primaryFixed.withValues(alpha: 0.2), blurRadius: 16)]
                            : null,
                      ),
                      child: Icon(_protocols[i].icon, size: 28,
                          color: active ? const Color(0xFF2B3400) : Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 8),
                    Text(_protocols[i].label,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: active ? Colors.white : Colors.white.withValues(alpha: 0.6)),
                        textAlign: TextAlign.center),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicians() {
    return StreamBuilder<List<MarketplaceTechnician>>(
      stream: TechnicianProfileService().watchMarketplaceTechnicians(),
      builder: (context, snapshot) {
        final techs = (snapshot.data ?? []).take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Opacity(
                        opacity: 0.7 + _pulseCtrl.value * 0.3,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.primaryFixed, blurRadius: 8)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Certified Technicians',
                        style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FindProsScreen()),
                    ),
                    child: Row(children: [
                      Text('View All', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              SizedBox(
                height: 248,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryFixed,
                  ),
                ),
              )
            else if (techs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101419).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Text(
                    'No live technicians are available right now.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 248,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: techs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final tech = techs[index];
                    return ExpertCard(
                      name: tech.fullName,
                      level: tech.speciality,
                      rating: tech.rating > 0 ? tech.rating.toStringAsFixed(1) : 'New',
                      eta: tech.distanceKm < double.infinity
                          ? '${tech.distanceKm.toStringAsFixed(0)} km'
                          : 'Nearby',
                      clearance: tech.isAvailable ? 'Live' : 'Offline',
                      imageUrl: tech.profileImage ?? '',
                      isAvailable: tech.isAvailable,
                      onDispatch: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TechnicianProfileScreen(
                              technicianId: tech.id,
                              initialName: tech.fullName,
                            ),
                          ),
                        );
                      },
                      onProfile: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TechnicianProfileScreen(
                              technicianId: tech.id,
                              initialName: tech.fullName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmergency() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _EmergencyButton(),
    );
  }
}

class _EmergencyButton extends StatefulWidget {
  @override
  State<_EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<_EmergencyButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(_pressed ? 0.98 : 1.0, _pressed ? 0.98 : 1.0, 1.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0xFFFF4B4B).withValues(alpha: 0.1)
              : const Color(0xFFFF4B4B).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _pressed
                ? const Color(0xFFFF4B4B).withValues(alpha: 0.3)
                : const Color(0xFFFF4B4B).withValues(alpha: 0.2),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _pressed
                      ? const Color(0xFFFF4B4B)
                      : const Color(0xFFFF4B4B).withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4B4B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF4B4B).withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.warning_outlined, color: Color(0xFFFF4B4B), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Critical Override',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 4),
                      Row(children: [
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Opacity(
                            opacity: _pulseCtrl.value,
                            child: Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(color: Color(0xFFFF4B4B), shape: BoxShape.circle),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Priority Routing',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFFFF4B4B).withValues(alpha: 0.8))),
                      ]),
                    ]),
                  ]),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: _pressed ? 0.1 : 0.05),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Icon(Icons.chevron_right,
                        size: 18,
                        color: Colors.white.withValues(alpha: _pressed ? 1.0 : 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Protocol {
  final String label;
  final IconData icon;
  const _Protocol(this.label, this.icon);
}
