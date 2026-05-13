import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  static const _levelColor = {
    'CRITICAL': Color(0xFFEF4444),
    'HIGH':     Color(0xFFF97316),
    'MEDIUM':   Color(0xFFF59E0B),
    'LOW':      Color(0xFF10B981),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final h = await ApiService.getHistory();
      final s = await ApiService.getStats();
      setState(() { _history = h; _stats = s; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // Stats
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
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
                                label: 'Total Scans',
                                value: '${_stats['total'] ?? 0}',
                                icon: Icons.radar_outlined,
                                valueColor: TitanTheme.indigoLight,
                              ),
                              MetricCard(
                                label: 'Today',
                                value: '${_stats['today'] ?? 0}',
                                icon: Icons.today_outlined,
                                valueColor: TitanTheme.cyan,
                              ),
                              MetricCard(
                                label: 'Unique Targets',
                                value: '${_stats['unique_targets'] ?? 0}',
                                icon: Icons.fingerprint_outlined,
                                valueColor: TitanTheme.amber,
                              ),
                              MetricCard(
                                label: 'Critical',
                                value: '${_stats['critical'] ?? 0}',
                                icon: Icons.warning_outlined,
                                valueColor: TitanTheme.red,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text('RECENT SCANS',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: TitanTheme.textMuted,
                                  letterSpacing: 0.12)),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),

                  // History list
                  _history.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 56,
                                    color: TitanTheme.textMuted),
                                SizedBox(height: 12),
                                Text('No scans yet',
                                    style: TextStyle(
                                        color: TitanTheme.textMuted,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final h = _history[i] as Map;
                                final score = (h['score'] ?? 0).toInt();
                                final label = h['label'] ?? 'LOW';
                                final col   = _levelColor[label] ?? TitanTheme.textMuted;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 46, height: 46,
                                          decoration: BoxDecoration(
                                            color: col.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                                color: col.withOpacity(0.3)),
                                          ),
                                          child: Center(
                                            child: Text('$score',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: col,
                                                    fontFamily: 'SpaceGrotesk')),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(h['target'] ?? '',
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      color: TitanTheme.textPrimary,
                                                      fontWeight: FontWeight.w500),
                                                  overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: TitanTheme.indigo
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: Text(h['ttype'] ?? '',
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color: TitanTheme.indigoLight)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    (h['ts'] ?? '').toString().length > 16
                                                        ? (h['ts'] ?? '').toString().substring(0, 16)
                                                        : h['ts'] ?? '',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: TitanTheme.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: col.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(label,
                                              style: TextStyle(
                                                  fontSize: 10, fontWeight: FontWeight.w700,
                                                  color: col)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: _history.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}
