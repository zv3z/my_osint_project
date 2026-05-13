import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static String baseUrl = 'http://localhost:8000';

  static Future<Map<String, dynamic>> scan(String target,
      {bool useCache = true, String lang = 'ar'}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/scan'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'target': target, 'use_cache': useCache, 'lang': lang}),
        )
        .timeout(const Duration(seconds: 120));
    if (res.statusCode != 200) throw Exception('Scan failed: ${res.body}');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<String> analyze(String target, {String lang = 'ar'}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'target': target, 'lang': lang}),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('Analyze failed');
    return jsonDecode(utf8.decode(res.bodyBytes))['analysis'] as String;
  }

  static Future<String> chat(
      String message, String target, String ttype,
      Map<String, dynamic> results, String aiAnalysis,
      {String lang = 'ar'}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'target': target,
            'ttype': ttype,
            'results': results,
            'ai_analysis': aiAnalysis,
            'lang': lang,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('Chat failed');
    return jsonDecode(utf8.decode(res.bodyBytes))['reply'] as String;
  }

  static Future<List<dynamic>> getHistory({int limit = 50}) async {
    final res = await http
        .get(Uri.parse('$baseUrl/history?limit=$limit'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('History failed');
    return jsonDecode(utf8.decode(res.bodyBytes)) as List;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final res = await http
        .get(Uri.parse('$baseUrl/stats'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Stats failed');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<void> bookmark(String target, String ttype) async {
    await http.post(
      Uri.parse('$baseUrl/bookmark'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target': target, 'ttype': ttype}),
    );
  }

  static Future<List<dynamic>> getNotes(String target) async {
    final res = await http
        .get(Uri.parse('$baseUrl/notes/${Uri.encodeComponent(target)}'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    return jsonDecode(utf8.decode(res.bodyBytes)) as List;
  }

  static Future<void> saveNote(String target, String body) async {
    await http.post(
      Uri.parse('$baseUrl/notes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target': target, 'body': body}),
    );
  }

  static Future<Map<String, dynamic>> getConfig() async {
    final res = await http
        .get(Uri.parse('$baseUrl/config'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw Exception('Config failed');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }
}
