import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RoadmapGeneratorScreen extends StatefulWidget {
  const RoadmapGeneratorScreen({super.key});

  @override
  State<RoadmapGeneratorScreen> createState() => _RoadmapGeneratorScreenState();
}

class _RoadmapGeneratorScreenState extends State<RoadmapGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  bool _showRoadmap = false;

  void _generateRoadmap() {
    if (_promptController.text.isEmpty) return;
    setState(() => _isGenerating = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _showRoadmap = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Roadmap Generator')),
      body: _showRoadmap ? _buildRoadmap() : _buildPromptView(),
    );
  }

  Widget _buildPromptView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree, size: 80, color: Colors.blueAccent.withAlpha(200)).animate().scale().fade(),
          const SizedBox(height: 24),
          const Text(
            'What do you want to learn?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            decoration: InputDecoration(
              hintText: 'e.g. Python for Data Science in 15 days',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          _isGenerating
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  onPressed: _generateRoadmap,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Skill Tree'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRoadmap() {
    final nodes = [
      {'day': 'Day 1-3', 'title': 'Python Basics (Variables, Loops)', 'icon': Icons.code},
      {'day': 'Day 4-6', 'title': 'Data Structures (Lists, Dicts)', 'icon': Icons.account_tree},
      {'day': 'Day 7-10', 'title': 'Numpy & Pandas Foundation', 'icon': Icons.table_chart},
      {'day': 'Day 11-13', 'title': 'Data Visualization', 'icon': Icons.show_chart},
      {'day': 'Day 14-15', 'title': 'Final Project', 'icon': Icons.star},
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final node = nodes[index];
                final isLeft = index % 2 == 0;
                return SizedBox(
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Connecting Line
                      if (index != nodes.length - 1)
                        Positioned(
                          top: 60,
                          bottom: -60,
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent,
                                  Colors.blueAccent.withAlpha(50),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 2000.ms, color: Colors.white),
                      
                      // Node Content
                      Row(
                        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
                        children: [
                          if (!isLeft) const Spacer(),
                          if (!isLeft) _buildNodeIcon(node['icon'] as IconData, index),
                          if (!isLeft) const SizedBox(width: 16),
                          
                          Expanded(
                            flex: 3,
                            child: Card(
                              elevation: 8,
                              shadowColor: Colors.blueAccent.withAlpha(100),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.blueAccent.withAlpha(50), width: 1),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).cardColor,
                                      Theme.of(context).cardColor.withAlpha(200),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        node['day'] as String,
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      node['title'] as String,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fade(delay: (200 * index).ms).scale(curve: Curves.easeOutBack),
                          ),
                          
                          if (isLeft) const SizedBox(width: 16),
                          if (isLeft) _buildNodeIcon(node['icon'] as IconData, index),
                          if (isLeft) const Spacer(),
                        ],
                      ),
                    ],
                  ),
                );
              },
              childCount: nodes.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeIcon(IconData icon, int index) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border.all(color: Colors.blueAccent, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withAlpha(150),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.blueAccent),
    ).animate().scale(delay: (200 * index).ms).then().shimmer(duration: 1500.ms, delay: 500.ms);
  }
}
