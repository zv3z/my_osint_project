import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

// ── Dashboard Screen ───────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _cves = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String _severityFilter = 'ALL';

  // Demo attack data: (lat, lng, city, country, count)
  static const _demoAttacks = [
    (39.9042, 116.4074, 'Beijing', 'CN', 850),
    (55.7558, 37.6173, 'Moscow', 'RU', 720),
    (37.5665, 126.9780, 'Seoul', 'KR', 380),
    (40.7128, -74.0060, 'New York', 'US', 290),
    (51.5074, -0.1278, 'London', 'GB', 180),
    (48.8566, 2.3522, 'Paris', 'FR', 120),
    (35.6762, 139.6503, 'Tokyo', 'JP', 95),
    (1.3521, 103.8198, 'Singapore', 'SG', 88),
    (25.2048, 55.2708, 'Dubai', 'AE', 76),
    (24.7136, 46.6753, 'Riyadh', 'SA', 45),
  ];

  // Tapped marker info
  (double, double, String, String, int)? _tappedMarker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final results = await Future.wait<Map<String, dynamic>>([
        ApiService.dashboardStats().catchError((_) => <String, dynamic>{}),
        ApiService.recentCves().catchError((_) => <String, dynamic>{}),
      ]);

      if (!mounted) return;

      final statsData = results[0];
      final cvesData = results[1];

      final rawCves = cvesData['cves'] ?? cvesData['results'] ?? cvesData['data'] ?? [];
      final cveList = (rawCves as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _stats = statsData;
        _cves = cveList;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredCves {
    if (_severityFilter == 'ALL') return _cves;
    return _cves
        .where((c) =>
            (c['severity'] as String? ?? '').toUpperCase() == _severityFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppState>().isAr;

    return Scaffold(
      backgroundColor: TitanTheme.bgPrimary,
      body: RefreshIndicator(
        onRefresh: _load,
        color: TitanTheme.indigo,
        backgroundColor: TitanTheme.bgSecondary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: TitanTheme.bgPrimary,
              elevation: 0,
              title: Text(
                L.t('dashboard', isAr),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: TitanTheme.textPrimary,
                ),
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              ),
              actions: [
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: TitanTheme.indigo,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              ],
            ),

            // ── Stats Row ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildStats(isAr),
            ),

            // ── Threat Map ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildThreatMap(isAr),
            ),

            // ── CVE Section ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildCveSection(isAr),
            ),

            // Bottom padding for floating nav
            const SliverToBoxAdapter(
              child: SizedBox(height: 110),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Section ──────────────────────────────────────────────────────
  Widget _buildStats(bool isAr) {
    final totalScans = _stats['total_scans'] ?? _stats['totalScans'] ?? 0;
    final highRisk   = _stats['high_risk'] ?? _stats['highRisk'] ?? 0;
    final aiStatus   = _stats['ai_enabled'] ?? _stats['aiEnabled'] ?? true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: totalScans.toString(),
              label: L.t('total_scans', isAr),
              icon: Icons.radar_outlined,
              color: TitanTheme.indigo,
              isAr: isAr,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '56',
              label: L.t('engines_active', isAr),
              icon: Icons.memory_outlined,
              color: TitanTheme.cyan,
              isAr: isAr,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: highRisk.toString(),
              label: L.t('high_risk', isAr),
              icon: Icons.warning_amber_outlined,
              color: TitanTheme.red,
              isAr: isAr,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: aiStatus == true ? '✓' : '✗',
              label: L.t('ai_powered', isAr),
              icon: Icons.psychology_outlined,
              color: aiStatus == true ? TitanTheme.green : TitanTheme.textMuted,
              isAr: isAr,
            ),
          ),
        ],
      ),
    );
  }

  // ── Threat Map Section ─────────────────────────────────────────────────
  Widget _buildThreatMap(bool isAr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            label: isAr
                ? 'خريطة التهديدات العالمية'
                : 'GLOBAL THREAT MAP',
            isAr: isAr,
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 16,
            glowColor: TitanTheme.red.withOpacity(0.4),
            borderGradient: LinearGradient(
              colors: [
                TitanTheme.red.withOpacity(0.25),
                TitanTheme.indigo.withOpacity(0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: const MapOptions(
                        initialCenter: LatLng(25.0, 15.0),
                        initialZoom: 1.8,
                        interactionOptions: InteractionOptions(
                          flags: InteractiveFlag.pinchZoom |
                              InteractiveFlag.drag,
                        ),
                      ),
                      children: [
                        // Dark CartoDB tiles
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.titan.osint',
                        ),
                        // Attack markers
                        MarkerLayer(
                          markers: _demoAttacks.map((attack) {
                            final lat   = attack.$1;
                            final lng   = attack.$2;
                            final count = attack.$5;
                            final size  = (count / 850 * 36 + 12).clamp(12.0, 48.0);

                            return Marker(
                              point: LatLng(lat, lng),
                              width: size,
                              height: size,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_tappedMarker != null &&
                                        _tappedMarker!.$1 == lat &&
                                        _tappedMarker!.$2 == lng) {
                                      _tappedMarker = null;
                                    } else {
                                      _tappedMarker = attack;
                                    }
                                  });
                                },
                                child: _PulsingDot(
                                  size: size,
                                  count: count,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    // Tapped marker popup
                    if (_tappedMarker != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: _MapPopup(
                          city: _tappedMarker!.$3,
                          country: _tappedMarker!.$4,
                          count: _tappedMarker!.$5,
                          onClose: () => setState(() => _tappedMarker = null),
                        ),
                      ),

                    // Legend
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _MapLegend(isAr: isAr),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CVE Section ────────────────────────────────────────────────────────
  Widget _buildCveSection(bool isAr) {
    const filters = ['ALL', 'CRITICAL', 'HIGH', 'MEDIUM'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            label: isAr ? 'تنبيهات الثغرات الأمنية' : 'VULNERABILITY ALERTS',
            isAr: isAr,
          ),
          const SizedBox(height: 12),

          // Filter chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = filters[i];
                final selected = _severityFilter == f;
                final color = _severityColor(f);
                return GestureDetector(
                  onTap: () => setState(() => _severityFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.18)
                          : color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? color.withOpacity(0.60)
                            : color.withOpacity(0.20),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      f,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? color : color.withOpacity(0.55),
                        letterSpacing: 0.06,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // CVE list or placeholder
          if (_loading)
            _CveLoadingPlaceholder()
          else if (_filteredCves.isEmpty)
            _CveEmptyState(isAr: isAr)
          else
            Column(
              children: _filteredCves
                  .map((cve) => _CveCard(cve: cve, isAr: isAr))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return TitanTheme.red;
      case 'HIGH':
        return TitanTheme.orange;
      case 'MEDIUM':
        return TitanTheme.amber;
      case 'LOW':
        return TitanTheme.green;
      default:
        return TitanTheme.indigo;
    }
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool isAr;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      glowColor: color.withOpacity(0.5),
      borderGradient: LinearGradient(
        colors: [
          color.withOpacity(0.35),
          color.withOpacity(0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [color, color.withOpacity(0.70)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: TitanTheme.textMuted,
              letterSpacing: 0.08,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isAr;

  const _SectionHeader({required this.label, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [TitanTheme.indigo, TitanTheme.violet],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TitanTheme.textMuted,
            letterSpacing: 0.12,
          ),
        ),
      ],
    );

    if (isAr) {
      return Directionality(textDirection: TextDirection.rtl, child: row);
    }
    return row;
  }
}

// ── Pulsing Dot Marker ─────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final double size;
  final int count;

  const _PulsingDot({required this.size, required this.count});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: TitanTheme.red.withOpacity(_anim.value * 0.75 + 0.10),
            shape: BoxShape.circle,
            border: Border.all(
              color: TitanTheme.red.withOpacity(_anim.value * 0.85 + 0.10),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: TitanTheme.red.withOpacity(_anim.value * 0.50),
                blurRadius: widget.size * 0.8,
                spreadRadius: 0,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Map Popup ──────────────────────────────────────────────────────────────
class _MapPopup extends StatelessWidget {
  final String city;
  final String country;
  final int count;
  final VoidCallback onClose;

  const _MapPopup({
    required this.city,
    required this.country,
    required this.count,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xCC0C0F1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: TitanTheme.red.withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: TitanTheme.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: TitanTheme.red.withOpacity(0.7), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$city, $country',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TitanTheme.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  $count attacks',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: TitanTheme.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 16, color: TitanTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Map Legend ─────────────────────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  final bool isAr;

  const _MapLegend({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xAA0C0F1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: TitanTheme.borderColor,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: TitanTheme.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isAr ? 'مصدر هجوم' : 'Attack Source',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: TitanTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CVE Card ───────────────────────────────────────────────────────────────
class _CveCard extends StatelessWidget {
  final Map<String, dynamic> cve;
  final bool isAr;

  static const _severityColors = {
    'CRITICAL': TitanTheme.red,
    'HIGH':     TitanTheme.orange,
    'MEDIUM':   TitanTheme.amber,
    'LOW':      TitanTheme.green,
  };

  const _CveCard({required this.cve, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final severity = (cve['severity'] as String? ?? 'LOW').toUpperCase();
    final cveId    = cve['cve_id'] as String? ??
        cve['id'] as String? ??
        cve['cveId'] as String? ?? 'N/A';
    final description = cve['description'] as String? ??
        cve['summary'] as String? ?? '';
    final published = cve['published'] as String? ??
        cve['publishedDate'] as String? ?? '';
    final scoreRaw = cve['cvss_score'] ?? cve['score'] ?? cve['cvssScore'];
    final score = scoreRaw != null ? scoreRaw.toString() : '—';

    final color = _severityColors[severity] ?? TitanTheme.green;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left:   BorderSide(color: color, width: 3),
                top:    BorderSide(color: color.withOpacity(0.15), width: 0.5),
                right:  BorderSide(color: color.withOpacity(0.08), width: 0.5),
                bottom: BorderSide(color: color.withOpacity(0.08), width: 0.5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: CVE ID + severity badge + score
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cveId,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TitanTheme.cyan,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Severity badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: color.withOpacity(0.40), width: 0.5),
                        ),
                        child: Text(
                          severity,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.06,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // CVSS score
                      Text(
                        score,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Description
                  if (description.isNotEmpty) ...[
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: TitanTheme.textSecondary,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Published date
                  if (published.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 10, color: TitanTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          published.length > 10
                              ? published.substring(0, 10)
                              : published,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: TitanTheme.textMuted,
                          ),
                        ),
                      ],
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

// ── CVE Loading Placeholder ────────────────────────────────────────────────
class _CveLoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TitanTheme.borderColor),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: TitanTheme.indigo,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── CVE Empty State ────────────────────────────────────────────────────────
class _CveEmptyState extends StatelessWidget {
  final bool isAr;

  const _CveEmptyState({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.security_outlined, size: 40, color: TitanTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            L.t('no_data', isAr),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: TitanTheme.textMuted,
            ),
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
