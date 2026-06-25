import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HandwritingRecognitionScreen extends StatefulWidget {
  const HandwritingRecognitionScreen({super.key});

  @override
  State<HandwritingRecognitionScreen> createState() =>
      _HandwritingRecognitionScreenState();
}

class _HandwritingRecognitionScreenState
    extends State<HandwritingRecognitionScreen> {
  File? _selectedImage;
  bool _isProcessing = false;
  String _extractedText = '';
  final TextEditingController _textEditingController = TextEditingController();
  List<Map<String, dynamic>> _recentScans = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
  }

  Future<void> _loadRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('handwriting_scans') ?? [];
    setState(() {
      _recentScans = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'handwriting_scans',
      _recentScans.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedText = '';
      });
    }
  }

  Future<void> _scanImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _isProcessing = true;
      _extractedText = '';
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final result = await AiService.analyzeImage(
        bytes,
        "Extract all handwritten text from this image. "
            "Preserve the original formatting, line breaks, and structure. "
            "Return the extracted text clearly and accurately.",
      );

      if (!mounted) return;

      setState(() {
        _extractedText = result;
        _textEditingController.text = result;
        _isProcessing = false;
      });

      _recentScans.insert(0, {
        'text': result.substring(0, result.length.clamp(0, 200)),
        'timestamp': DateTime.now().toIso8601String(),
        'hasText': result.isNotEmpty && !result.startsWith('API Error'),
      });
      if (_recentScans.length > 20) _recentScans.removeLast();
      _saveRecentScans();
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _createFlashcards() async {
    final text = _textEditingController.text.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating flashcards from extracted text...'),
        backgroundColor: Colors.deepPurpleAccent.withAlpha(200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final result = await AiService.generateFlashcards(text);
    if (!mounted) return;

    try {
      String jsonStr = result.trim();
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
        jsonStr = lines.join('\n').trim();
      }
      final List<dynamic> parsed = json.decode(jsonStr);
      if (parsed.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${parsed.length} flashcards generated!'),
            backgroundColor: Colors.tealAccent.withAlpha(200),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to generate flashcards. Try again.'),
          backgroundColor: Colors.redAccent.withAlpha(200),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Handwriting Scanner',
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
            _buildImagePicker(),
            const SizedBox(height: 16),
            _buildImagePreview(),
            if (_selectedImage != null && _extractedText.isEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _scanImage,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.document_scanner),
                  label: Text(
                    _isProcessing ? 'Scanning...' : 'Scan & Extract Text',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (_isProcessing) ...[
              const SizedBox(height: 20),
              _buildProcessingIndicator(),
            ],
            if (_extractedText.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildExtractedTextCard(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _createFlashcards,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.tealAccent.withAlpha(200),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.style),
                  label: const Text(
                    'Create Flashcards',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (_recentScans.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Recent Scans',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_recentScans.length.clamp(0, 10), (i) {
                return _buildRecentScanItem(_recentScans[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPickButton(
              'Camera',
              Icons.camera_alt,
              () => _pickImage(ImageSource.camera),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPickButton(
              'Gallery',
              Icons.photo_library,
              () => _pickImage(ImageSource.gallery),
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.06);
  }

  Widget _buildPickButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.deepPurpleAccent, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedImage = null;
                _extractedText = '';
              }),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildProcessingIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withAlpha(30),
            Colors.teal.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(50)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.deepPurpleAccent),
          const SizedBox(height: 16),
          Text(
            'Extracting text from image...',
            style: TextStyle(
              color: Colors.deepPurpleAccent.withAlpha(200),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'AI is analyzing your handwriting',
            style: TextStyle(
              color: Colors.white.withAlpha(100),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildExtractedTextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_snippet, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Extracted Text',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.tealAccent, size: 18),
                onPressed: () {
                  // Copy to clipboard
                },
                tooltip: 'Copy Text',
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          TextField(
            controller: _textEditingController,
            maxLines: null,
            minLines: 4,
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Extracted text will appear here...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFF0F0F13),
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms);
  }

  Widget _buildRecentScanItem(Map<String, dynamic> scan, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: Colors.white.withAlpha(80), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan['text'] ?? 'Scanned text',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  scan['timestamp'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(100),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _recentScans.removeAt(index));
              _saveRecentScans();
            },
          ),
        ],
      ),
    );
  }
}
