import 'package:flutter/material.dart';
import '../models/miner.dart';
import '../services/api_service.dart';
import '../widgets/miner_card.dart';
import 'miner_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Controllers
  final _backendUrlCtrl = TextEditingController(text: 'http://localhost:8080');
  final _baseCtrl = TextEditingController(text: '192.168.1');
  final _startCtrl = TextEditingController(text: '100');
  final _endCtrl = TextEditingController(text: '110');
  final _timeoutCtrl = TextEditingController(text: '500');
  final _workersCtrl = TextEditingController(text: '30');

  bool isLoading = false;
  List<Miner> miners = [];
  String? lastRequest;
  int onlineCount = 0;
  int offlineCount = 0;
  int? elapsedMs;

  int _parseInt(TextEditingController c, int def) {
    final n = int.tryParse(c.text.trim());
    return n ?? def;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 支援兩種輸入：
  /// 1) 三段 base: 192.168.1  -> scan 192.168.1.{start..end}
  /// 2) 完整 IP : 127.0.0.1  -> 自動 normalize 成 base=127.0.0, start=end=1
  ///
  /// 回傳 (base, start, end)
  (String base, int start, int end) _normalizeBaseAndRange({
    required String rawBase,
    required int start,
    required int end,
  }) {
    final base = rawBase.trim();

    // full ip pattern: a.b.c.d
    final fullIpMatch = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
        .firstMatch(base);

    if (fullIpMatch != null) {
      final a = int.parse(fullIpMatch.group(1)!);
      final b = int.parse(fullIpMatch.group(2)!);
      final c = int.parse(fullIpMatch.group(3)!);
      final d = int.parse(fullIpMatch.group(4)!);

      // keep it simple: validate 0..255
      bool ok(int x) => x >= 0 && x <= 255;
      if (ok(a) && ok(b) && ok(c) && ok(d)) {
        final base3 = '$a.$b.$c';
        return (base3, d, d);
      }
    }

    // three-octet base pattern: a.b.c
    final base3Match = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(base);
    if (base3Match != null) {
      final a = int.parse(base3Match.group(1)!);
      final b = int.parse(base3Match.group(2)!);
      final c = int.parse(base3Match.group(3)!);

      bool ok(int x) => x >= 0 && x <= 255;
      if (ok(a) && ok(b) && ok(c)) {
        return (base, start, end);
      }
    }

    // if invalid, return as-is (validation will catch)
    return (base, start, end);
  }

  bool _validateAndMaybeNormalizeInputs() {
    final backend = _backendUrlCtrl.text.trim();
    if (!backend.startsWith('http://') && !backend.startsWith('https://')) {
      _snack('Backend URL must start with http:// or https://');
      return false;
    }

    final rawBase = _baseCtrl.text.trim();
    if (rawBase.isEmpty) {
      _snack('Base is required. e.g. 192.168.1 or 127.0.0.1');
      return false;
    }

    var start = _parseInt(_startCtrl, 100);
    var end = _parseInt(_endCtrl, 110);

    final normalized = _normalizeBaseAndRange(rawBase: rawBase, start: start, end: end);
    final base = normalized.$1;
    start = normalized.$2;
    end = normalized.$3;

    // validate base format after normalization
    final isThreeOctet = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(base);
    if (!isThreeOctet) {
      _snack('Base should look like: 192.168.1 (or full IP like 127.0.0.1)');
      return false;
    }

    // validate range
    if (start > end) {
      _snack('Invalid range: start must be <= end.');
      return false;
    }
    if (start < 1 || start > 254 || end < 1 || end > 254) {
      _snack('Start/End must be within 1..254');
      return false;
    }

    // large range warning
    final range = end - start + 1;
    if (range > 512) {
      _snack('Range is large ($range IPs). Consider smaller range for demo.');
    }

    // If user entered full IP, normalize the UI fields to avoid confusion
    final rawWasFullIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(rawBase);
    if (rawWasFullIp) {
      // update UI controllers to normalized values
      _baseCtrl.text = base;
      _startCtrl.text = start.toString();
      _endCtrl.text = end.toString();

      // keep cursor at end (nice UX)
      _baseCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _baseCtrl.text.length));
      _startCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _startCtrl.text.length));
      _endCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _endCtrl.text.length));
    }

    return true;
  }

  Future<void> _scan() async {
    if (isLoading) return;

    // Validate & normalize (may update controllers)
    if (!_validateAndMaybeNormalizeInputs()) return;

    setState(() => isLoading = true);

    final api = ApiService(_backendUrlCtrl.text.trim());

    // read possibly-normalized values
    final base = _baseCtrl.text.trim();
    final start = _parseInt(_startCtrl, 100);
    final end = _parseInt(_endCtrl, 110);
    final timeoutMs = _parseInt(_timeoutCtrl, 500);
    final workers = _parseInt(_workersCtrl, 30);

    final uri = api.buildScanUri(
      base: base,
      start: start,
      end: end,
      timeoutMs: timeoutMs,
      workers: workers,
    );
    lastRequest = uri.toString();

    try {
      // Fast fail: backend health check
      final ok = await api.health();
      if (!ok) {
        throw Exception('Backend health check failed.');
      }

      final result = await api.scan(
        base: base,
        start: start,
        end: end,
        timeoutMs: timeoutMs,
        workers: workers,
      );

      if (!mounted) return;
      setState(() {
        miners = result.miners;
        onlineCount = result.onlineCount;
        offlineCount = result.offlineCount;
        elapsedMs = result.elapsedMs;
      });

      _snack('Scan complete. Online: $onlineCount, Offline: $offlineCount');
    } catch (e) {
      _snack('Scan failed: $e');
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    double? width,
  }) {
    final child = TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final request = lastRequest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BTC Miner Monitor'),
        actions: [
          IconButton(
            tooltip: 'Scan',
            onPressed: isLoading ? null : _scan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _field(
              controller: _backendUrlCtrl,
              label: 'Backend URL',
              hint: 'http://localhost:8080',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(
                  controller: _baseCtrl,
                  label: 'Base (or full IP)',
                  hint: '192.168.1  or  127.0.0.1',
                  width: 220,
                ),
                _field(controller: _startCtrl, label: 'Start', hint: '100', width: 110),
                _field(controller: _endCtrl, label: 'End', hint: '110', width: 110),
                _field(controller: _timeoutCtrl, label: 'Timeout(ms)', hint: '500', width: 140),
                _field(controller: _workersCtrl, label: 'Workers', hint: '30', width: 120),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _scan,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(isLoading ? 'Scanning...' : 'Start Network Scan'),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Online: $onlineCount'),
                    Text('Offline: $offlineCount'),
                    if (elapsedMs != null) Text('Time: ${elapsedMs}ms'),
                  ],
                ),
              ],
            ),
          ),
          if (request != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isLoading ? 'Request: $request (running...)' : 'Request: $request',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: miners.isEmpty
                ? const Center(child: Text('No results yet. Start a scan.'))
                : RefreshIndicator(
                    onRefresh: _scan,
                    child: ListView.builder(
                      itemCount: miners.length,
                      itemBuilder: (context, index) {
                        final miner = miners[index];
                        return MinerCard(
                          miner: miner,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MinerDetailScreen(miner: miner),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
