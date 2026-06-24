import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Web3CryptoWalletScreen extends StatelessWidget {
  const Web3CryptoWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(title: const Text('Learn-to-Earn Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.currency_bitcoin, color: Colors.amber, size: 80).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.1),
            const SizedBox(height: 16),
            const Text('450 \$NEXUS', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
            const Text('≈ \$14.50 USD', style: TextStyle(color: Colors.greenAccent, fontSize: 18)),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.amber.withAlpha(50))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Smart Contract Earnings', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildTransaction('Solved Calculus Quiz', '+15 \$NEXUS'),
                  _buildTransaction('10 Day Streak Bonus', '+50 \$NEXUS'),
                  _buildTransaction('Helped a Peer in Chat', '+5 \$NEXUS'),
                ],
              ),
            ).animate().slideY(begin: 0.1),
            const Spacer(),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Withdraw to Metamask', style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTransaction(String title, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white)),
          Text(amount, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
