import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  List<dynamic> _watched = [];
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
      final w = await ApiService.getWatched();
      setState(() { _watched = w; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _watched.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _watched.length,
                    itemBuilder: (_, i) => _buildCard(_watched[i] as Map),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: TitanTheme.indigo.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TitanTheme.indigo.withAlpha(51)),
            ),
            child: const Icon(Icons.bookmark_border_outlined,
                color: TitanTheme.indigoLight, size: 32),
          ),
          const SizedBox(height: 16),
          Text('No watched targets',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: TitanTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Bookmark targets from scan results\nto track them here',
            textAlign: TextAlign.center,
            style: TextStyle(color: TitanTheme.textMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map h) {
    final score  = (h['score'] ?? 0) as int;
    final level  = (h['level'] ?? 'UNKNOWN') as String;
    final col    = _levelColor[level] ?? TitanTheme.textMuted;
    final target = h['target'] ?? '';
    final ttype  = h['ttype'] ?? '';
    final lastScan = h['last_scan'] as String?;

    String timeAgo = 'Never scanned';
    if (lastScan != null) {
      try {
        final diff = DateTime.now().difference(DateTime.parse(lastScan));
        if (diff.inDays > 0)        timeAgo = '${diff.inDays}d ago';
        else if (diff.inHours > 0)  timeAgo = '${diff.inHours}h ago';
        else                        timeAgo = '${diff.inMinutes}m ago';
      } catch (_) {
        timeAgo = lastScan.length > 16 ? lastScan.substring(0, 16) : lastScan;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Score badge
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: col.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: col.withAlpha(76)),
              ),
              child: Center(
                child: Text('$score',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: col, fontFamily: 'SpaceGrotesk')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target,
                      style: const TextStyle(
                          fontSize: 14, color: TitanTheme.textPrimary,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: TitanTheme.indigo.withAlpha(25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(ttype,
                          style: const TextStyle(
                              fontSize: 10, color: TitanTheme.indigoLight)),
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgo,
                        style: const TextStyle(
                            fontSize: 11, color: TitanTheme.textMuted)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: col.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(level,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: col)),
            ),
          ],
        ),
      ),
    );
  }
}
