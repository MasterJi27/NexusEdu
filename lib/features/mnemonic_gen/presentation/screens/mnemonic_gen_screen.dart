import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MnemonicGenScreen extends StatefulWidget {
  const MnemonicGenScreen({super.key});

  @override
  State<MnemonicGenScreen> createState() => _MnemonicGenScreenState();
}

class _MnemonicGenScreenState extends State<MnemonicGenScreen> {
  final TextEditingController _inputController = TextEditingController();
  String _selectedSubject = 'Physics';
  bool _isLoading = false;
  String _generatedTricks = '';
  double _rating = 0;
  List<Map<String, dynamic>> _savedMnemonics = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('mnemonics') ?? [];
    setState(() {
      _savedMnemonics = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _generateTricks() async {
    if (_inputController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _generatedTricks = '';
      _rating = 0;
    });

    final result = await AiAgentService.callAgent('custom', {
      'prompt':
          'Create memory tricks, mnemonics, stories, and associations for: '
              '"${_inputController.text.trim()}" in $_selectedSubject. '
              'Include: 1) A story-based mnemonic, 2) An acronym trick, '
              '3) A visual association, 4) A rhyming mnemonic. '
              'Make them easy to remember and fun.',
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _generatedTricks = result;
    });

    _savedMnemonics.insert(0, {
      'input': _inputController.text.trim(),
      'subject': _selectedSubject,
      'content': _generatedTricks,
      'rating': 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedMnemonics.length > 50) _savedMnemonics.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'mnemonics',
      _savedMnemonics.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Mnemonic Generator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter formulas, dates, or concepts to memorize',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inputController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Photosynthesis equation, Planck\'s constant...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSelectorRow(
                    'Subject',
                    ['Physics', 'Chemistry', 'Biology', 'Maths', 'History', 'Geography'],
                    _selectedSubject,
                    (val) => setState(() => _selectedSubject = val!),
                  ),
                ],
              ),
            ).animate().fade(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateTricks,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(200),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.psychology),
                label: Text(
                  _isLoading ? 'Generating Tricks...' : 'Generate Tricks',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 30),
              const Center(
                child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
              ),
            ],
            if (_generatedTricks.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildTricksCard(),
              const SizedBox(height: 12),
              _buildRatingWidget(),
            ],
            if (_savedMnemonics.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Mnemonics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedMnemonics.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedMnemonics[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withAlpha(150),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () => onChanged(opt),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurpleAccent.withAlpha(40)
                      : Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.deepPurpleAccent
                        : Colors.white.withAlpha(15),
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.deepPurpleAccent
                        : Colors.white.withAlpha(150),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTricksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Memory Tricks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          SelectableText(
            _generatedTricks,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildRatingWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate this trick',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(180),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final starValue = i + 1.0;
              return GestureDetector(
                onTap: () {
                  setState(() => _rating = starValue);
                  if (_savedMnemonics.isNotEmpty) {
                    _savedMnemonics[0]['rating'] = _rating.toInt();
                    final prefs = SharedPreferences.getInstance();
                    prefs.then((p) => p.setStringList(
                          'mnemonics',
                          _savedMnemonics.map((e) => json.encode(e)).toList(),
                        ));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amberAccent,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    ).animate().fade(delay: 300.ms);
  }

  Widget _buildSavedItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.amberAccent.withAlpha(180), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['subject'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item['input'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if ((item['rating'] ?? 0) > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(item['rating'], (i) => Icon(
                    Icons.star,
                    color: Colors.amberAccent,
                    size: 14,
                  )),
            ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _savedMnemonics.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'mnemonics',
                    _savedMnemonics.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
