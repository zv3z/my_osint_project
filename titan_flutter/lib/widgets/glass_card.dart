import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

// ── Glass Card ─────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? glowColor;
  final double blurSigma;
  final Gradient? borderGradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderRadius = 20,
    this.backgroundColor,
    this.glowColor,
    this.blurSigma = 12,
    this.borderGradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlow = glowColor ?? Colors.transparent;
    final hasGlow = glowColor != null;

    // 1. Build the glass interior
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (backgroundColor ?? const Color(0x0DFFFFFF)),
                (backgroundColor ?? const Color(0x06FFFFFF)),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );

    // 2. Overlay gradient border via CustomPaint
    card = CustomPaint(
      painter: _GradientBorderPainter(
        borderRadius: borderRadius,
        borderColor: borderColor,
        borderGradient: borderGradient,
      ),
      child: card,
    );

    // 3. Outer glow / shadow
    if (hasGlow) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: effectiveGlow.withOpacity(0.28),
              blurRadius: 28,
              spreadRadius: -2,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: effectiveGlow.withOpacity(0.12),
              blurRadius: 56,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.50),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: card,
      );
    } else {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.04),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: card,
      );
    }

    return card;
  }
}

// ── Gradient Border Painter ────────────────────────────────────────────────
class _GradientBorderPainter extends CustomPainter {
  final double borderRadius;
  final Color? borderColor;
  final Gradient? borderGradient;

  _GradientBorderPainter({
    required this.borderRadius,
    this.borderColor,
    this.borderGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (borderGradient != null) {
      paint.shader = borderGradient!.createShader(rect);
    } else {
      paint.color = borderColor ?? const Color(0x18FFFFFF);
    }

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) =>
      old.borderRadius != borderRadius ||
      old.borderColor != borderColor ||
      old.borderGradient != borderGradient;
}

// ── Neon Button ────────────────────────────────────────────────────────────
class NeonButton extends StatefulWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final bool isLoading;
  final Widget? loadingChild;
  final double height;
  final double borderRadius;

  const NeonButton({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    this.colors = const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    this.isLoading = false,
    this.loadingChild,
    this.height = 54,
    this.borderRadius = 16,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (widget.onPressed == null || widget.isLoading) return;
    _scaleCtrl.reverse();
  }

  void _onTapUp(_) => _scaleCtrl.forward();
  void _onTapCancel() => _scaleCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final glowColor  = widget.colors.first;

    return GestureDetector(
      onTapDown:   _onTapDown,
      onTapUp:     _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (context, child) =>
            Transform.scale(scale: _scaleCtrl.value, child: child),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.50 : 1.0,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: glowColor.withOpacity(0.50),
                        blurRadius: 22,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: glowColor.withOpacity(0.22),
                        blurRadius: 44,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: widget.isLoading
                ? Center(
                    child: widget.loadingChild ??
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white.withOpacity(0.9),
                            strokeWidth: 2.5,
                          ),
                        ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
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

// ── Metric Card ────────────────────────────────────────────────────────────
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      glowColor: valueColor,
      borderGradient: LinearGradient(
        colors: [
          (valueColor ?? TitanTheme.indigo).withOpacity(0.35),
          (valueColor ?? TitanTheme.violet).withOpacity(0.10),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (valueColor ?? TitanTheme.indigo).withOpacity(0.25),
                    (valueColor ?? TitanTheme.violet).withOpacity(0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (valueColor ?? TitanTheme.indigo).withOpacity(0.25),
                ),
              ),
              child: Icon(icon, size: 18,
                  color: valueColor ?? TitanTheme.indigoLight),
            ),
            const SizedBox(height: 12),
          ],
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                valueColor ?? TitanTheme.indigoLight,
                (valueColor ?? TitanTheme.violet).withOpacity(0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: TitanTheme.textMuted,
              letterSpacing: 0.12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Signal Row ─────────────────────────────────────────────────────────────
class SignalRow extends StatelessWidget {
  final String level;
  final String engine;
  final String message;

  const SignalRow({
    super.key,
    required this.level,
    required this.engine,
    required this.message,
  });

  static const _colors = {
    'CRITICAL': Color(0xFFEF4444),
    'HIGH':     Color(0xFFF97316),
    'MEDIUM':   Color(0xFFF59E0B),
    'LOW':      Color(0xFF10B981),
  };

  @override
  Widget build(BuildContext context) {
    final col = _colors[level] ?? const Color(0xFF888888);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: col.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left:   BorderSide(color: col, width: 3),
              top:    BorderSide(color: col.withOpacity(0.18), width: 0.5),
              right:  BorderSide(color: col.withOpacity(0.08), width: 0.5),
              bottom: BorderSide(color: col.withOpacity(0.08), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Glowing dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: col.withOpacity(0.7), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                child: Text(
                  level,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: col,
                    letterSpacing: 0.04,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      engine,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: TitanTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: TitanTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Score Badge ────────────────────────────────────────────────────────────
class ScoreBadge extends StatelessWidget {
  final int score;
  final String label;
  final Color color;

  const ScoreBadge({
    super.key,
    required this.score,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      backgroundColor: color.withOpacity(0.07),
      borderGradient: LinearGradient(
        colors: [
          color.withOpacity(0.45),
          color.withOpacity(0.15),
          color.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [color, color.withOpacity(0.65)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Text(
              '$score',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 60,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'THREAT SCORE',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: TitanTheme.textMuted,
              letterSpacing: 0.14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
