import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';

class FindProsScreen extends StatefulWidget {
  const FindProsScreen({super.key});

  @override
  State<FindProsScreen> createState() => _FindProsScreenState();
}

class _FindProsScreenState extends State<FindProsScreen> with TickerProviderStateMixin {
  int _selectedNavIndex = 2;
  int _currentCardIndex = 0;
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  final List<ProProfile> _profiles = [
    ProProfile(
      name: 'Marcus P.',
      profession: 'Electrician',
      rating: 5.0,
      distance: '3km away',
      badges: ['Expert', 'Certified', 'Fast Response'],
      description: 'Specializing in smart home integration and complex rewiring. Available for emergency calls 24/7.',
      imageUrl: 'https://via.placeholder.com/400x600/2A3040/FFFFFF?text=Electrician',
    ),
    ProProfile(
      name: 'Sarah K.',
      profession: 'Plumber',
      rating: 4.9,
      distance: '5km away',
      badges: ['Expert', 'Licensed', '24/7'],
      description: 'Expert in leak detection and pipe repair. Fast response time for emergencies.',
      imageUrl: 'https://via.placeholder.com/400x600/2A3040/FFFFFF?text=Plumber',
    ),
    ProProfile(
      name: 'David M.',
      profession: 'HVAC Specialist',
      rating: 4.8,
      distance: '7km away',
      badges: ['Certified', 'Experienced', 'Reliable'],
      description: 'Professional heating and cooling system installation and maintenance.',
      imageUrl: 'https://via.placeholder.com/400x600/2A3040/FFFFFF?text=HVAC',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (_dragOffset.dx.abs() > screenWidth * 0.3) {
      // Swipe threshold reached
      _animateSwipe(_dragOffset.dx > 0);
    } else {
      // Return to center
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  void _animateSwipe(bool isRight) {
    final screenWidth = MediaQuery.of(context).size.width;
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(isRight ? screenWidth * 1.5 : -screenWidth * 1.5, _dragOffset.dy),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));

    _swipeController.forward(from: 0).then((_) {
      setState(() {
        _currentCardIndex = (_currentCardIndex + 1) % _profiles.length;
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
      _swipeController.reset();
    });
  }

  void _handleReject() {
    _dragOffset = const Offset(-100, 0);
    _animateSwipe(false);
  }

  void _handleHire() {
    _dragOffset = const Offset(100, 0);
    _animateSwipe(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildMainContent(),
          ),
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: ClipOval(
                  child: Icon(
                    Icons.person,
                    color: AppColors.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'DOMFIX',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.primaryContainer,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildTitleSection(),
          const SizedBox(height: 24),
          Expanded(
            child: _buildCardStack(),
          ),
          const SizedBox(height: 20),
          _buildSwipeHints(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MARKETPLACE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Find Pros',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            Icons.tune,
            color: AppColors.onSurface,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildCardStack() {
    return Stack(
      children: [
        // Background cards for depth effect
        if (_currentCardIndex + 2 < _profiles.length)
          _buildBackgroundCard(2),
        if (_currentCardIndex + 1 < _profiles.length)
          _buildBackgroundCard(1),
        // Active card
        _buildActiveCard(),
      ],
    );
  }

  Widget _buildBackgroundCard(int offset) {
    final scale = 1.0 - (offset * 0.05);
    final yOffset = offset * 10.0;
    final opacity = 1.0 - (offset * 0.35);

    return Transform.translate(
      offset: Offset(0, -yOffset),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.05),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard() {
    final profile = _profiles[_currentCardIndex];
    final rotation = _dragOffset.dx / 1000;
    final opacity = 1.0 - (_dragOffset.dx.abs() / 500).clamp(0.0, 0.5);

    return AnimatedBuilder(
      animation: _swipeAnimation,
      builder: (context, child) {
        final offset = _isDragging ? _dragOffset : _swipeAnimation.value;
        
        return Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: opacity,
              child: child!,
            ),
          ),
        );
      },
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                // Background image placeholder
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF2A3040),
                        AppColors.background,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.engineering_outlined,
                      size: 120,
                      color: AppColors.primaryContainer.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.background.withValues(alpha: 0.9),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
                // Content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildCardContent(profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(ProProfile profile) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.badges.map((badge) {
              final isExpert = badge == 'Expert';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isExpert
                      ? AppColors.primaryContainer.withValues(alpha: 0.15)
                      : AppColors.onSurface.withValues(alpha: 0.05),
                  border: Border.all(
                    color: isExpert
                        ? AppColors.primaryContainer.withValues(alpha: 0.3)
                        : AppColors.onSurface.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: isExpert ? AppColors.primaryContainer : AppColors.onSurface,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            profile.name,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          // Profession and Rating
          Row(
            children: [
              Text(
                profile.profession,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.star,
                color: AppColors.primaryContainer,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                profile.rating.toString(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Distance
          Row(
            children: [
              Icon(
                Icons.near_me,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                profile.distance,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            profile.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: _handleReject,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _handleHire,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryContainer.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryContainer.withValues(alpha: 0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'HIRE PRO',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.favorite,
                          color: AppColors.primaryContainer,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeHints() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(
              Icons.keyboard_arrow_left,
              size: 16,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            Text(
              'SWIPE LEFT TO SKIP',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(width: 32),
        Row(
          children: [
            Text(
              'SWIPE RIGHT TO HIRE',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right,
              size: 16,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_outlined, 'HOME', 0, () {
            Navigator.pop(context);
          }),
          _buildNavItem(Icons.psychology, 'AI CHAT', 1, () {}),
          _buildNavItem(Icons.engineering, 'PROS', 2, () {}),
          _buildNavItem(Icons.settings_remote_outlined, 'CONTROL', 3, () {}),
          _buildNavItem(Icons.settings_outlined, 'SETTINGS', 4, () {}),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, VoidCallback onTap) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primaryContainer
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: isSelected
                    ? AppColors.primaryContainer
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProProfile {
  final String name;
  final String profession;
  final double rating;
  final String distance;
  final List<String> badges;
  final String description;
  final String imageUrl;

  ProProfile({
    required this.name,
    required this.profession,
    required this.rating,
    required this.distance,
    required this.badges,
    required this.description,
    required this.imageUrl,
  });
}
