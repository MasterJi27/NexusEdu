import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CheatSheetGenScreen extends StatefulWidget {
  const CheatSheetGenScreen({super.key});

  @override
  State<CheatSheetGenScreen> createState() => _CheatSheetGenScreenState();
}

class _CheatSheetGenScreenState extends State<CheatSheetGenScreen> {
  String _selectedSubject = 'Physics';
  String _selectedChapter = '';
  bool _isLoading = false;
  String _generatedSheet = '';
  List<Map<String, dynamic>> _savedSheets = [];

  final Map<String, List<String>> _chaptersBySubject = {
    'Physics': [
      'Electrostatics',
      'Current Electricity',
      'Magnetic Effects',
      'Optics',
      'Dual Nature of Matter',
      'Atoms & Nuclei',
      'Semiconductors',
      'Thermodynamics',
    ],
    'Chemistry': [
      'Solid State',
      'Solutions',
      'Electrochemistry',
      'Chemical Kinetics',
      'p-Block Elements',
      'Organic Chemistry',
      'Biomolecules',
      'Coordination Chemistry',
    ],
    'Biology': [
      'Genetics & Evolution',
      'Human Physiology',
      'Plant Physiology',
      'Cell Biology',
      'Ecology',
      'Biotechnology',
      'Reproduction',
      'Molecular Biology',
    ],
    'Maths': [
      'Calculus',
      'Algebra',
      'Trigonometry',
      'Coordinate Geometry',
      'Vectors',
      'Probability',
      'Matrices',
      'Differential Equations',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedChapter = _chaptersBySubject[_selectedSubject]!.first;
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('cheat_sheets') ?? [];
    setState(() {
      _savedSheets = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _generateCheatSheet() async {
    setState(() {
      _isLoading = true;
      _generatedSheet = '';
    });

    final result = await AiAgentService.callAgent('custom', {
      'prompt':
          'Create a compact 1-page revision cheat sheet for "$_selectedChapter" '
              'in $_selectedSubject. Include: key formulas, definitions, '
              'important points, quick diagrams (text-based), and memory aids. '
              'Use compact formatting with symbols, arrows, and shorthand. '
              'Maximize information density.',
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _generatedSheet = result;
    });

    _savedSheets.insert(0, {
      'subject': _selectedSubject,
      'chapter': _selectedChapter,
      'content': _generatedSheet,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedSheets.length > 50) _savedSheets.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'cheat_sheets',
      _savedSheets.map((e) => json.encode(e)).toList(),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedSheet));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cheat sheet copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Revision Cheat Sheet',
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
            _buildSelectorRow(
              'Subject',
              ['Physics', 'Chemistry', 'Biology', 'Maths'],
              _selectedSubject,
              (val) => setState(() {
                _selectedSubject = val!;
                _selectedChapter =
                    _chaptersBySubject[_selectedSubject]!.first;
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Chapter',
              _chaptersBySubject[_selectedSubject]!,
              _selectedChapter,
              (val) => setState(() => _selectedChapter = val!),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateCheatSheet,
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
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoading ? 'Generating Cheat Sheet...' : 'Generate Cheat Sheet',
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
            if (_generatedSheet.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildActionButtons(),
              const SizedBox(height: 12),
              _buildCheatSheetCard(),
            ],
            if (_savedSheets.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Cheat Sheets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedSheets.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedSheets[i], i);
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
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
      ),
    ).animate().fade();
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _copyToClipboard,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.deepPurpleAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.copy, color: Colors.deepPurpleAccent, size: 18),
            label: const Text(
              'Copy',
              style: TextStyle(
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved')),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.deepPurpleAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.save, color: Colors.deepPurpleAccent, size: 18),
            label: const Text(
              'Save',
              style: TextStyle(
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ).animate().fade(delay: 100.ms);
  }

  Widget _buildCheatSheetCard() {
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
              const Icon(Icons.description, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_selectedSubject - $_selectedChapter',
                  style: const TextStyle(
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
            _generatedSheet,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              height: 1.6,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms).slideY(begin: 0.05);
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
          Icon(Icons.description, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
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
                  item['chapter'] ?? '',
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
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _savedSheets.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'cheat_sheets',
                    _savedSheets.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
