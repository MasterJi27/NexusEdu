import 'package:flutter/material.dart';

class CodeSandboxScreen extends StatefulWidget {
  const CodeSandboxScreen({super.key});

  @override
  State<CodeSandboxScreen> createState() => _CodeSandboxScreenState();
}

class _CodeSandboxScreenState extends State<CodeSandboxScreen> {
  final TextEditingController _controller = TextEditingController(text: "def fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)\n\nprint([fibonacci(i) for i in range(10)])");
  String _output = "";

  void _runCode() {
    setState(() => _output = "Running...");
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _output = "[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]\n\nExecution finished in 0.042s");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // VSCode dark background
      appBar: AppBar(
        title: const Text('Python Sandbox', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace')),
        backgroundColor: const Color(0xFF252526),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.play_arrow, color: Colors.greenAccent), onPressed: _runCode),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 16),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF1E1E1E),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          Container(height: 2, color: Colors.black),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0D0D0D),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TERMINAL', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_output, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
