import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

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
    _tab = TabController(length: 7, vsync: this);
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

  Future<void> _exportPdf() async {
    final result = r;
    final pdf = pw.Document();
    final scoreHex = {
      'CRITICAL': PdfColors.red,
      'HIGH': PdfColors.orange,
      'MEDIUM': PdfColors.amber,
      'LOW': PdfColors.green,
    }[result.score.label] ?? PdfColors.indigo;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TITAN OSINT REPORT',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(result.target,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Type: ${result.ttype} · ${result.fromCache ? "From cache" : "Live scan"}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: scoreHex,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(children: [
                  pw.Text('${result.score.score}',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text(result.score.label,
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Text('ENGINE RESULTS',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Engine', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                ],
              ),
              ...result.results.entries.map((e) {
                final hasErr = (e.value as Map?)?.containsKey('error') ?? false;
                return pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(hasErr ? 'Error' : 'OK',
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: hasErr ? PdfColors.red : PdfColors.green,
                              fontWeight: pw.FontWeight.bold))),
                ]);
              }),
            ],
          ),
          if (result.iocData != null && result.iocData!.iocs.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('IOC INDICATORS',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...result.iocData!.iocs.take(15).map((ioc) {
              final m = ioc as Map;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(color: PdfColors.indigo50,
                        border: pw.Border.all(color: PdfColors.indigo200)),
                    child: pw.Text('${m['type'] ?? ''}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.indigo)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text('${m['value'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                ]),
              );
            }),
          ],
        ],
      ),
    );

    final filename = 'titan-${result.target.replaceAll(RegExp(r'[^\w\-]'), '_')}.pdf';
    await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
  }

  Future<void> _shareReport() async {
    try {
      final data = await ApiService.share(r.target);
      final token = data['token'] ?? data['url'] ?? data['share_url'] ?? '';
      final shareUrl = token.toString().startsWith('http')
          ? token.toString()
          : '${ApiService.baseUrl}/share/$token';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share link: $shareUrl'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () => Clipboard.setData(ClipboardData(text: shareUrl)),
          ),
        ),
      );
      await Share.share(
        'Titan OSINT Report for ${r.target}\n$shareUrl',
        subject: 'Titan OSINT – ${r.target}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

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
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
                onPressed: _exportPdf,
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Report',
                onPressed: _shareReport,
              ),
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
                Tab(text: 'Map'),
                Tab(text: 'Graph'),
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
            _MapTab(result: r),
            _GraphTab(result: r),
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

        // Discovered entities
        _EntitiesSection(raw: result.results),
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
// Entities Section (used by Dashboard Tab)
// ══════════════════════════════════════════════════════════════════
List<(String, String)> _extractEntities(Map<String, dynamic> raw) {
  final entities = <(String, String)>[];
  final ipRe     = RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b');
  final emailRe  = RegExp(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b');
  final urlRe    = RegExp(r"""https?://[^\s'">,]+""");
  final domainRe = RegExp(r'\b([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\b');
  final text     = raw.toString();

  final seen = <String>{};

  for (final m in emailRe.allMatches(text).take(5)) {
    final v = m.group(0)!;
    if (seen.add(v)) entities.add((v, 'EMAIL'));
  }
  for (final m in urlRe.allMatches(text).take(5)) {
    final v = m.group(0)!;
    if (seen.add(v)) entities.add((v, 'URL'));
  }
  for (final m in ipRe.allMatches(text).take(8)) {
    final v = m.group(0)!;
    if (seen.add(v)) entities.add((v, 'IP'));
  }
  for (final m in domainRe.allMatches(text).take(6)) {
    final v = m.group(0)!;
    // Skip entries already captured as IP, URL, or email
    if (seen.add(v)) entities.add((v, 'DOMAIN'));
  }

  return entities;
}

class _EntitiesSection extends StatelessWidget {
  final Map<String, dynamic> raw;
  const _EntitiesSection({required this.raw});

  static const _typeColor = {
    'IP':     Color(0xFF22D3EE),   // cyan
    'DOMAIN': Color(0xFF6366F1),   // indigo
    'EMAIL':  Color(0xFFF59E0B),   // amber
    'URL':    Color(0xFF10B981),   // green
  };

  @override
  Widget build(BuildContext context) {
    final entities = _extractEntities(raw);
    if (entities.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENTITIES FOUND',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: TitanTheme.textMuted, letterSpacing: 0.1)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entities.map((e) {
              final color = _typeColor[e.$2] ?? TitanTheme.indigoLight;
              return Tooltip(
                message: e.$1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.$2,
                          style: TextStyle(
                              fontSize: 9, color: color,
                              fontWeight: FontWeight.w700, letterSpacing: 0.05)),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(e.$1,
                            style: const TextStyle(
                                fontSize: 11, color: TitanTheme.textPrimary,
                                fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
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

    final grey  = (r['GreyNoise']   as Map?) ?? {};
    final cip   = (r['CriminalIP']  as Map?) ?? {};
    final ipqs  = (r['IPQS']        as Map?) ?? {};
    final lk    = (r['LeakCheck']   as Map?) ?? {};
    final pt    = (r['PhishTank']   as Map?) ?? {};
    final gsb   = (r['Google SafeBrowsing'] as Map?) ?? {};
    final erep  = (r['EmailRep']    as Map?) ?? {};
    final sfs   = (r['StopForumSpam'] as Map?) ?? {};
    final spamh = (r['SpamHaus']    as Map?) ?? {};
    final dh    = (r['Dehashed']    as Map?) ?? {};
    final uname = (r['Username Search'] as Map?) ?? {};
    final mb    = (r['MalwareBazaar'] as Map?) ?? {};

    if (grey['noise'] == true)     sigs.add(Signal(level: 'MEDIUM', engine: 'GreyNoise',   message: 'Known internet scanner'));
    if (cip['is_tor'] == true)     sigs.add(Signal(level: 'HIGH',   engine: 'CriminalIP',  message: 'TOR exit node'));
    if (cip['is_scanner'] == true) sigs.add(Signal(level: 'MEDIUM', engine: 'CriminalIP',  message: 'Active scanner'));
    if (ipqs['tor'] == true)       sigs.add(Signal(level: 'HIGH',   engine: 'IPQS',        message: 'TOR detected'));
    if (lk['found'] == true || lk['result'] != null)
      sigs.add(Signal(level: 'HIGH', engine: 'LeakCheck', message: 'Credentials in leak DB'));

    // New engine signals
    if (pt['in_database'] == true) sigs.add(Signal(level: 'CRITICAL', engine: 'PhishTank', message: 'Known phishing URL in database'));
    if (gsb['safe'] == false)      sigs.add(Signal(level: 'HIGH', engine: 'Google SafeBrowsing', message: 'Flagged: ${(gsb['threats'] as List?)?.join(', ') ?? 'unsafe'}'));
    if (erep['suspicious'] == true) sigs.add(Signal(level: 'MEDIUM', engine: 'EmailRep', message: 'Suspicious email reputation'));
    if (erep['malicious_activity'] == true) sigs.add(Signal(level: 'HIGH', engine: 'EmailRep', message: 'Malicious activity linked to email'));
    if (erep['credentials_leaked'] == true) sigs.add(Signal(level: 'HIGH', engine: 'EmailRep', message: 'Credentials leaked'));
    if (erep['data_breach'] == true) sigs.add(Signal(level: 'MEDIUM', engine: 'EmailRep', message: 'Found in data breach'));
    if (sfs['appears'] == true) sigs.add(Signal(level: 'MEDIUM', engine: 'StopForumSpam', message: 'In spam database (${sfs['frequency'] ?? 0} reports)'));
    if ((spamh['zone_count'] as int? ?? 0) > 0) sigs.add(Signal(level: 'HIGH', engine: 'SpamHaus', message: 'Blacklisted: ${(spamh['zones'] as List?)?.join(', ') ?? 'listed'}'));
    final dhTotal = (dh['total'] as int?) ?? 0;
    if (dhTotal > 0) sigs.add(Signal(level: 'HIGH', engine: 'Dehashed', message: '$dhTotal breach records found'));
    if (mb['file_name'] != null) sigs.add(Signal(level: 'CRITICAL', engine: 'MalwareBazaar', message: 'Malware: ${mb['file_name']} (${mb['file_type'] ?? ''})'));
    final foundOn = (uname['found_on'] as List?)?.length ?? 0;
    if (foundOn > 0) sigs.add(Signal(level: 'LOW', engine: 'Username Search', message: 'Found on $foundOn platforms'));

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

// ══════════════════════════════════════════════════════════════════
// Map Tab
// ══════════════════════════════════════════════════════════════════
class _MapTab extends StatelessWidget {
  final ScanResult result;
  const _MapTab({required this.result});

  List<Map<String, dynamic>> _extractGeoPoints() {
    final points = <Map<String, dynamic>>[];
    final res = result.results;

    void tryAdd(Map? data, String source) {
      if (data == null) return;
      // Support both lat/lon and latitude/longitude field names
      final lat = ((data['lat'] ?? data['latitude']) as num?)?.toDouble();
      final lon = ((data['lon'] ?? data['longitude']) as num?)?.toDouble();
      if (lat == null || lon == null || (lat == 0 && lon == 0)) return;
      final city    = data['city']    as String? ?? '';
      final country = data['country'] as String? ?? '';
      final isp     = data['isp']     as String? ?? '';
      final org     = data['org']     as String? ?? '';
      final asn     = data['asn']     as String? ?? '';
      points.add({
        'lat': lat,
        'lon': lon,
        'label': [city, country].where((s) => s.isNotEmpty).join(', '),
        'source': source,
        'isp': isp.isNotEmpty ? isp : org,
        'asn': asn,
      });
    }

    tryAdd(res['IPapi']  as Map?, 'IPapi');
    tryAdd(res['IPInfo'] as Map?, 'IPInfo');
    tryAdd(res['Shodan'] as Map?, 'Shodan');
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final points = _extractGeoPoints();

    if (points.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 56, color: TitanTheme.textMuted),
            SizedBox(height: 12),
            Text('No geo data available',
                style: TextStyle(color: TitanTheme.textMuted, fontSize: 15)),
            SizedBox(height: 8),
            Text('Requires IPInfo or Shodan API key',
                style: TextStyle(color: TitanTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    final first = points.first;
    final center = LatLng(first['lat'] as double, first['lon'] as double);

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 4),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.titan.osint',
        ),
        MarkerLayer(
          markers: points.map((p) {
            final lat   = p['lat']   as double;
            final lon   = p['lon']   as double;
            final label = p['label'] as String;
            final isp   = p['isp']   as String;
            final asn   = p['asn']   as String;
            return Marker(
              point: LatLng(lat, lon),
              width: 180,
              height: 110,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1121).withAlpha(230),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TitanTheme.indigo.withAlpha(180)),
                      boxShadow: [
                        BoxShadow(
                            color: TitanTheme.indigo.withAlpha(120),
                            blurRadius: 14,
                            spreadRadius: 2),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label.isEmpty ? '—' : label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        if (isp.isNotEmpty)
                          Text(isp,
                              style: const TextStyle(
                                  color: TitanTheme.cyan, fontSize: 9),
                              overflow: TextOverflow.ellipsis),
                        if (asn.isNotEmpty)
                          Text(asn,
                              style: const TextStyle(
                                  color: TitanTheme.textMuted, fontSize: 9),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Glowing pin
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEF4444),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFEF4444).withAlpha(180),
                            blurRadius: 12,
                            spreadRadius: 3),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Network Graph Tab
// ══════════════════════════════════════════════════════════════════
class _GraphNode {
  final String label;
  final Color  color;
  const _GraphNode({required this.label, required this.color});
}

class _GraphTab extends StatelessWidget {
  final ScanResult result;
  const _GraphTab({required this.result});

  static const _levelColor = {
    'CRITICAL': Color(0xFFEF4444),
    'HIGH':     Color(0xFFF97316),
    'MEDIUM':   Color(0xFFF59E0B),
    'LOW':      Color(0xFF10B981),
  };

  List<_GraphNode> _buildNodes() {
    final nodes = <_GraphNode>[];
    final r = result.results;
    final seen = <String>{};

    void add(String label, Color color) {
      final key = label.toLowerCase();
      if (key.isEmpty || !seen.add(key)) return;
      nodes.add(_GraphNode(label: label, color: color));
    }

    // Hostnames from Shodan
    for (final h in ((r['Shodan'] as Map?)?['hostnames'] as List? ?? []).take(4)) {
      add('$h', TitanTheme.cyan);
    }

    // Open ports from Shodan
    for (final p in ((r['Shodan'] as Map?)?['ports'] as List? ?? []).take(5)) {
      add(':$p', TitanTheme.amber);
    }

    // A records from SecurityTrails
    for (final ip in ((r['SecurityTrails'] as Map?)?['a_records'] as List? ?? []).take(4)) {
      add('$ip', TitanTheme.green);
    }

    // MX records from SecurityTrails
    for (final mx in ((r['SecurityTrails'] as Map?)?['mx_records'] as List? ?? []).take(3)) {
      add('MX:$mx', TitanTheme.orange);
    }

    // Robtex IP records
    for (final rec in ((r['Robtex'] as Map?)?['records'] as List? ?? []).take(4)) {
      if (rec is Map) {
        final ip = rec['ip'] ?? rec['name'];
        if (ip != null) add('$ip', TitanTheme.green);
      }
    }

    return nodes.take(14).toList();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _buildNodes();
    final scoreColor = _levelColor[result.score.label] ?? TitanTheme.indigoLight;

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _NetworkPainter(
              target: result.target,
              nodes: nodes,
              scoreColor: scoreColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: TitanTheme.borderColor)),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _LegendDot(color: TitanTheme.indigo,  label: 'Target'),
              _LegendDot(color: TitanTheme.cyan,    label: 'Host'),
              _LegendDot(color: TitanTheme.green,   label: 'IP'),
              _LegendDot(color: TitanTheme.amber,   label: 'Port'),
              _LegendDot(color: TitanTheme.orange,  label: 'MX'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: TitanTheme.textMuted, fontSize: 11)),
    ]);
  }
}

class _NetworkPainter extends CustomPainter {
  final String target;
  final List<_GraphNode> nodes;
  final Color scoreColor;

  const _NetworkPainter({
    required this.target,
    required this.nodes,
    required this.scoreColor,
  });

  void _drawLabel(Canvas canvas, String text, Offset pos, double fontSize, Color color) {
    final maxChars = (fontSize < 10) ? 10 : 13;
    final label = text.length > maxChars ? '${text.substring(0, maxChars - 2)}..' : text;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final radius = math.min(cx, cy) * 0.65;

    // Edge paint
    final edgePaint = Paint()
      ..color = const Color(0x20FFFFFF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Draw edges first
    for (int i = 0; i < nodes.length; i++) {
      final angle = (2 * math.pi * i / nodes.length) - math.pi / 2;
      final np = Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle));
      canvas.drawLine(center, np, edgePaint);
    }

    // Center node (target)
    canvas.drawCircle(center, 44,
        Paint()..color = scoreColor.withAlpha(38)..style = PaintingStyle.fill);
    canvas.drawCircle(center, 44,
        Paint()..color = scoreColor..strokeWidth = 2..style = PaintingStyle.stroke);
    _drawLabel(canvas, target.split('.').first, center, 10, Colors.white);
    _drawLabel(canvas, nodes.isEmpty ? 'No links' : '',
        center + const Offset(0, 14), 8, const Color(0xFF94A3B8));

    // Peripheral nodes
    for (int i = 0; i < nodes.length; i++) {
      final angle = (2 * math.pi * i / nodes.length) - math.pi / 2;
      final np = Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle));
      final node = nodes[i];

      canvas.drawCircle(np, 26,
          Paint()..color = node.color.withAlpha(38)..style = PaintingStyle.fill);
      canvas.drawCircle(np, 26,
          Paint()..color = node.color.withAlpha(153)..strokeWidth = 1.5..style = PaintingStyle.stroke);
      _drawLabel(canvas, node.label, np, 9, node.color);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter old) =>
      old.target != target || old.nodes.length != nodes.length;
}
