import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() => runApp(const MinerApp());

class MinerApp extends StatelessWidget {
  const MinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BTC Miner Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.orange,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
