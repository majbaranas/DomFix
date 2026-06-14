import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/dashboard_metrics.dart';

class AIInsightsPremium extends StatefulWidget {
  final List<AIInsight> insights;

  const AIInsightsPremium({super.key, required this.insights});

  @override
  State<AIInsightsPremium> createState() => _AIInsightsPremiumState();
}

class _AIInsightsPremiumState extends State<AIInsightsPremium> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Insights',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '✨ Smart',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                widget.insights.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    right: index == widget.insights.length - 1 ? 0 : AppSpacing.space12,
                  ),
                  child: _AIInsightCard(
                    insight: widget.insights[index],
                    animationController: _controller,
                    delay: Duration(milliseconds: index * 100),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AIInsightCard extends StatefulWidget {
  final AIInsight insight;
  final AnimationController animationController;
  final Duration delay;

  const _AIInsightCard({
    required this.insight,
    required this.animationController,
    required this.delay,
  });

  @override
  State<_AIInsightCard> createState() => _AIInsightCardState();
}

class _AIInsightCardState extends State<_AIInsightCard> {
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Interval(
          widget.delay.inMilliseconds / 1200.0,
          (widget.delay.inMilliseconds + 600) / 1200.0,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  Color _getInsightColor() {
    switch (widget.insight.category) {
      case 'opportunity':
        return Colors.cyan;
      case 'performance':
        return Colors.amber;
      case 'earnings':
        return AppColors.neonAccent;
      case 'rating':
        return Colors.pink;
      default:
        return AppColors.neonAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getInsightColor().withValues(alpha: 0.12),
              _getInsightColor().withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: _getInsightColor().withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: _getInsightColor().withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getInsightColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.insight.icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.insight.title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Description
            Text(
              widget.insight.description,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // Metric if available
            if (widget.insight.metric != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getInsightColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${widget.insight.metric!.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _getInsightColor(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AIInsight {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String category;
  final double? metric;

  const AIInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    this.metric,
  });
}
