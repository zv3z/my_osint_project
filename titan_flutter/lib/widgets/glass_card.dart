import 'package:flutter/material.dart';
import '../main.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderRadius;
  final Color? backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderRadius = 16,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor ?? TitanTheme.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? TitanTheme.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 18, color: TitanTheme.textMuted),
          if (icon != null) const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor ?? TitanTheme.indigoLight,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: TitanTheme.textMuted,
              letterSpacing: 0.08,
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
  static const _icons = {
    'CRITICAL': '🔴',
    'HIGH':     '🟠',
    'MEDIUM':   '🟡',
    'LOW':      '🟢',
  };

  @override
  Widget build(BuildContext context) {
    final col = _colors[level] ?? const Color(0xFF888888);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: col.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: col, width: 3)),
      ),
      child: Row(
        children: [
          Text(_icons[level] ?? '⚪', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              level,
              style: TextStyle(
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: TitanTheme.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: TitanTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
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
      backgroundColor: color.withOpacity(0.08),
      borderColor: color.withOpacity(0.35),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'THREAT SCORE',
            style: TextStyle(fontSize: 10, color: TitanTheme.textMuted, letterSpacing: 0.1),
          ),
        ],
      ),
    );
  }
}
