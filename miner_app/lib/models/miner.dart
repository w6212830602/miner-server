class Miner {
  final String ip;
  final String status; // "online" | "offline" | "unknown"

  Miner({
    required this.ip,
    required this.status,
  });

  bool get isOnline => status.toLowerCase() == 'online';

  factory Miner.fromJson(Map<String, dynamic> json) {
    return Miner(
      ip: (json['ip'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString().toLowerCase(),
    );
  }
}
