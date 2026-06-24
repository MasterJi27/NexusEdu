import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VrFieldTripScreen extends StatelessWidget {
  const VrFieldTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('VR Field Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Simulated 360 panorama using an InteractiveViewer over an image
          Positioned.fill(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 1.0,
              maxScale: 3.0,
              child: Image.network(
                'https://images.unsplash.com/photo-1614730321146-b6fa6a46bcb4?q=80&w=2000&auto=format&fit=crop', // Space panorama
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // UI Overlays
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.headset, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('The Surface of Mars', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('AI Guide: Move your phone to explore the Jezero Crater.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1),
          ),
          
          Center(
            child: const Icon(Icons.control_camera, color: Colors.white54, size: 64).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.2),
          )
        ],
      ),
    );
  }
}
