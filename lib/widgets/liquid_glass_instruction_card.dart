import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';

class LiquidGlassInstructionCard extends StatelessWidget {
  final String? text;
  final Widget? child;
  final EdgeInsets padding;
  final double radius;
  final double minHeight;

  const LiquidGlassInstructionCard({
    super.key,
    this.text,
    this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
    this.radius = 28,
    this.minHeight = 82,
  }) : assert(text != null || child != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 12,
            spreadRadius: -6,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: minHeight),
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(radius),
              border: GradientBoxBorder(
                width: 1.4,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.withValues(alpha: 0.45),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 10,
                  spreadRadius: -4,
                  offset: const Offset(-3, -3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 12,
                  spreadRadius: -6,
                  offset: const Offset(4, 5),
                ),
              ],
            ),
            child: child ??
                Text(
                  text ?? '',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202020),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}