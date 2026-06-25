import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AppPromotion {
  static void showRateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('❤️ Love NexusEdu?', style: TextStyle(color: Colors.white)),
        content: const Text('Rate us 5 stars on Play Store!', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.nexus.edu'));
              Navigator.pop(context);
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  static void showShareDialog(BuildContext context) {
    const shareText =
        '📚 Download NexusEdu - AI-powered learning app for Indian students!\nCBSE, JEE, NEET, NCERT solutions & more.\n\nGet it now: https://play.google.com/store/apps/details?id=com.nexus.edu';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Share NexusEdu', style: TextStyle(color: Colors.white)),
        content: const Text('Share with friends & classmates!', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(const ClipboardData(text: shareText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied! Share with friends 🎉')),
              );
            },
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }
}
