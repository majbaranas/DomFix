import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveStatusBadge extends StatefulWidget {
  final String status;
  final bool showLabel;
  final double size;

  const LiveStatusBadge({
    super.key,
    required this.status,
    this.showLabel = true,
    this.size = 10.0,
  });

  @override
  State<LiveStatusBadge> createState() => _LiveStatusBadgeState();
}

class _LiveStatusBadgeState extends State<LiveStatusBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.status) {
      case 'online':
        return const Color(0xFF00FF66); // Neon Green
      case 'busy':
        return const Color(0xFFFF9900); // Orange
      case 'on_job':
        return const Color(0xFF00BFFF); // Neon Blue
      case 'offline':
      default:
        return Colors.grey.shade600;
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case 'online':
        return 'Online';
      case 'busy':
        return 'Busy';
      case 'on_job':
        return 'On Job';
      case 'offline':
      default:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == 'offline' && !widget.showLabel) {
      // For minimal views (like map markers), don't show offline badges to keep it clean
      return const SizedBox.shrink();
    }

    final color = _statusColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: widget.status != 'offline'
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: _glowAnimation.value),
                          blurRadius: widget.size,
                          spreadRadius: widget.size * 0.2,
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: 6),
          Text(
            _statusLabel,
            style: GoogleFonts.inter(
              color: color,
              fontSize: widget.size * 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
