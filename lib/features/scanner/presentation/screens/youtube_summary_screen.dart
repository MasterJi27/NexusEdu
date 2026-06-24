import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class YoutubeSummaryScreen extends StatefulWidget {
  const YoutubeSummaryScreen({super.key});

  @override
  State<YoutubeSummaryScreen> createState() => _YoutubeSummaryScreenState();
}

class _YoutubeSummaryScreenState extends State<YoutubeSummaryScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String _summary = '';

  void _generate() async {
    if (_urlController.text.isEmpty) return;
    setState(() { _isLoading = true; _summary = ''; });
    final result = await AiService.generateYoutubeSummary(_urlController.text);
    if (!mounted) return;
    setState(() { _isLoading = false; _summary = result; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('YouTube Learning Mode', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Simulated Video Player
          Container(
            width: double.infinity,
            height: 250,
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    'https://images.unsplash.com/photo-1498050108023-c5249f4df085?q=80&w=1000&auto=format&fit=crop',
                    fit: BoxFit.cover,
                    color: Colors.black45,
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
                    onPressed: () {},
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.1),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.black87,
                    child: const Text('14:23', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(value: 0.3, color: Colors.red, backgroundColor: Colors.white24),
                )
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'Paste YouTube URL here...',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent),
                      onPressed: _generate,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_summary.isNotEmpty) ...[
                  const Text('AI Summary & Quiz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.deepPurpleAccent.withAlpha(50)),
                    ),
                    child: Text(_summary, style: const TextStyle(fontSize: 16, height: 1.5)),
                  ).animate().fade().slideY(),
                ] else ...[
                  const Center(child: Text('Paste a link and tap the sparkle icon to analyze!', style: TextStyle(color: Colors.grey))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
