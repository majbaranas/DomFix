import 'package:flutter/material.dart';

class AnimatedPulseDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool isAnimating;

  const AnimatedPulseDot({
    super.key,
    required this.color,
    this.size = 8.0,
    this.isAnimating = true,
  });

  @override
  State<AnimatedPulseDot> createState() => _AnimatedPulseDotState();
}

class _AnimatedPulseDotState extends State<AnimatedPulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedPulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: widget.isAnimating ? _animation.value : 1.0),
            boxShadow: widget.isAnimating
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: _animation.value * 0.6),
                      blurRadius: widget.size * 1.5,
                      spreadRadius: widget.size * 0.2,
                    )
                  ]
                : null,
          ),
        );
      },
    );
  }
}
