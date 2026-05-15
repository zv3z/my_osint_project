import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import 'result_screen.dart';

// ── Home Screen ────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _ctrl        = TextEditingController();
  final _focusNode   = FocusNode();
  bool _scanning     = false;
  bool _inputFocused = false;
  String _status     = '';

  // Pulse animation for LIVE badge
  late AnimationController _pulseCtrl;
  late Animation<double>    _pulse;

  // Radial gradient animation for header
  late AnimationController _radialCtrl;
  late Animation<double>    _radial;

  // Scanning progress shimmer animation
  late AnimationController _shimmerCtrl;
  late Animation<double>    _shimmer;

  // Status cycling
  int _statusIdx = 0;
  final _statuses = [
    'Initializing engines...',
    'Running 50+ threat engines...',
    'Correlating intelligence...',
    'Analyzing network topology...',
    'Fetching geolocation data...',
    'Cross-referencing databases...',
    'Generating AI insights...',
  ];

  // Target chip definitions: (label, icon, placeholder, color)
  final _targetTypes = [
    ('IP Address', Icons.router_outlined,        '8.8.8.8',           TitanTheme.cyan),
    ('Domain',     Icons.language_outlined,       'google.com',        TitanTheme.indigo),
    ('Email',      Icons.alternate_email_outlined,'user@example.com',  TitanTheme.violet),
    ('Hash',       Icons.fingerprint_outlined,    'a94a8fe5ccb19ba..', TitanTheme.amber),
    ('URL',        Icons.link_outlined,           'https://...',       TitanTheme.green),
    ('Phone',      Icons.phone_outlined,          '+1-555-0100',       TitanTheme.orange),
    ('GitHub',     Icons.code_outlined,           '@username',         TitanTheme.indigoLight),
    ('ASN',        Icons.hub_outlined,            'AS15169',           TitanTheme.pink),
    ('npm',        Icons.inventory_2_outlined,    'package-name',      TitanTheme.greenDark),
  ];

  final _features = [
    (Icons.shield_outlined,     '50+ Engines',      'Parallel threat scanning',     TitanTheme.indigo,  TitanTheme.violet),
    (Icons.psychology_outlined, 'AI Analysis',      'Gemini & GPT-4 fusion',        TitanTheme.cyan,    TitanTheme.indigo),
    (Icons.map_outlined,        'Geo Intelligence', 'IP geolocation mapping',       TitanTheme.green,   TitanTheme.cyan),
    (Icons.hub_outlined,        'Network Graph',    'Relationship visualization',   TitanTheme.amber,   TitanTheme.orange),
    (Icons.bug_report_outlined, 'MITRE ATT&CK',     'Technique mapping',            TitanTheme.orange,  TitanTheme.red),
    (Icons.lock_open_outlined,  'Breach Check',     'HIBP + LeakCheck integration', TitanTheme.red,     TitanTheme.pink),
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _radialCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _radial = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _radialCtrl, curve: Curves.easeInOutSine),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOutCubic),
    );

    _focusNode.addListener(() {
      setState(() => _inputFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _pulseCtrl.dispose();
    _radialCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    final target = _ctrl.text.trim();
    if (target.isEmpty) return;

    HapticFeedback.mediumImpact();
    _focusNode.unfocus();

    setState(() {
      _scanning  = true;
      _statusIdx = 0;
      _status    = _statuses[0];
    });

    // Cycle status messages while scanning
    _cycleStatus();

    try {
      final lang = context.read<AppState>().lang;
      final data = await ApiService.scan(target, lang: lang);
      final result = ScanResult.fromJson(data);

      if (!mounted) return;
      setState(() => _scanning = false);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => ResultScreen(result: result),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _scanning = false; _status = ''; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Error: ${e.toString().replaceAll('Exception: ', '')}',
          style: GoogleFonts.inter(color: TitanTheme.textPrimary),
        ),
        backgroundColor: TitanTheme.bgSecondary,
      ));
    }
  }

  void _cycleStatus() {
    if (!_scanning || !mounted) return;
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted || !_scanning) return;
      setState(() {
        _statusIdx = (_statusIdx + 1) % _statuses.length;
        _status    = _statuses[_statusIdx];
      });
      _cycleStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TitanTheme.bgPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Animated Header ────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader()),

          // ── Main Content ───────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // Scan card
                _buildScanCard(),
                const SizedBox(height: 28),

                // Supported Targets
                _buildSectionLabel('SUPPORTED TARGETS'),
                const SizedBox(height: 12),
                _buildTargetChips(),
                const SizedBox(height: 28),

                // Capabilities grid
                _buildSectionLabel('CAPABILITIES'),
                const SizedBox(height: 12),
                _buildFeatureGrid(),

                // Bottom padding for floating nav
                const SizedBox(height: 110),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _radial,
      builder: (context, _) {
        return Container(
          height: 220,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(color: TitanTheme.bgPrimary),
          child: Stack(
            children: [
              // Animated radial glow background
              Positioned.fill(
                child: CustomPaint(
                  painter: _RadialGlowPainter(progress: _radial.value),
                ),
              ),

              // Subtle grid lines
              Positioned.fill(
                child: CustomPaint(painter: _GridLinePainter()),
              ),

              // Blur overlay at bottom edge
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        TitanTheme.bgPrimary.withOpacity(0),
                        TitanTheme.bgPrimary,
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: logo + title + LIVE badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Lightning bolt logo with glow
                          _buildLogo(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Gradient "TITAN OSINT" text
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFFF1F5F9),
                                      Color(0xFF818CF8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  child: Text(
                                    'TITAN OSINT',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cyber Intelligence Platform',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: TitanTheme.textMuted,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildLiveBadge(),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Stat row
                      Row(
                        children: [
                          _buildStatPill('50+', 'ENGINES',  TitanTheme.indigo),
                          const SizedBox(width: 10),
                          _buildStatPill('AI',  'POWERED',  TitanTheme.cyan),
                          const SizedBox(width: 10),
                          _buildStatPill('24/7','LIVE',     TitanTheme.green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TitanTheme.indigo, TitanTheme.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: TitanTheme.indigo.withOpacity(0.60),
            blurRadius: 20,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: TitanTheme.cyan.withOpacity(0.20),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.bolt, color: Colors.white, size: 26),
    );
  }

  Widget _buildLiveBadge() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: TitanTheme.green.withOpacity(0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: TitanTheme.green.withOpacity(_pulse.value * 0.6 + 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: TitanTheme.green.withOpacity(_pulse.value * 0.18),
                blurRadius: 14,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: TitanTheme.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: TitanTheme.green.withOpacity(_pulse.value * 0.9),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: TitanTheme.green,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatPill(String value, String label, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.20), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.70),
                  letterSpacing: 0.12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Label ────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Row(
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
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TitanTheme.textMuted,
            letterSpacing: 0.14,
          ),
        ),
      ],
    );
  }

  // ── Scan Card ────────────────────────────────────────────────────────────
  Widget _buildScanCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        glowColor: _inputFocused ? TitanTheme.cyan : null,
        borderGradient: _inputFocused
            ? const LinearGradient(
                colors: [
                  Color(0xFF22D3EE),
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0x25FFFFFF), Color(0x08FFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [TitanTheme.indigo, TitanTheme.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: TitanTheme.indigo.withOpacity(0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.radar, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Target',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: TitanTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'IP · Domain · Email · Hash · URL · Phone',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: TitanTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Input field
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: _inputFocused
                    ? [
                        BoxShadow(
                          color: TitanTheme.cyan.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                enabled: !_scanning,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: TitanTheme.textPrimary,
                  letterSpacing: 0.3,
                ),
                decoration: InputDecoration(
                  hintText: '8.8.8.8  ·  google.com  ·  user@email.com',
                  hintStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: TitanTheme.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: _inputFocused
                        ? TitanTheme.cyan
                        : TitanTheme.textMuted,
                    size: 20,
                  ),
                  suffixIcon: _ctrl.text.isNotEmpty && !_scanning
                      ? GestureDetector(
                          onTap: () {
                            _ctrl.clear();
                            setState(() {});
                          },
                          child: Icon(
                            Icons.close,
                            color: TitanTheme.textMuted,
                            size: 18,
                          ),
                        )
                      : null,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: TitanTheme.cyan, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _runScan(),
                textInputAction: TextInputAction.search,
              ),
            ),

            // Scanning progress
            if (_scanning) ...[
              const SizedBox(height: 16),
              _buildScanningProgress(),
            ],

            const SizedBox(height: 16),

            // Run Engines button
            NeonButton(
              icon: _scanning ? null : Icons.bolt,
              label: _scanning ? 'SCANNING...' : 'RUN ENGINES',
              onPressed: _scanning ? null : _runScan,
              isLoading: _scanning,
              colors: _scanning
                  ? [
                      TitanTheme.indigo.withOpacity(0.7),
                      TitanTheme.violet.withOpacity(0.7),
                    ]
                  : [TitanTheme.indigo, TitanTheme.violet],
              height: 54,
              borderRadius: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: TitanTheme.indigoLight.withOpacity(0.9),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  _status,
                  key: ValueKey(_status),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: TitanTheme.indigoLight,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Animated shimmer progress bar
        AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0x1A6366F1),
                ),
                child: Stack(
                  children: [
                    // Base fill
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            TitanTheme.indigo.withOpacity(0.3),
                            TitanTheme.violet.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    // Shimmer sweep
                    FractionallySizedBox(
                      widthFactor: 0.4,
                      child: FractionalTranslation(
                        translation: Offset(_shimmer.value, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                TitanTheme.indigo.withOpacity(0.9),
                                TitanTheme.cyan.withOpacity(0.7),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Target Chips ─────────────────────────────────────────────────────────
  Widget _buildTargetChips() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _targetTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _targetTypes[i];
          return _TargetChip(
            label: t.$1,
            icon: t.$2,
            color: t.$4,
            onTap: () {
              _ctrl.text = t.$3;
              setState(() {});
              _focusNode.requestFocus();
            },
          );
        },
      ),
    );
  }

  // ── Feature Grid ─────────────────────────────────────────────────────────
  Widget _buildFeatureGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: _features.length,
      itemBuilder: (_, i) {
        final f = _features[i];
        return _FeatureCard(
          icon:        f.$1,
          title:       f.$2,
          subtitle:    f.$3,
          colorStart:  f.$4,
          colorEnd:    f.$5,
        );
      },
    );
  }
}

// ── Target Chip Widget ─────────────────────────────────────────────────────
class _TargetChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_TargetChip> createState() => _TargetChipState();
}

class _TargetChipState extends State<_TargetChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.reverse(),
      onTapUp:   (_) { _scaleCtrl.forward(); widget.onTap(); },
      onTapCancel: () => _scaleCtrl.forward(),
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (_, child) => Transform.scale(
          scale: _scaleCtrl.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.color.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.color.withOpacity(0.90),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature Card Widget ────────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color colorStart;
  final Color colorEnd;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorStart,
    required this.colorEnd,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverCtrl;
  late Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _hoverAnim = CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hoverCtrl.forward(),
      onTapUp:   (_) => _hoverCtrl.reverse(),
      onTapCancel: () => _hoverCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _hoverAnim,
        builder: (_, child) {
          return Transform.scale(
            scale: 1.0 - _hoverAnim.value * 0.03,
            child: child,
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          glowColor: widget.colorStart.withOpacity(0.6),
          borderGradient: LinearGradient(
            colors: [
              widget.colorStart.withOpacity(0.30),
              widget.colorEnd.withOpacity(0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with gradient background
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.colorStart.withOpacity(0.25),
                      widget.colorEnd.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.colorStart.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Icon(widget.icon, size: 18, color: widget.colorStart),
              ),
              const Spacer(),
              Text(
                widget.title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TitanTheme.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: TitanTheme.textMuted,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Radial Glow Painter ────────────────────────────────────────────────────
class _RadialGlowPainter extends CustomPainter {
  final double progress;

  _RadialGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Primary glow — indigo/violet, shifts position subtly
    final cx1 = w * (0.25 + progress * 0.15);
    final cy1 = h * (0.35 - progress * 0.10);
    final r1   = w * (0.55 + progress * 0.10);

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6366F1).withOpacity(0.18),
          const Color(0xFF8B5CF6).withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: r1));

    canvas.drawCircle(Offset(cx1, cy1), r1, paint1);

    // Secondary glow — cyan, on the right side
    final cx2 = w * (0.80 - progress * 0.12);
    final cy2 = h * (0.50 + progress * 0.12);
    final r2   = w * (0.40 + progress * 0.08);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF22D3EE).withOpacity(0.10),
          const Color(0xFF22D3EE).withOpacity(0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: r2));

    canvas.drawCircle(Offset(cx2, cy2), r2, paint2);
  }

  @override
  bool shouldRepaint(_RadialGlowPainter old) => old.progress != progress;
}

// ── Grid Line Painter ──────────────────────────────────────────────────────
class _GridLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x086366F1)
      ..strokeWidth = 0.5;

    const spacing = 36.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridLinePainter old) => false;
}
