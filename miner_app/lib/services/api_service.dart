import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/miner.dart';

class ScanResult {
  final List<Miner> miners;
  final int onlineCount;
  final int offlineCount;
  final int? elapsedMs;

  ScanResult({
    required this.miners,
    required this.onlineCount,
    required this.offlineCount,
    required this.elapsedMs,
  });
}

class ApiService {
  /// e.g. http://localhost:8080 
  final String baseUrl;

  ApiService(this.baseUrl);

  String get _cleanBase => baseUrl.trim().replaceAll(RegExp(r'\/+$'), '');

  Uri buildScanUri({
    required String base,
    required int start,
    required int end,
    required int timeoutMs,
    required int workers,
  }) {
    return Uri.parse('$_cleanBase/miners/scan').replace(queryParameters: {
      'base': base,
      'start': start.toString(),
      'end': end.toString(),
      'timeout_ms': timeoutMs.toString(),
      'workers': workers.toString(),
    });
  }

  Future<bool> health() async {
    final uri = Uri.parse('$_cleanBase/health');
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    return resp.statusCode == 200;
  }

  Future<ScanResult> scan({
    required String base,
    required int start,
    required int end,
    required int timeoutMs,
    required int workers,
  }) async {
    final uri = buildScanUri(
      base: base,
      start: start,
      end: end,
      timeoutMs: timeoutMs,
      workers: workers,
    );

    final resp = await http.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = json.decode(resp.body);

    // backend response: { miners: [...] , elapsed_ms: ... }
    final List<dynamic> raw =
        (decoded is Map && decoded['miners'] is List) ? decoded['miners'] : [];

    final miners = raw
        .whereType<Map>()
        .map((m) => Miner.fromJson(m.map((k, v) => MapEntry(k.toString(), v))))
        .toList();

    // stable sorting: online first, then ip
    miners.sort((a, b) {
      final ao = a.isOnline ? 0 : 1;
      final bo = b.isOnline ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      return a.ip.compareTo(b.ip);
    });

    final online = miners.where((m) => m.isOnline).length;
    final offline = miners.length - online;

    final elapsedMs = (decoded is Map && decoded['elapsed_ms'] is num)
        ? (decoded['elapsed_ms'] as num).toInt()
        : null;

    return ScanResult(
      miners: miners,
      onlineCount: online,
      offlineCount: offline,
      elapsedMs: elapsedMs,
    );
  }
}
