import 'package:flutter/material.dart';
import '../models/miner.dart';
import '../widgets/status_badge.dart';

class MinerDetailScreen extends StatelessWidget {
  final Miner miner;
  const MinerDetailScreen({super.key, required this.miner});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Miner ${miner.ip}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      miner.ip,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    StatusBadge(status: miner.status),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Text('Status: ${miner.status}'),
                const SizedBox(height: 8),
                Text('Notes: This is a PoC. Next step would be to fetch real metrics (hashrate, temp, power).'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
