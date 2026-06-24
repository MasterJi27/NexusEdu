import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class OfflineVaultScreen extends StatelessWidget {
  const OfflineVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Pitch black/dark grey
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Offline Vault', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.wifi, color: Colors.green),
            label: const Text('Go Online', style: TextStyle(color: Colors.green)),
          )
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are currently offline. Only your pinned notes and flashcards are available.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ).animate().slideY().fade(),
            const SizedBox(height: 32),
            const Text('Pinned Flashcards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFlashcardDeck('Physics Formulas', '32 Cards', Colors.blue),
                  _buildFlashcardDeck('History Dates', '15 Cards', Colors.orange),
                  _buildFlashcardDeck('Spanish Vocab', '50 Cards', Colors.green),
                ],
              ),
            ).animate().slideX(begin: 0.2).fade(),
            const SizedBox(height: 32),
            const Text('Saved Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildNoteTile('Thermodynamics Summary', 'Last edited 2 days ago'),
                  _buildNoteTile('World War II Essay Draft', 'Last edited 5 days ago'),
                  _buildNoteTile('Python Cheatsheet', 'Last edited 1 week ago'),
                ],
              ),
            ).animate().slideY(begin: 0.2).fade(delay: 200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashcardDeck(String title, String subtitle, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100)),
        boxShadow: [BoxShadow(color: color.withAlpha(20), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.style, color: color, size: 32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNoteTile(String title, String subtitle) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.deepPurpleAccent.withAlpha(50), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.description, color: Colors.deepPurpleAccent),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () {},
      ),
    );
  }
}
