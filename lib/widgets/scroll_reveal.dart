import 'package:flutter/material.dart';

/// Reveals its child with a slide-up + fade-in animation.
///
/// In [ListView.builder] contexts this triggers automatically when the item
/// first enters the viewport (Flutter builds items lazily, so [initState]
/// runs exactly when the item becomes visible). Combined with an index-based
/// [delay] this produces a natural staggered cascade as the user scrolls.
///
/// In [CustomScrollView] / [SliverToBoxAdapter] contexts (where all slivers
/// build at once), pass explicit staggered delays to each section widget for
/// a cascading page-load reveal.
class RevealItem extends StatefulWidget {
  const RevealItem({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.slideDistance = 28.0,
    this.curve = Curves.easeOutQuart,
  });

  final Widget child;

  /// How long to wait before starting the animation.
  final Duration delay;

  /// Total animation duration.
  final Duration duration;

  /// Vertical distance (in logical pixels) the widget slides from.
  final double slideDistance;

  /// Easing curve applied to both opacity and slide.
  final Curve curve;

  @override
  State<RevealItem> createState() => _RevealItemState();
}

class _RevealItemState extends State<RevealItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _opacity = curved;
    _slide =
        Tween<double>(begin: widget.slideDistance, end: 0.0).animate(curved);

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FadeTransition is more efficient than Opacity — it avoids a composited
    // layer on every frame. AnimatedBuilder handles the translate separately.
    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (_, child) =>
            Transform.translate(offset: Offset(0, _slide.value), child: child),
        child: widget.child,
      ),
    );
  }
}

/// Wraps a horizontal [SizedBox]+[ListView] in a [Stack] that fades the right
/// edge, hinting at off-screen content. The fade overlay is non-interactive.
class HorizontalFadeHint extends StatelessWidget {
  const HorizontalFadeHint({
    super.key,
    required this.child,
    this.fadeWidth = 48.0,
    this.color,
  });

  final Widget child;
  final double fadeWidth;

  /// Background color to fade to. Defaults to [Theme.of(context).scaffoldBackgroundColor].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: fadeWidth,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [bg.withValues(alpha: 0), bg.withValues(alpha: 0.9)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
