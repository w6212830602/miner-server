import 'package:flutter/material.dart';
import '../models/miner.dart';
import 'status_badge.dart';

class MinerCard extends StatelessWidget {
  final Miner miner;
  final VoidCallback? onTap;

  const MinerCard({super.key, required this.miner, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          Icons.dns,
          color: miner.isOnline ? Colors.green : Colors.red,
        ),
        title: Text(miner.ip),
        subtitle: Text('Status: ${miner.status}'),
        trailing: StatusBadge(status: miner.status),
      ),
    );
  }
}
