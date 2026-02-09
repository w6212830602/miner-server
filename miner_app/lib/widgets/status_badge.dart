import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status; // online/offline/unknown
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final isOnline = s == 'online';

    final text = (s == 'online')
        ? 'Online'
        : (s == 'offline')
            ? 'Offline'
            : 'Unknown';

    final color = isOnline ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
