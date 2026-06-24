import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ApiLicensingScreen extends StatelessWidget {
  const ApiLicensingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('Nexus Developer Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('API Usage', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('B2B SaaS Revenue from 3rd party apps.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.cyanAccent.withAlpha(50))),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total API Calls (This Month)', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('14,502,800', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Estimated Revenue: \$145,028.00', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ).animate().scale(),
          const SizedBox(height: 32),
          const Text('API Keys', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildKeyCard('Production Key', 'sk_live_8f9d...2a1b', Colors.green),
          _buildKeyCard('Test Key', 'sk_test_4c2a...9b4c', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildKeyCard(String name, String keyStr, Color dotColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: dotColor, size: 12),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(keyStr, style: const TextStyle(color: Colors.grey, fontFamily: 'monospace')),
                ],
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.copy, color: Colors.grey), onPressed: () {})
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }
}
