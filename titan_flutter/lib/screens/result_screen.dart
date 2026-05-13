import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import 'ai_screen.dart';

class ResultScreen extends StatefulWidget {
  final ScanResult result;
  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  ScanResult get r => widget.result;

  static const _levelColor = {
    'CRITICAL': Color(0xFFEF4444),
    'HIGH':     Color(0xFFF97316),
    'MEDIUM':   Color(0xFFF59E0B),
    'LOW':      Color(0xFF10B981),
  };

  Color get scoreColor =>
      _levelColor[r.score.label] ?? TitanTheme.indigoLight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 200,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmark_outline),
                tooltip: 'Bookmark',
                onPressed: () async {
                  await ApiService.bookmark(r.target, r.ttype);
                  if (!mounted) return;
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⭐ Bookmarked!')));
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildResultHeader(),
            ),
            bottom: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w500, fontSize: 13),
              labelColor: TitanTheme.indigoLight,
              unselectedLabelColor: TitanTheme.textMuted,
              indicatorColor: TitanTheme.indigo,
              indicatorWeight: 2,
              dividerColor: TitanTheme.borderColor,
              tabs: const [
                Tab(text: 'Dashboard'),
                Tab(text: 'Signals'),
                Tab(text: 'TitanAI'),
                Tab(text: 'Raw Data'),
                Tab(text: 'Notes'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _DashboardTab(result: r, scoreColor: scoreColor),
            _SignalsTab(result: r),
            AiTab(result: r),
            _RawDataTab(result: r),
            _NotesTab(result: r),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1121), Color(0xFF080B14)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: TitanTheme.indigo.withAlpha(38),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: TitanTheme.indigo.withAlpha(76)),
                      ),
                      child: Text(
                        r.ttype.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10, color: TitanTheme.indigoLight,
                            fontWeight: FontWeight.w600, letterSpacing: 0.08),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.target,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: TitanTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.fromCache ? '⚡ From cache' : '🔄 Live scan',
                      style: const TextStyle(
                          fontSize: 11, color: TitanTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ScoreBadge(
                  score: r.score.score,
                  label: r.score.label,
                  color: scoreColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Dashboard Tab
// ══════════════════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  final ScanResult result;
  final Color scoreColor;

  const _DashboardTab({required this.result, required this.scoreColor});

  @override
  Widget build(BuildContext context) {
    final r      = result.results;
    final vt     = (r['VirusTotal']     as Map?) ?? {};
    final abuse  = (r['AbuseIPDB']      as Map?) ?? {};
    final shodan = (r['Shodan']         as Map?) ?? {};
    final otx    = (r['AlienVault OTX'] as Map?) ?? {};
    final ipinf  = (r['IPInfo']         as Map?) ?? {};
    final grey   = (r['GreyNoise']      as Map?) ?? {};
    final cip    = (r['CriminalIP']     as Map?) ?? {};
    final iocTotal = result.iocData?.summary['total'] ?? 0;
    final engOk  = r.values
        .where((v) => v is Map && !v.containsKey('error')).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2,
          children: [
            MetricCard(
                label: 'VirusTotal',
                value: '${vt['malicious'] ?? 'N/A'}',
                valueColor: const Color(0xFFEF4444),
                icon: Icons.bug_report_outlined),
            MetricCard(
                label: 'Abuse Score',
                value: '${abuse['abuseConfidenceScore'] ?? 'N/A'}%',
                valueColor: const Color(0xFFF97316),
                icon: Icons.warning_amber_outlined),
            MetricCard(
                label: 'Open Ports',
                value: '${(shodan['ports'] as List?)?.length ?? 0}',
                valueColor: TitanTheme.cyan,
                icon: Icons.settings_ethernet_outlined),
            MetricCard(
                label: 'OTX Pulses',
                value: '${otx['pulse_count'] ?? 'N/A'}',
                valueColor: TitanTheme.amber,
                icon: Icons.rss_feed_outlined),
            MetricCard(
                label: 'IOCs Found',
                value: '$iocTotal',
                valueColor: TitanTheme.amber,
                icon: Icons.search_outlined),
            MetricCard(
                label: 'Engines OK',
                value: '$engOk/${r.length}',
                valueColor: TitanTheme.green,
                icon: Icons.check_circle_outline),
          ],
        ),
        const SizedBox(height: 16),

        // Threat score bar
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('THREAT SCORE',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: TitanTheme.textMuted, letterSpacing: 0.1)),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: result.score.score / 100,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [scoreColor.withAlpha(178), scoreColor]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: scoreColor.withAlpha(102),
                              blurRadius: 8)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${result.score.score}/100',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: scoreColor,
                          fontFamily: 'SpaceGrotesk')),
                  Text(result.score.label,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: scoreColor)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Infrastructure
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INFRASTRUCTURE',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: TitanTheme.textMuted, letterSpacing: 0.1)),
              const SizedBox(height: 12),
              ...[
                ('ORG',     shodan['org']     ?? ipinf['org']),
                ('ISP',     abuse['isp']      ?? shodan['isp']),
                ('COUNTRY', ipinf['country']  ?? shodan['country']),
                ('CITY',    ipinf['city']     ?? shodan['city']),
                ('OS',      shodan['os']),
                ('NOISE',   grey['noise']?.toString()),
                ('CLASS',   grey['classification']),
                ('VPN',     cip['is_vpn']?.toString()),
                ('TOR',     cip['is_tor']?.toString()),
              ].where((e) =>
                  e.$2 != null &&
                  e.$2.toString().isNotEmpty &&
                  e.$2 != 'null' &&
                  e.$2 != 'false').map((e) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(e.$1,
                            style: const TextStyle(
                                fontSize: 11, color: TitanTheme.textMuted,
                                letterSpacing: 0.06)),
                      ),
                      Expanded(
                        child: Text('${e.$2}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: TitanTheme.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Engine contributions
        if (result.score.contributions.isNotEmpty)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ENGINE CONTRIBUTIONS',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: TitanTheme.textMuted, letterSpacing: 0.1)),
                const SizedBox(height: 12),
                ...result.score.contributions.entries.map((e) {
                  final maxVal = result.score.contributions.values
                      .reduce((a, b) => a > b ? a : b);
                  final pct = e.value / maxVal;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: TitanTheme.textSecondary)),
                            Text('${e.value.toStringAsFixed(0)}pts',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scoreColor)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 4,
                            backgroundColor: Colors.white.withAlpha(15),
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

        // Open ports
        if ((result.results['Shodan'] as Map?)?.containsKey('ports') == true) ...[
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OPEN PORTS',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: TitanTheme.textMuted, letterSpacing: 0.1)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ((result.results['Shodan'] as Map)['ports'] as List? ?? [])
                      .take(40)
                      .map((p) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: TitanTheme.cyan.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: TitanTheme.cyan.withAlpha(51)),
                            ),
                            child: Text('$p',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: TitanTheme.cyan,
                                    fontFamily: 'monospace')),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Signals Tab
// ══════════════════════════════════════════════════════════════════
class _SignalsTab extends StatelessWidget {
  final ScanResult result;
  const _SignalsTab({required this.result});

  List<Signal> _buildSignals() {
    final r    = result.results;
    final sigs = <Signal>[];

    final vtM  = ((r['VirusTotal']     as Map?)??{})['malicious']            as int? ?? 0;
    final abS  = ((r['AbuseIPDB']      as Map?)??{})['abuseConfidenceScore'] as int? ?? 0;
    final tfT  = ((r['ThreatFox']      as Map?)??{})['total']                as int? ?? 0;
    final uhC  = ((r['URLhaus']        as Map?)??{})['urls_count']           as int? ?? 0;
    final otxP = ((r['AlienVault OTX'] as Map?)??{})['pulse_count']          as int? ?? 0;
    final hibp = ((r['HaveIBeenPwned'] as Map?)??{})['count']                as int? ?? 0;

    if (vtM  > 0) sigs.add(Signal(level: vtM > 5 ? 'CRITICAL' : 'HIGH',  engine: 'VirusTotal',     message: '$vtM malicious detections'));
    if (abS  > 30) sigs.add(Signal(level: abS > 70 ? 'HIGH' : 'MEDIUM',  engine: 'AbuseIPDB',      message: 'Abuse score $abS%'));
    if (tfT  > 0) sigs.add(Signal(level: 'HIGH',  engine: 'ThreatFox',    message: '$tfT IOC matches'));
    if (uhC  > 0) sigs.add(Signal(level: 'HIGH',  engine: 'URLhaus',       message: '$uhC malicious URLs'));
    if (otxP > 0) sigs.add(Signal(level: 'MEDIUM', engine: 'AlienVault OTX', message: '$otxP threat pulses'));
    if (hibp > 0) sigs.add(Signal(level: 'HIGH',  engine: 'HaveIBeenPwned', message: 'Found in $hibp breaches'));

    final grey = (r['GreyNoise']  as Map?) ?? {};
    final cip  = (r['CriminalIP'] as Map?) ?? {};
    final ipqs = (r['IPQS']       as Map?) ?? {};
    final lk   = (r['LeakCheck']  as Map?) ?? {};

    if (grey['noise'] == true)     sigs.add(Signal(level: 'MEDIUM', engine: 'GreyNoise',  message: 'Known internet scanner'));
    if (cip['is_tor'] == true)     sigs.add(Signal(level: 'HIGH',   engine: 'CriminalIP', message: 'TOR exit node'));
    if (cip['is_scanner'] == true) sigs.add(Signal(level: 'MEDIUM', engine: 'CriminalIP', message: 'Active scanner'));
    if (ipqs['tor'] == true)       sigs.add(Signal(level: 'HIGH',   engine: 'IPQS',       message: 'TOR detected'));
    if (lk['found'] == true || lk['result'] != null)
      sigs.add(Signal(level: 'HIGH', engine: 'LeakCheck', message: 'Credentials in leak DB'));

    return sigs;
  }

  @override
  Widget build(BuildContext context) {
    final signals = _buildSignals();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text('Threat Signals',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: TitanTheme.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: signals.isEmpty
                      ? TitanTheme.green.withAlpha(30)
                      : TitanTheme.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${signals.length} signals',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: signals.isEmpty ? TitanTheme.green : TitanTheme.red)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (signals.isEmpty)
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TitanTheme.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: TitanTheme.green),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('No threats detected',
                      style: TextStyle(color: TitanTheme.green, fontSize: 15)),
                ),
              ],
            ),
          )
        else
          ...signals.map((s) => SignalRow(
              level: s.level, engine: s.engine, message: s.message)),

        if (result.iocData != null && result.iocData!.iocs.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('IOC INDICATORS',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: TitanTheme.textMuted, letterSpacing: 0.1)),
          const SizedBox(height: 10),
          ...result.iocData!.iocs.take(20).map((ioc) {
            final m = ioc as Map;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: TitanTheme.indigo.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${m['type'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 10, color: TitanTheme.indigoLight,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${m['value'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: TitanTheme.textPrimary,
                              fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: '${m['value'] ?? ''}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied!')));
                      },
                      child: const Icon(Icons.copy_outlined,
                          size: 16, color: TitanTheme.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Raw Data Tab
// ══════════════════════════════════════════════════════════════════
class _RawDataTab extends StatefulWidget {
  final ScanResult result;
  const _RawDataTab({required this.result});

  @override
  State<_RawDataTab> createState() => _RawDataTabState();
}

class _RawDataTabState extends State<_RawDataTab> {
  String _filter = '';

  String _prettyJson(dynamic v) {
    try {
      final encoder = const JsonEncoder.withIndent('  ');
      return encoder.convert(v);
    } catch (_) {
      return '$v';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.result.results.entries
        .where((e) => _filter.isEmpty ||
            e.key.toLowerCase().contains(_filter.toLowerCase()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Filter engines...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              final hasErr = (e.value as Map?)?.containsKey('error') ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: hasErr
                            ? TitanTheme.red.withAlpha(76)
                            : TitanTheme.borderColor),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: hasErr
                            ? TitanTheme.red.withAlpha(76)
                            : TitanTheme.borderColor),
                  ),
                  backgroundColor: TitanTheme.bgCard,
                  collapsedBackgroundColor: TitanTheme.bgCard,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasErr
                          ? TitanTheme.red.withAlpha(25)
                          : TitanTheme.green.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(hasErr ? 'ERR' : 'OK',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: hasErr ? TitanTheme.red : TitanTheme.green)),
                  ),
                  title: Text(e.key,
                      style: const TextStyle(
                          fontSize: 13, color: TitanTheme.textPrimary,
                          fontWeight: FontWeight.w500)),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _prettyJson(e.value),
                        style: const TextStyle(
                            fontSize: 11,
                            color: TitanTheme.textSecondary,
                            fontFamily: 'monospace',
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Notes Tab
// ══════════════════════════════════════════════════════════════════
class _NotesTab extends StatefulWidget {
  final ScanResult result;
  const _NotesTab({required this.result});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  final _ctrl   = TextEditingController();
  List<dynamic> _notes  = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await ApiService.getNotes(widget.result.target);
      setState(() { _notes = notes; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveNote() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    await ApiService.saveNote(widget.result.target, body);
    _ctrl.clear();
    HapticFeedback.lightImpact();
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_outlined, size: 48,
                              color: TitanTheme.textMuted),
                          SizedBox(height: 8),
                          Text('No notes yet',
                              style: TextStyle(color: TitanTheme.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notes.length,
                      itemBuilder: (_, i) {
                        final n = _notes[i] as Map;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${n['body'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: TitanTheme.textPrimary)),
                                const SizedBox(height: 6),
                                Text('${n['ts'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: TitanTheme.textMuted)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: TitanTheme.borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                      hintText: 'Add analyst note...'),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _saveNote,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(50, 50),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.save_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
