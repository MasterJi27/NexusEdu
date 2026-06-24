import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class InteractiveModelScreen extends StatelessWidget {
  const InteractiveModelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '3D Interactive Learning',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Stack(
        children: [
          ModelViewer(
            backgroundColor: Color(0xFF0F0F13),
            src: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
            alt: 'A 3D model of an astronaut',
            ar: true,
            autoRotate: true,
            cameraControls: true,
            disableZoom: false,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.white10,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Explore the model in 3D! Use one finger to rotate, and two fingers to zoom or pan. Tap the AR icon in the corner to place it in your real room.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
