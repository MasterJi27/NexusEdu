import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class IsaContractScreen extends StatelessWidget {
  const IsaContractScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Income Share Agreement', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.handshake, size: 60, color: Colors.blueAccent).animate().slideY(begin: -0.2),
            const SizedBox(height: 24),
            const Text('Study Now. Pay Later.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            const Text('Unlock Nexus Pro completely free today. You only pay us back when you succeed.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 32),
            _buildTermRow(Icons.check_circle, '0 Upfront Cost'),
            _buildTermRow(Icons.account_balance_wallet, 'Pay 10% of salary for 1 year'),
            _buildTermRow(Icons.work, 'Triggered ONLY if job > ₹5 LPA'),
            const Spacer(),
            const Text('By clicking agree, you legally bind to the ISA contract terms.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20)),
                child: const Text('Sign Contract & Unlock Pro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTermRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }
}
