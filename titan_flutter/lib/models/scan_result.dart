import 'package:flutter/material.dart';

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
        target:    j['target'] as String? ?? '',
        ttype:     j['ttype']  as String? ?? '',
        fromCache: j['from_cache'] as bool? ?? false,
        scanTs:    j['scan_ts']    as String? ?? '',
        score:     ScoreData.fromJson(j['score'] as Map<String, dynamic>? ?? {}),
        iocData:   j['ioc_data'] != null
            ? IocData.fromJson(j['ioc_data'] as Map<String, dynamic>)
            : null,
        results: Map<String, dynamic>.from(j['results'] as Map? ?? {}),
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
        score: (j['score'] as num?)?.toInt() ?? 0,
        label: j['label'] as String? ?? 'N/A',
        color: j['color'] as String? ?? '#888888',
        icon:  j['icon']  as String? ?? '',
        contributions: Map<String, double>.from(
          (j['contributions'] as Map? ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
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
        summary: Map<String, dynamic>.from(j['summary'] as Map? ?? {}),
        iocs:    List<dynamic>.from(j['iocs'] as List? ?? []),
      );
}

class Signal {
  final String level;
  final String engine;
  final String message;
  Signal({required this.level, required this.engine, required this.message});
}
