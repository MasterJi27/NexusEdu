import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EssayRoasterScreen extends StatefulWidget {
  const EssayRoasterScreen({super.key});

  @override
  State<EssayRoasterScreen> createState() => _EssayRoasterScreenState();
}

class _EssayRoasterScreenState extends State<EssayRoasterScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isGrading = false;
  bool _hasResult = false;
  String _roastResult = '';

  void _gradeEssay() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    setState(() => _isGrading = true);
    final result = await AiService.roastEssay(text);
    
    if (!mounted) return;
    setState(() {
      _isGrading = false;
      _hasResult = true;
      _roastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Essay Roaster 🔥', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_hasResult) ...[
              const Text('Paste your essay draft below. Be warned, the AI pulls no punches.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'In conclusion, the Great Gatsby is about boats...',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              _isGrading 
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : ElevatedButton.icon(
                    onPressed: _gradeEssay,
                    icon: const Icon(Icons.local_fire_department),
                    label: const Text('Roast My Essay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
            ] else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withAlpha(20),
                    border: Border.all(color: Colors.redAccent, width: 4),
                  ),
                  child: const Text('F', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                ).animate().scale(curve: Curves.elasticOut, duration: 1.seconds),
              ),
              const SizedBox(height: 32),
              const Text('The Roast:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  _roastResult,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => setState(() => _hasResult = false),
                child: const Text('Rewrite and Try Again', style: TextStyle(fontSize: 16)),
              )
            ]
          ],
        ),
      ),
    );
  }
}
