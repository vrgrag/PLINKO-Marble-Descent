import 'package:flutter/material.dart';

class AppColors {
  static const Color deepBlack = Color(0xFF06061A);
  static const Color deepBlue = Color(0xFF0A0B32);
  static const Color neonCyan = Color(0xFF29E7FF);
  static const Color neonPink = Color(0xFFFF3EA5);
  static const Color neonPurple = Color(0xFF9D4EDD);
  static const Color panelDark = Color(0xCC0A0B25);
  static const Color panelBorder = Color(0xFF2E2F76);
}

class AppTextStyles {
  static const TextStyle titleBig = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 1.4,
    shadows: [
      Shadow(color: AppColors.neonCyan, blurRadius: 14),
      Shadow(color: AppColors.neonPink, blurRadius: 22),
    ],
  );

  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 1.2,
    shadows: [Shadow(color: AppColors.neonCyan, blurRadius: 12)],
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: Colors.white,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
  );

  static const TextStyle bodyDim = TextStyle(
    fontSize: 13,
    color: Color(0xFFA6B0F5),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  static const TextStyle number = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    shadows: [Shadow(color: AppColors.neonCyan, blurRadius: 10)],
  );
}

class NeonBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final Color? fill;

  const NeonBorder({
    super.key,
    required this.child,
    this.color = AppColors.neonCyan,
    this.radius = 16,
    this.borderWidth = 1.4,
    this.padding,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? AppColors.panelDark,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color, width: borderWidth),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.55), blurRadius: 16, spreadRadius: 0.5),
          BoxShadow(color: color.withOpacity(0.18), blurRadius: 40, spreadRadius: 4),
        ],
      ),
      child: child,
    );
  }
}

class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  final double horizontalPadding;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.neonCyan,
    this.height = 56,
    this.horizontalPadding = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: NeonBorder(
            color: color,
            radius: 18,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 22, shadows: [
                    Shadow(color: color, blurRadius: 12),
                  ]),
                  const SizedBox(width: 10),
                ],
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    shadows: [Shadow(color: color, blurRadius: 10)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
