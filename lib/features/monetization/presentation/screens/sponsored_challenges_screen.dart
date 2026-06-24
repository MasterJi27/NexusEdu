import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SponsoredChallengesScreen extends StatelessWidget {
  const SponsoredChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Corporate Challenges', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSponsorCard('Google Cloud', 'Cloud Architecture Quest', 'Top 10 win guaranteed summer internship interviews at Google.', Colors.blue, 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/1200px-Google_%22G%22_Logo.svg.png'),
          const SizedBox(height: 16),
          _buildSponsorCard('Microsoft', 'AI for Good Hackathon', 'Win Surface laptops and direct mentorship.', Colors.green, 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Microsoft_logo.svg/2048px-Microsoft_logo.svg.png'),
        ],
      ),
    );
  }

  Widget _buildSponsorCard(String company, String title, String prize, Color color, String logoUrl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withAlpha(50))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.network(logoUrl, height: 40),
              const SizedBox(width: 16),
              Text('Sponsored by $company', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Text(title, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(prize, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Join Challenge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    ).animate().scale();
  }
}
