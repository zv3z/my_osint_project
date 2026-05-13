import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _ctrl    = TextEditingController();
  bool _scanning = false;
  String _status = '';
  late AnimationController _pulseCtrl;
  late Animation<double>    _pulse;

  final _targetTypes = [
    ('IP Address',   Icons.router_outlined,         '8.8.8.8'),
    ('Domain',       Icons.language_outlined,        'google.com'),
    ('Email',        Icons.email_outlined,           'user@example.com'),
    ('Hash',         Icons.fingerprint_outlined,     'MD5 / SHA256'),
    ('URL',          Icons.link_outlined,            'https://...'),
    ('Phone',        Icons.phone_outlined,           '+1-555-0100'),
    ('GitHub',       Icons.code_outlined,            '@username'),
    ('ASN',          Icons.hub_outlined,             'AS15169'),
    ('npm',          Icons.inventory_2_outlined,     'package-name'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    final target = _ctrl.text.trim();
    if (target.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() { _scanning = true; _status = 'Initializing engines...'; });

    try {
      final lang = context.read<AppState>().lang;
      setState(() => _status = 'Running 50+ engines...');
      final data = await ApiService.scan(target, lang: lang);
      final result = ScanResult.fromJson(data);

      if (!mounted) return;
      setState(() => _scanning = false);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => ResultScreen(result: result),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      setState(() { _scanning = false; _status = ''; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}',
            style: const TextStyle(color: TitanTheme.textPrimary)),
        backgroundColor: TitanTheme.bgSecondary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: TitanTheme.bgPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Search Bar ─────────────────────────────────
                _buildSearchCard(),
                const SizedBox(height: 24),

                // ── Target Types ───────────────────────────────
                Text(
                  'SUPPORTED TARGETS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: TitanTheme.textMuted, letterSpacing: 0.12),
                ),
                const SizedBox(height: 10),
                _buildTargetChips(),
                const SizedBox(height: 24),

                // ── Feature Cards ──────────────────────────────
                _buildFeatureGrid(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1121), Color(0xFF080B14)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [TitanTheme.indigo, TitanTheme.cyan]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: TitanTheme.indigo.withAlpha(102),
                            blurRadius: 16),
                      ],
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TITAN OSINT',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              color: TitanTheme.textPrimary)),
                      const Text('Cyber Intelligence Platform',
                          style: TextStyle(fontSize: 12, color: TitanTheme.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  // Status indicator
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Opacity(
                      opacity: _pulse.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: TitanTheme.green.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: TitanTheme.green.withAlpha(76)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  color: TitanTheme.green, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            const Text('ONLINE',
                                style: TextStyle(
                                    fontSize: 10, color: TitanTheme.green,
                                    fontWeight: FontWeight.w600, letterSpacing: 0.06)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scan Target',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: TitanTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('IP · Domain · Email · Hash · URL · Phone · ASN · Username',
              style: TextStyle(fontSize: 12, color: TitanTheme.textMuted)),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            enabled: !_scanning,
            style: const TextStyle(fontFamily: 'monospace',
                fontSize: 14, color: TitanTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: '8.8.8.8 / google.com / user@email.com / +1-555-0100',
              prefixIcon: Icon(Icons.search, color: TitanTheme.textMuted, size: 20),
              suffixIcon: null,
            ),
            onSubmitted: (_) => _runScan(),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 14),
          if (_scanning) ...[
            _buildScanningIndicator(),
            const SizedBox(height: 14),
          ],
          ElevatedButton.icon(
            onPressed: _scanning ? null : _runScan,
            icon: _scanning
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.radar, size: 20),
            label: Text(_scanning ? 'Scanning...' : 'Run Engines'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TitanTheme.indigo,
              disabledBackgroundColor: TitanTheme.indigo.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  color: TitanTheme.indigoLight, strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(_status,
                style: const TextStyle(
                    fontSize: 12, color: TitanTheme.indigoLight,
                    fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
            backgroundColor: Color(0x1A6366F1),
            color: TitanTheme.indigo,
            minHeight: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildTargetChips() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _targetTypes.map((t) {
        return ActionChip(
          avatar: Icon(t.$2, size: 14, color: TitanTheme.indigoLight),
          label: Text(t.$1),
          onPressed: () { _ctrl.text = t.$3; },
        );
      }).toList(),
    );
  }

  Widget _buildFeatureGrid() {
    final features = [
      (Icons.shield_outlined,      '50+ Engines',      'Parallel threat scanning',        TitanTheme.indigo),
      (Icons.psychology_outlined,  'AI Analysis',      'Gemini & GPT-4 fusion',           TitanTheme.cyan),
      (Icons.map_outlined,         'Geo Intelligence', 'IP geolocation mapping',          TitanTheme.green),
      (Icons.hub_outlined,         'Network Graph',    'Relationship visualization',       TitanTheme.amber),
      (Icons.bug_report_outlined,  'MITRE ATT&CK',     'Technique mapping',               TitanTheme.orange),
      (Icons.lock_open_outlined,   'Breach Check',     'HIBP + LeakCheck integration',    TitanTheme.red),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CAPABILITIES',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: TitanTheme.textMuted, letterSpacing: 0.12)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 10,
            mainAxisSpacing: 10, childAspectRatio: 1.7),
          itemCount: features.length,
          itemBuilder: (_, i) {
            final f = features[i];
            return GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(f.$1, color: f.$4, size: 22),
                  const Spacer(),
                  Text(f.$2,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: TitanTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(f.$3,
                      style: const TextStyle(
                          fontSize: 11, color: TitanTheme.textMuted)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
