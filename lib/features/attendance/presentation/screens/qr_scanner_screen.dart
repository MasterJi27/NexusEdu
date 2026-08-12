import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';

/// Full-screen camera scanner for classroom QR codes. Pops with the scanned
/// raw string on a successful read, or with null if the user backs out.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .where((b) => b.rawValue != null && b.rawValue!.isNotEmpty)
        .map((b) => b.rawValue!)
        .firstOrNull;
    if (raw == null) return;
    _handled = true;
    _controller.stop();
    if (mounted) Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: 'Scan classroom QR',
      transparentAppBar: true,
      applyTabletMaxWidth: false,
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              placeholderBuilder: (context) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Text(
                    'Starting camera…',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
                  ),
                ),
              ),
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Text(
                    'Camera unavailable: ${error.errorCode.name}',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Text(
              'Point the camera at the QR your teacher is showing. It joins you to their classroom.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: t.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
