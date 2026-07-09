import 'package:flutter/material.dart';

// ============================================================
// SLATE BUTTON — shared button style for shell (gray) screens
// ============================================================
// Deliberately distinct from the native game's neon rectangular
// buttons — a stadium-shaped pill with a magenta→cyan gradient
// and a subtle push-scale reaction. This is what users see on
// the offline and push-invite veils.
// ============================================================

class SlatePillButton extends StatefulWidget {
  const SlatePillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
    this.accent = _kPrimaryAccent,
    this.secondaryAccent = _kSecondaryAccent,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;
  final Color accent;
  final Color secondaryAccent;

  static const Color _kPrimaryAccent = Color(0xFF29E7FF);
  static const Color _kSecondaryAccent = Color(0xFFFF3EA5);

  @override
  State<SlatePillButton> createState() => _SlatePillButtonState();
}

class _SlatePillButtonState extends State<SlatePillButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final double vPad = widget.compact ? 12 : 18;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: vPad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[widget.accent, widget.secondaryAccent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.accent.withOpacity(0.55),
                blurRadius: 22,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: widget.secondaryAccent.withOpacity(0.35),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 15 : 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                height: 1.0,
                shadows: const <Shadow>[
                  Shadow(
                    color: Color(0x99000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost / outline variant — used for the "Skip" secondary action.
class SlateGhostButton extends StatefulWidget {
  const SlateGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;

  @override
  State<SlateGhostButton> createState() => _SlateGhostButtonState();
}

class _SlateGhostButtonState extends State<SlateGhostButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final double vPad = widget.compact ? 10 : 14;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: vPad),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 2),
          ),
          child: Center(
            child: Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 14 : 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
