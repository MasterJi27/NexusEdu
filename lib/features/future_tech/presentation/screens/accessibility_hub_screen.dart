import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AccessibilityHubScreen extends StatefulWidget {
  const AccessibilityHubScreen({super.key});

  @override
  State<AccessibilityHubScreen> createState() => _AccessibilityHubScreenState();
}

class _AccessibilityHubScreenState extends State<AccessibilityHubScreen> {
  bool _dyslexiaFont = false;
  bool _adhdFocus = true;
  bool _colorBlind = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Accessibility & Tech For Good', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.accessibility_new, size: 60, color: Colors.blueAccent).animate().slideY(begin: -0.2),
          const SizedBox(height: 24),
          const Text('Inclusive Learning', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SwitchListTile(
            title: const Text('Dyslexia Font Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Converts all app text to OpenDyslexic font for easier reading.'),
            value: _dyslexiaFont,
            onChanged: (val) => setState(() => _dyslexiaFont = val),
            activeThumbColor: Colors.blueAccent,
            secondary: const Icon(Icons.text_format),
          ).animate().slideX(begin: 0.1),
          SwitchListTile(
            title: const Text('ADHD Hyper-Focus Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Aggressively blocks all push notifications and social apps during study time.'),
            value: _adhdFocus,
            onChanged: (val) => setState(() => _adhdFocus = val),
            activeThumbColor: Colors.redAccent,
            secondary: const Icon(Icons.center_focus_strong),
          ).animate().slideX(begin: 0.1, delay: 100.ms),
          SwitchListTile(
            title: const Text('Colorblind Filter', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Adjusts UI contrast and chart colors for Protanopia and Deuteranopia.'),
            value: _colorBlind,
            onChanged: (val) => setState(() => _colorBlind = val),
            activeThumbColor: Colors.green,
            secondary: const Icon(Icons.color_lens),
          ).animate().slideX(begin: 0.1, delay: 200.ms),
        ],
      ),
    );
  }
}
