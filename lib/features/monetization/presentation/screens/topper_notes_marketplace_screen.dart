import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TopperNotesMarketplaceScreen extends StatelessWidget {
  const TopperNotesMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(title: const Text('Topper Notes Store', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Top Selling Handwritten Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildNoteCard('Physics Class 12 - Complete Mechanics', 'By AIR 45 - Rahul K.', '₹50', 4.9, 1200),
          _buildNoteCard('Organic Chemistry Reactants Cheat Sheet', 'By Neha S.', '₹30', 4.8, 850),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Become a Creator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Upload your notes and earn ₹30 per sale.', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple), child: const Text('Upload'))
              ],
            ),
          ).animate().fade()
        ],
      ),
    );
  }

  Widget _buildNoteCard(String title, String author, String price, double rating, int sales) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 80, height: 100, decoration: BoxDecoration(color: Colors.amber.withAlpha(50), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.menu_book, color: Colors.amber)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(author, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(' $rating ($sales sales)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
              ],
            ),
          )
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }
}
