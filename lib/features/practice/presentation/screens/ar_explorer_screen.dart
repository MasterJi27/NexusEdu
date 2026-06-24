import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ArExplorerScreen extends StatefulWidget {
  const ArExplorerScreen({super.key});

  @override
  State<ArExplorerScreen> createState() => _ArExplorerScreenState();
}

class _ArExplorerScreenState extends State<ArExplorerScreen> {
  final List<Map<String, String>> _models = [
    {
      "subject": "Astronomy",
      "name": "Astronaut Suit",
      "src": "https://modelviewer.dev/shared-assets/models/Astronaut.glb",
      "alt": "A 3D model of an astronaut",
      "icon": "Icons.rocket_launch"
    },
    {
      "subject": "Biology",
      "name": "Nervous System",
      "src": "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/BrainStem/glTF-Binary/BrainStem.glb",
      "alt": "A 3D model of a brain stem and nervous system",
      "icon": "Icons.biotech"
    },
    {
      "subject": "Engineering",
      "name": "Vintage Buggy",
      "src": "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Buggy/glTF-Binary/Buggy.glb",
      "alt": "A 3D model of a buggy",
      "icon": "Icons.engineering"
    },
    {
      "subject": "History",
      "name": "Damaged Helmet",
      "src": "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/DamagedHelmet/glTF-Binary/DamagedHelmet.glb",
      "alt": "A 3D model of a historical damaged helmet",
      "icon": "Icons.history"
    }
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentModel = _models[_selectedIndex];

    return Scaffold(
      backgroundColor: Colors.black, // Dark aesthetic for "AR" immersion
      appBar: AppBar(
        title: const Text('AR 3D Explorer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Simulated AR Camera Background (Static blurry image or gradient for mock)
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.network(
                'https://images.unsplash.com/photo-1518173946687-a4c8892bbd9f?q=80&w=1000&auto=format&fit=crop',
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Interactive 3D Model
          Positioned.fill(
            child: ModelViewer(
              key: ValueKey(currentModel['src']), // Force rebuild when src changes
              backgroundColor: Colors.transparent,
              src: currentModel['src']!,
              alt: currentModel['alt']!,
              ar: false, // Disables the native barcode AR button
              autoRotate: true,
              cameraControls: true,
              disableZoom: false,
            ),
          ),

          // Subject Model Selector
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book, color: Colors.cyanAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Subject: ${currentModel['subject']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ).animate().slideX(begin: -0.2),
                
                const SizedBox(height: 16),
                
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _models.length,
                    itemBuilder: (context, index) {
                      final model = _models[index];
                      final isSelected = index == _selectedIndex;
                      
                      IconData getIcon(String iconStr) {
                        switch(iconStr) {
                          case 'Icons.rocket_launch': return Icons.rocket_launch;
                          case 'Icons.biotech': return Icons.biotech;
                          case 'Icons.engineering': return Icons.engineering;
                          case 'Icons.history': return Icons.history_edu;
                          default: return Icons.view_in_ar;
                        }
                      }
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 140,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.cyanAccent.withAlpha(30) : Colors.black.withAlpha(150),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.cyanAccent : Colors.white.withAlpha(30),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected 
                                ? [BoxShadow(color: Colors.cyanAccent.withAlpha(40), blurRadius: 15)] 
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(getIcon(model['icon']!), color: isSelected ? Colors.cyanAccent : Colors.white70),
                              const SizedBox(height: 8),
                              Text(
                                model['name']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ).animate().slideY(begin: 0.5),
              ],
            ),
          ),
          
        ],
      ),
    );
  }
}
