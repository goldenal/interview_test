import 'package:flutter/material.dart';

/// Animated skeleton box for loading states
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    required this.color,
  });

  final double height;
  final double? width;
  final Color color;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.5),
                color.withValues(alpha: 0.3),
              ],
              stops: [
                (_controller.value * 0.5).clamp(0.0, 0.5),
                (_controller.value * 0.5 + 0.25).clamp(0.25, 0.75),
                (_controller.value * 0.5 + 0.5).clamp(0.5, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
