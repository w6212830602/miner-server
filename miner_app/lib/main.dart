import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MinerApp());

class MinerApp extends StatelessWidget {
  const MinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.orange, brightness: Brightness.dark),
      home: const MinerListScreen(),
      debugShowCheckedModeBanner: true,
    );
  }
}

class MinerListScreen extends StatefulWidget {
  const MinerListScreen({super.key});

  @override
  State<MinerListScreen> createState() => _MinerListScreenState();
}

class _MinerListScreenState extends State<MinerListScreen> {
  List<Map<String, dynamic>> miners = [];
  bool isLoading = false;

  // ✅ Backend host（可換成筆電 IP，例如 http://192.168.1.50:8080）
  final TextEditingController _backendUrlCtrl =
      TextEditingController(text: 'http://localhost:8080');

  // ✅ 掃描參數（對應 Go /scan?base=...&start=...&end=...&timeout_ms=...&workers=...）
  final TextEditingController _baseCtrl = TextEditingController(text: '192.168.1');
  final TextEditingController _startCtrl = TextEditingController(text: '100');
  final TextEditingController _endCtrl = TextEditingController(text: '110');
  final TextEditingController _timeoutCtrl = TextEditingController(text: '500');
  final TextEditingController _workersCtrl = TextEditingController(text: '30');

  String? lastScanSummary;

  int get onlineCount => miners.where((m) => (m['status'] ?? '') == 'Online').length;
  int get offlineCount => miners.length - onlineCount;

  int _parseInt(TextEditingController c, int def) {
    final v = c.text.trim();
    final n = int.tryParse(v);
    return n ?? def;
  }

  Uri _buildScanUri() {
    final baseUrl = _backendUrlCtrl.text.trim().replaceAll(RegExp(r'\/+$'), '');
    final base = _baseCtrl.text.trim();
    final start = _parseInt(_startCtrl, 100);
    final end = _parseInt(_endCtrl, 110);
    final timeoutMs = _parseInt(_timeoutCtrl, 500);
    final workers = _parseInt(_workersCtrl, 30);

    return Uri.parse('$baseUrl/scan').replace(queryParameters: {
      'base': base,
      'start': start.toString(),
      'end': end.toString(),
      'timeout_ms': timeoutMs.toString(),
      'workers': workers.toString(),
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _validateInputs() {
    final start = _parseInt(_startCtrl, 100);
    final end = _parseInt(_endCtrl, 110);

    if (start > end) {
      _showSnack('Invalid range: start must be <= end.');
      return false;
    }

    // ✅ 你可以調整上限，避免 demo 時掃太大範圍卡住
    final range = end - start + 1;
    if (range > 512) {
      _showSnack('Warning: range is large ($range IPs). Consider smaller range for demo.');
      // 不阻止，只提醒；你也可以改成 return false;
    }

    final base = _baseCtrl.text.trim();
    if (base.isEmpty || !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(base)) {
      _showSnack('Base should look like: 192.168.1');
      return false;
    }

    final backend = _backendUrlCtrl.text.trim();
    if (!backend.startsWith('http://') && !backend.startsWith('https://')) {
      _showSnack('Backend URL must start with http:// or https://');
      return false;
    }

    return true;
  }

  Future<void> scanMiners() async {
    if (isLoading) return;
    if (!_validateInputs()) return;

    setState(() => isLoading = true);

    final uri = _buildScanUri();
    lastScanSummary = uri.toString();

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final decoded = json.decode(response.body);

      // ✅ 相容兩種格式：
      // 1) 舊版：直接回傳 List
      // 2) 新版：{ miners: [...] }
      final List<dynamic> rawList = decoded is List
          ? decoded
          : (decoded is Map && decoded['miners'] is List)
              ? decoded['miners']
              : [];

      final list = rawList
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList()
          .cast<Map<String, dynamic>>();

      // ✅ 排序：Online 先，然後依 IP 排
      list.sort((a, b) {
        final aOnline = (a['status'] == 'Online') ? 0 : 1;
        final bOnline = (b['status'] == 'Online') ? 0 : 1;
        if (aOnline != bOnline) return aOnline.compareTo(bOnline);

        final aip = (a['ip'] ?? '').toString();
        final bip = (b['ip'] ?? '').toString();
        return aip.compareTo(bip);
      });

      if (!mounted) return;
      setState(() => miners = list);

      _showSnack('Scan complete. Online: $onlineCount, Offline: $offlineCount');
    } catch (e) {
      _showSnack('Scan failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _backendUrlCtrl.dispose();
    _baseCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _timeoutCtrl.dispose();
    _workersCtrl.dispose();
    super.dispose();
  }

  Widget _paramField({
    required TextEditingController controller,
    required String label,
    String? hint,
    double? width,
  }) {
    final field = TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );

    if (width == null) return field;
    return SizedBox(width: width, child: field);
  }

  @override
  Widget build(BuildContext context) {
    final scanInfo = lastScanSummary;

    return Scaffold(
      appBar: AppBar(title: const Text("BTC Miner Monitor")),
      body: Column(
        children: [
          // Backend URL
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _paramField(
              controller: _backendUrlCtrl,
              label: 'Backend URL',
              hint: 'http://localhost:8080',
            ),
          ),

          // Scan params row 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _paramField(controller: _baseCtrl, label: 'Base', hint: '192.168.1', width: 160),
                _paramField(controller: _startCtrl, label: 'Start', hint: '100', width: 110),
                _paramField(controller: _endCtrl, label: 'End', hint: '110', width: 110),
                _paramField(controller: _timeoutCtrl, label: 'Timeout(ms)', hint: '500', width: 140),
                _paramField(controller: _workersCtrl, label: 'Workers', hint: '30', width: 120),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Button + summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : scanMiners,
                    child: Text(isLoading ? "Scanning..." : "Start Network Scan"),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Online: $onlineCount  Offline: $offlineCount'),
              ],
            ),
          ),

          // Show current request (super helpful for demo)
          if (scanInfo != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isLoading ? 'Request: $scanInfo (running...)' : 'Request: $scanInfo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          Expanded(
            child: miners.isEmpty
                ? const Center(child: Text('No results yet. Start a scan.'))
                : ListView.builder(
                    itemCount: miners.length,
                    itemBuilder: (context, index) {
                      final miner = miners[index];
                      final status = (miner['status'] ?? 'Unknown').toString();
                      final ip = (miner['ip'] ?? '').toString();
                      final isOnline = status == "Online";

                      return ListTile(
                        leading: Icon(Icons.dns, color: isOnline ? Colors.green : Colors.red),
                        title: Text("IP: $ip"),
                        subtitle: Text("Status: $status"),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
