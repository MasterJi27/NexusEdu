import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabManualGenScreen extends StatefulWidget {
  const LabManualGenScreen({super.key});

  @override
  State<LabManualGenScreen> createState() => _LabManualGenScreenState();
}

class _LabManualGenScreenState extends State<LabManualGenScreen> {
  String _selectedSubject = 'Physics';
  String _selectedExperiment = '';
  bool _isLoading = false;
  String _generatedManual = '';
  List<Map<String, dynamic>> _savedManuals = [];

  final Map<String, List<String>> _experimentsBySubject = {
    'Physics': [
      'Ohm\'s Law Verification',
      'Meter Bridge Experiment',
      'Potentiometer Calibration',
      'Diode Characteristics',
      'Transistor CE Characteristics',
      'Lens Focal Length',
      'Diffraction Grating',
      'Young\'s Double Slit',
    ],
    'Chemistry': [
      'Titration - Acid Base',
      'Salt Analysis',
      'Electrochemistry Cell',
      'Reaction Kinetics',
      'pH Measurement',
      'Conductometric Titration',
      'Flame Test',
      'Preparation of Soap',
    ],
    'Biology': [
      'Microscope Observation',
      'DNA Extraction',
      'Enzyme Activity',
      'Plant Tissue Culture',
      'Osmosis Experiment',
      'Photosynthesis Rate',
      'Bacterial Staining',
      'Heart Rate Response',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedExperiment = _experimentsBySubject[_selectedSubject]!.first;
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('lab_manuals') ?? [];
    setState(() {
      _savedManuals = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _generateManual() async {
    setState(() {
      _isLoading = true;
      _generatedManual = '';
    });

    final result = await AiAgentService.callAgent('lab_experiment', {
      'experiment': _selectedExperiment,
      'subject': _selectedSubject,
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _generatedManual = result;
    });

    _savedManuals.insert(0, {
      'subject': _selectedSubject,
      'experiment': _selectedExperiment,
      'content': _generatedManual,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedManuals.length > 50) _savedManuals.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'lab_manuals',
      _savedManuals.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Lab Manual Creator',
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
              ['Physics', 'Chemistry', 'Biology'],
              _selectedSubject,
              (val) => setState(() {
                _selectedSubject = val!;
                _selectedExperiment =
                    _experimentsBySubject[_selectedSubject]!.first;
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Experiment',
              _experimentsBySubject[_selectedSubject]!,
              _selectedExperiment,
              (val) => setState(() => _selectedExperiment = val!),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateManual,
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
                    : const Icon(Icons.science),
                label: Text(
                  _isLoading ? 'Generating Manual...' : 'Generate Manual',
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
            if (_generatedManual.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildManualCard(),
            ],
            if (_savedManuals.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Lab Manuals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedManuals.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedManuals[i], i);
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

  Widget _buildManualCard() {
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
              const Icon(Icons.science, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_selectedSubject - $_selectedExperiment',
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
            _generatedManual,
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
          Icon(Icons.science, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
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
                  item['experiment'] ?? '',
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
              setState(() => _savedManuals.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'lab_manuals',
                    _savedManuals.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
