import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class QuantumCircuitScreen extends StatefulWidget {
  const QuantumCircuitScreen({super.key});

  @override
  State<QuantumCircuitScreen> createState() => _QuantumCircuitScreenState();
}

class _QuantumCircuitScreenState extends State<QuantumCircuitScreen>
    with TickerProviderStateMixin {
  static const int _numWires = 4;
  static const int _numSlots = 6;

  late AnimationController _placeGateController;

  String? _selectedGate;
  String _metaphorInterest = '';
  String _circuitExplanation = '';
  String _metaphorExplanation = '';
  bool _isExplaining = false;
  bool _isMetaphoring = false;

  final List<List<String?>> _gates = List.generate(
    _numWires,
    (_) => List.filled(_numSlots, null),
  );

  final List<String> _qubitStates = List.filled(_numWires, '|0\u27E9');

  final List<Map<String, dynamic>> _recentCircuits = [];

  final List<Map<String, String>> _gatePalette = [
    {'symbol': 'H', 'name': 'Hadamard', 'desc': 'Creates superposition'},
    {'symbol': 'X', 'name': 'Pauli-X', 'desc': 'Quantum NOT gate'},
    {'symbol': 'CNOT', 'name': 'CNOT', 'desc': 'Controlled NOT'},
    {'symbol': 'M', 'name': 'Measure', 'desc': 'Collapse state'},
    {'symbol': 'T', 'name': 'T Gate', 'desc': 'Phase shift'},
    {'symbol': 'S', 'name': 'S Gate', 'desc': 'Phase gate'},
  ];

  @override
  void initState() {
    super.initState();
    _placeGateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadCircuits();
  }

  Future<void> _loadCircuits() async {
    final settings = AppSettings.instance;
    final existing = settings.cachedNotes
        .where((n) => n['type'] == 'quantum_circuits')
        .toList();
    if (existing.isNotEmpty) {
      final data = json.decode(existing.first['data'] ?? '[]');
      if (data is List) {
        setState(() {
          _recentCircuits.addAll(data.cast<Map<String, dynamic>>());
        });
      }
    }
  }

  Future<void> _saveCircuits() async {
    final settings = AppSettings.instance;
    final updated = [
      {'type': 'quantum_circuits', 'data': json.encode(_recentCircuits)}
    ];
    await settings.saveCachedNotes(updated);
  }

  void _placeGate(int wire, int slot) {
    if (_selectedGate == null || _gates[wire][slot] != null) return;
    setState(() {
      _gates[wire][slot] = _selectedGate;
      _simulateQubitState(wire);
    });
    _placeGateController.forward(from: 0);
  }

  void _simulateQubitState(int wire) {
    final hasH = _gates[wire].contains('H');
    final hasX = _gates[wire].contains('X');
    final hasM = _gates[wire].contains('M');

    if (hasM) {
      _qubitStates[wire] = hasX ? '|1\u27E9' : '|0\u27E9';
    } else if (hasH) {
      _qubitStates[wire] = hasX ? '|-\u27E9' : '|+\u27E9';
    } else if (hasX) {
      _qubitStates[wire] = '|1\u27E9';
    } else {
      _qubitStates[wire] = '|0\u27E9';
    }
    _qubitStates[wire] = _qubitStates[wire].replaceAll('\u27E9', '\u27E9');
  }

  Future<void> _runCircuit() async {
    setState(() => _isExplaining = true);
    final circuitDesc = _describeCircuit();
    final result = await AiService.sendMessageToTutor(
      "Explain this quantum circuit in simple terms: $circuitDesc. "
      "Describe what the sequence of gates does to the qubits.",
    );
    setState(() {
      _circuitExplanation = result;
      _isExplaining = false;
    });

    _recentCircuits.insert(0, {
      'gates': _gates.map((w) => w.join(',')).toList(),
      'date': DateTime.now().toIso8601String(),
      'explanation': result,
    });
    if (_recentCircuits.length > 10) _recentCircuits.removeLast();
    _saveCircuits();
  }

  Future<void> _generateMetaphor() async {
    if (_metaphorInterest.isEmpty) return;
    setState(() => _isMetaphoring = true);
    final result = await AiService.sendMessageToTutor(
      "Explain this quantum circuit: ${_describeCircuit()} "
      "using a metaphor based on '$_metaphorInterest'. "
      "Make it intuitive, creative, and educational.",
    );
    setState(() {
      _metaphorExplanation = result;
      _isMetaphoring = false;
    });
  }

  String _describeCircuit() {
    final parts = <String>[];
    for (int w = 0; w < _numWires; w++) {
      final gates = _gates[w].where((g) => g != null).join(' -> ');
      if (gates.isNotEmpty) {
        parts.add('Wire $w: $gates');
      }
    }
    return parts.join('; ') + ' (${_qubitStates.join(', ')})';
  }

  void _clearCircuit() {
    setState(() {
      for (int w = 0; w < _numWires; w++) {
        for (int s = 0; s < _numSlots; s++) {
          _gates[w][s] = null;
        }
        _qubitStates[w] = '|0\u27E9';
      }
      _circuitExplanation = '';
      _metaphorExplanation = '';
    });
  }

  @override
  void dispose() {
    _placeGateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Quantum Circuit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _clearCircuit,
            tooltip: 'Clear circuit',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildGatePalette(),
            const SizedBox(height: 16),
            _buildCircuitCanvas(),
            const SizedBox(height: 16),
            _buildQubitStates(),
            const SizedBox(height: 16),
            _buildControls(),
            if (_circuitExplanation.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildExplanation(),
            ],
            _buildMetaphorEngine(),
          ],
        ),
      ),
    );
  }

  Widget _buildGatePalette() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GATE PALETTE', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _gatePalette.map((gate) {
              final isSelected = _selectedGate == gate['symbol'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGate = isSelected ? null : gate['symbol'];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurpleAccent.withAlpha(40)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(20),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(gate['symbol'] ?? '',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.deepPurpleAccent : Colors.white,
                        ),
                      ),
                      Text(gate['name'] ?? '',
                        style: TextStyle(fontSize: 9, color: Colors.white.withAlpha(150)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedGate != null) ...[
            const SizedBox(height: 8),
            Text('Selected: $_selectedGate — tap a wire slot to place',
              style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildCircuitCanvas() {
    final double canvasHeight = _numWires * 60.0 + 40;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasWidth = constraints.maxWidth;
            final slotSpacing = canvasWidth / _numSlots;
            return GestureDetector(
              onTapDown: (details) {
                if (_selectedGate == null) return;
                final slot = (details.localPosition.dx / slotSpacing).floor().clamp(0, _numSlots - 1);
                final wire = (details.localPosition.dy / 60).floor().clamp(0, _numWires - 1);
                _placeGate(wire, slot);
              },
              child: CustomPaint(
                painter: _CircuitCanvasPainter(
                  gates: _gates,
                  qubitStates: _qubitStates,
                  wireSpacing: 60,
                  slotCount: _numSlots,
                ),
                size: Size(canvasWidth, canvasHeight.toDouble()),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQubitStates() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUBIT STATES', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: List.generate(_numWires, (w) {
              final state = _qubitStates[w];
              final isOne = state.contains('1') || state.contains('-');
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOne ? Colors.deepPurpleAccent : Colors.cyanAccent,
                      boxShadow: [
                        BoxShadow(
                          color: (isOne ? Colors.deepPurpleAccent : Colors.cyanAccent).withAlpha(60),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Wire $w: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  Text(state, style: TextStyle(
                    color: isOne ? Colors.deepPurpleAccent : Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (_isExplaining || _isMetaphoring) ? null : _runCircuit,
            icon: _isExplaining
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow),
            label: const Text('Run Circuit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExplanation() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science, size: 18, color: Colors.deepPurpleAccent),
              SizedBox(width: 8),
              Text('AI Analysis', style: TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_circuitExplanation, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildMetaphorEngine() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('METAPHOR ENGINE', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 4),
          const Text('Explain this circuit using your interest',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => _metaphorInterest = v,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. cricket, cooking, gaming',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withAlpha(8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: (_isMetaphoring || _metaphorInterest.isEmpty) ? null : _generateMetaphor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isMetaphoring
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
              ),
            ],
          ),
          if (_metaphorExplanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withAlpha(30)),
              ),
              child: Text(
                _metaphorExplanation,
                style: TextStyle(color: Colors.amber.withAlpha(230), fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircuitCanvasPainter extends CustomPainter {
  final List<List<String?>> gates;
  final List<String> qubitStates;
  final double wireSpacing;
  final int slotCount;

  _CircuitCanvasPainter({
    required this.gates,
    required this.qubitStates,
    required this.wireSpacing,
    required this.slotCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wireCount = gates.length;
    final slotSpacing = size.width / slotCount;
    final effectiveWireSpacing = size.height / wireCount;

    final wirePaint = Paint()
      ..color = Colors.white.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int w = 0; w < wireCount; w++) {
      final y = effectiveWireSpacing * w + effectiveWireSpacing / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), wirePaint);

      final isOne = qubitStates[w].contains('1') || qubitStates[w].contains('-');
      final dotPaint = Paint()
        ..color = isOne ? Colors.deepPurpleAccent : Colors.cyanAccent;
      canvas.drawCircle(Offset(12, y), 5, dotPaint);
    }

    for (int s = 0; s < slotCount; s++) {
      final x = slotSpacing * s + slotSpacing / 2;
      final slotPaint = Paint()
        ..color = Colors.white.withAlpha(8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), slotPaint);
    }

    for (int w = 0; w < wireCount; w++) {
      for (int s = 0; s < slotCount; s++) {
        final gate = gates[w][s];
        if (gate != null) {
          final x = slotSpacing * s + 4;
          final y = effectiveWireSpacing * w + 6;
          final gw = slotSpacing - 8;
          final gh = effectiveWireSpacing - 12;

          final borderPaint = Paint()
            ..color = Colors.deepPurpleAccent.withAlpha(120)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          final fillPaint = Paint()
            ..color = Colors.deepPurpleAccent.withAlpha(40);

          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, gw, gh),
            const Radius.circular(6),
          );
          canvas.drawRRect(rect, fillPaint);
          canvas.drawRRect(rect, borderPaint);

          final tp = TextPainter(
            text: TextSpan(
              text: gate,
              style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(x + gw / 2 - tp.width / 2, y + gh / 2 - tp.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitCanvasPainter old) => true;
}
