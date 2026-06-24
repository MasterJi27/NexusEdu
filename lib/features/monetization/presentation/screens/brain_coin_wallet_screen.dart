import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BrainCoinWalletScreen extends StatelessWidget {
  const BrainCoinWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(title: const Text('Nexus Wallet', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.monetization_on, color: Colors.yellowAccent, size: 100).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.1),
          const SizedBox(height: 16),
          const Text('1,450', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
          const Text('Brain Coins Balance', style: TextStyle(color: Colors.white54, fontSize: 18)),
          const SizedBox(height: 48),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top Up Coins', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildCoinPack('500 Coins', '₹49'),
                  _buildCoinPack('1200 Coins + 10% Bonus', '₹99', isPopular: true),
                  _buildCoinPack('5000 Coins + 25% Bonus', '₹399'),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCoinPack(String coins, String price, {bool isPopular = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: isPopular ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coins, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                if (isPopular) const Text('Most Popular', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: Text(price),
          )
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }
}
