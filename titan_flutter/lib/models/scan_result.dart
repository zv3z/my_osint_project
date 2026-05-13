class ScanResult {
  final String target;
  final String ttype;
  final bool fromCache;
  final String scanTs;
  final ScoreData score;
  final IocData? iocData;
  final Map<String, dynamic> results;

  ScanResult({
    required this.target,
    required this.ttype,
    required this.fromCache,
    required this.scanTs,
    required this.score,
    this.iocData,
    required this.results,
  });

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        target:    j['target'] ?? '',
        ttype:     j['ttype'] ?? '',
        fromCache: j['from_cache'] ?? false,
        scanTs:    j['scan_ts'] ?? '',
        score:     ScoreData.fromJson(j['score'] ?? {}),
        iocData:   j['ioc_data'] != null ? IocData.fromJson(j['ioc_data']) : null,
        results:   Map<String, dynamic>.from(j['results'] ?? {}),
      );
}

class ScoreData {
  final int score;
  final String label;
  final String color;
  final String icon;
  final Map<String, double> contributions;

  ScoreData({
    required this.score,
    required this.label,
    required this.color,
    required this.icon,
    required this.contributions,
  });

  factory ScoreData.fromJson(Map<String, dynamic> j) => ScoreData(
        score: (j['score'] ?? 0).toInt(),
        label: j['label'] ?? 'N/A',
        color: j['color'] ?? '#888888',
        icon:  j['icon']  ?? '',
        contributions: Map<String, double>.from(
          (j['contributions'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
        ),
      );

  Color get flutterColor {
    switch (label) {
      case 'CRITICAL': return const Color(0xFFEF4444);
      case 'HIGH':     return const Color(0xFFF97316);
      case 'MEDIUM':   return const Color(0xFFF59E0B);
      default:         return const Color(0xFF10B981);
    }
  }
}

class IocData {
  final Map<String, dynamic> summary;
  final List<dynamic> iocs;

  IocData({required this.summary, required this.iocs});

  factory IocData.fromJson(Map<String, dynamic> j) => IocData(
        summary: Map<String, dynamic>.from(j['summary'] ?? {}),
        iocs:    List<dynamic>.from(j['iocs'] ?? []),
      );
}

class Signal {
  final String level;
  final String engine;
  final String message;

  Signal({required this.level, required this.engine, required this.message});
}

// ignore: avoid_classes_with_only_static_members
class Color {
  final int value;
  const Color(this.value);
}
