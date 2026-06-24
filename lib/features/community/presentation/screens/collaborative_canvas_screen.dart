import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CollaborativeCanvasScreen extends StatelessWidget {
  const CollaborativeCanvasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Whiteboard color
      appBar: AppBar(
        title: const Text('Live Whiteboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.blue, radius: 12, child: Text('A', style: TextStyle(fontSize: 10))),
              const SizedBox(width: 4),
              const CircleAvatar(backgroundColor: Colors.green, radius: 12, child: Text('S', style: TextStyle(fontSize: 10))),
              const SizedBox(width: 16),
            ],
          )
        ],
      ),
      body: Stack(
        children: [
          // Simulated drawing
          Center(
            child: CustomPaint(
              size: const Size(300, 300),
              painter: _MockDrawingPainter(),
            ).animate().fade(duration: 1.seconds),
          ),
          
          // Toolbar
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Icon(Icons.format_color_fill, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Icon(Icons.crop_square, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Icon(Icons.cleaning_services, color: Colors.red),
                ],
              ),
            ).animate().slideX(begin: -1),
          ),
        ],
      ),
    );
  }
}

class _MockDrawingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
      
    // Draw a mock physics diagram
    canvas.drawCircle(const Offset(150, 150), 50, paint);
    canvas.drawLine(const Offset(150, 150), const Offset(200, 200), paint..color = Colors.red);
    
    final textPainter = TextPainter(text: const TextSpan(text: 'F = ma', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(160, 100));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
