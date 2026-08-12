import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ble_peripheral/ble_peripheral.dart' as peripheral;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue;

import 'package:nexus_edu/features/offline_exam/domain/offline_exam_models.dart';

/// Chunked BLE protocol for the offline exam.
///
/// The teacher's phone advertises a GATT service with 8 characteristics:
///  - paper chunks 0..3  (read-only, hold the base64 paper)
///  - answer chunks 0..3 (writable; 0 also readable and holds the score ack)
///
/// Chunk size is 120 bytes so writes succeed even on modest MTUs; papers are
/// capped at 4 chunks so a paper must stay under ~480 base64 bytes
/// (about 30 short MCQs). Bigger papers should use the hotspot transport.
abstract final class ExamBleConstants {
  static const String serviceUuid =
      'a1e5b0ff-0ff1-4e1d-8f0f-0ff1c311e45d';
  static const String advertisementName = 'NexusExam';
  static const int chunkCount = 4;
  static const int chunkSize = 120;
  static const String _pad = '~';

  static String paperChunk(int i) =>
      'a1e5b0ff-0ff1-4e1d-8f0f-0ff1c311e450${i.toRadixString(16)}';
  static String answerChunk(int i) =>
      'a1e5b0ff-0ff1-4e1d-8f0f-0ff1c311e451${i.toRadixString(16)}';

  static String encode(String raw) => base64Url.encode(utf8.encode(raw));

  /// Rebuilds a payload from joined chunks (padding `~` stripped).
  static String decode(String chunked) =>
      chunked.replaceAll(_pad, '');

  /// Splits [payload] into fixed-size chunks padded with `~` so the reader
  /// can rebuild it without needing a length prefix.
  static List<String> chunk(String payload) {
    final chunks = <String>[];
    for (var i = 0; i < chunkCount; i++) {
      final start = i * chunkSize;
      if (start >= payload.length) break;
      final end = (start + chunkSize).clamp(0, payload.length);
      var part = payload.substring(start, end);
      if (part.length < chunkSize) {
        part = part.padRight(chunkSize, _pad);
      }
      chunks.add(part);
    }
    return chunks;
  }
}

/// Teacher side: hosts the paper as a BLE peripheral.
class OfflineExamBleHost {
  final List<OfflineExamResult> results = [];
  final _onSubmit = StreamController<OfflineExamResult>.broadcast();

  bool _advertising = false;
  OfflineExamPaper? _paper;
  final Map<String, String> _answerChunks = {};
  bool _initialized = false;

  Stream<OfflineExamResult> get onSubmit => _onSubmit.stream;
  bool get isAdvertising => _advertising;

  Future<void> start(OfflineExamPaper paper) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('BLE hosting is not supported on this platform.');
    }
    _paper = paper;
    try {
      await peripheral.BlePeripheral.initialize();
      _initialized = true;
    } catch (_) {
      throw StateError('Bluetooth not available. Turn it on and try again.');
    }

    await peripheral.BlePeripheral.clearServices();

    final chars = <peripheral.BleCharacteristic>[];
    final paperChunks = ExamBleConstants.chunk(
        ExamBleConstants.encode(paper.encode()));
    for (var i = 0; i < ExamBleConstants.chunkCount; i++) {
      chars.add(peripheral.BleCharacteristic(
        uuid: ExamBleConstants.paperChunk(i),
        properties: [
          peripheral.CharacteristicProperties.read.index,
          peripheral.CharacteristicProperties.notify.index,
        ],
        value: i < paperChunks.length ? utf8.encode(paperChunks[i]) : null,
        permissions: [peripheral.AttributePermissions.readable.index],
      ));
    }
    for (var i = 0; i < ExamBleConstants.chunkCount; i++) {
      chars.add(peripheral.BleCharacteristic(
        uuid: ExamBleConstants.answerChunk(i),
        properties: [
          peripheral.CharacteristicProperties.read.index,
          peripheral.CharacteristicProperties.write.index,
          peripheral.CharacteristicProperties.notify.index,
        ],
        value: null,
        permissions: [
          peripheral.AttributePermissions.readable.index,
          peripheral.AttributePermissions.writeable.index,
        ],
      ));
    }

    _answerChunks.clear();
    results.clear();
    peripheral.BlePeripheral.setWriteRequestCallback(
        (deviceId, characteristicId, offset, value) {
      if (value == null) return null;
      final chunkIndex = _chunkIndexOf(characteristicId);
      if (chunkIndex == null) return null;
      _answerChunks[chunkIndex] = utf8.decode(value);
      if (_answerChunks.length == ExamBleConstants.chunkCount) {
        _gradeAndAck();
      }
      return peripheral.WriteRequestResult();
    });

    await peripheral.BlePeripheral.addService(peripheral.BleService(
      uuid: ExamBleConstants.serviceUuid,
      primary: true,
      characteristics: chars,
    ));
    await peripheral.BlePeripheral.startAdvertising(
      services: [ExamBleConstants.serviceUuid],
      localName: ExamBleConstants.advertisementName,
    );
    _advertising = true;
  }

  Future<void> stop() async {
    if (_initialized) {
      try {
        await peripheral.BlePeripheral.stopAdvertising();
      } catch (_) {}
    }
    _advertising = false;
  }

  String? _chunkIndexOf(String uuid) {
    for (var i = 0; i < ExamBleConstants.chunkCount; i++) {
      if (uuid.toUpperCase() ==
          ExamBleConstants.answerChunk(i).toUpperCase()) {
        return '$i';
      }
    }
    return null;
  }

  void _gradeAndAck() async {
    final paper = _paper;
    if (paper == null) return;
    final encoded = _answerChunks.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    final raw =
        ExamBleConstants.decode(encoded.map((e) => e.value).join());
    Map<String, dynamic>? payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {}
    if (payload == null) return;

    final name = (payload['name'] as String? ?? 'Student').trim();
    final answers = (payload['answers'] as List? ?? [])
        .map((a) => a as int?)
        .toList();
    var score = 0;
    for (var i = 0; i < paper.questions.length && i < answers.length; i++) {
      if (answers[i] == paper.questions[i].correctIndex) score++;
    }
    final result = OfflineExamResult(
      studentName: name.isEmpty ? 'Student' : name,
      answers: answers,
      score: score,
      total: paper.questions.length,
      submittedAt: DateTime.now(),
    );
    results.add(result);
    _answerChunks.clear();

    try {
      await peripheral.BlePeripheral.updateCharacteristic(
        characteristicId: ExamBleConstants.answerChunk(0),
        value: utf8.encode(jsonEncode({
          'score': result.score,
          'total': result.total,
          'percent': result.percent,
        })),
      );
    } catch (_) {}
    _onSubmit.add(result);
  }
}

/// Student side: discovers the teacher's phone over BLE and transfers the
/// paper and answers.
class OfflineExamBleClient {
  OfflineExamBleClient({this.scanTimeout = const Duration(seconds: 12)});

  final Duration scanTimeout;

  Future<void> _permissions() async {
    if (!Platform.isAndroid) return;
    try {
      await blue.FlutterBluePlus.turnOn();
    } catch (_) {}
  }

  Future<OfflineExamPaper?> downloadPaper() async {
    final device = await _findHost();
    if (device == null) return null;
    try {
      await device.connect(
        license: blue.License.nonprofit,
        timeout: const Duration(seconds: 10),
        mtu: 185,
      );
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.str.toUpperCase() !=
            ExamBleConstants.serviceUuid.toUpperCase()) {
          continue;
        }
        final chunks = <String>[];
        for (var i = 0; i < ExamBleConstants.chunkCount; i++) {
          final char = service.characteristics
              .where((c) =>
                  c.uuid.str.toUpperCase() ==
                  ExamBleConstants.paperChunk(i).toUpperCase())
              .firstOrNull;
          if (char == null) continue;
          final value = await char.read();
          chunks.add(utf8.decode(value));
        }
        final decoded = ExamBleConstants.decode(chunks.join());
        return OfflineExamPaper.decode(
            utf8.decode(base64Url.decode(decoded)));
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  /// Sends [name] + [answers], then waits for the teacher's score ack.
  /// Returns (score, total) or null on failure.
  Future<(int, int)?> submitAnswers(
    String name,
    List<int?> answers,
  ) async {
    final device = await _findHost();
    if (device == null) return null;
    try {
      await device.connect(
        license: blue.License.nonprofit,
        timeout: const Duration(seconds: 10),
        mtu: 185,
      );
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.str.toUpperCase() !=
            ExamBleConstants.serviceUuid.toUpperCase()) {
          continue;
        }
        final payload = ExamBleConstants.chunk(ExamBleConstants.encode(
            jsonEncode({'name': name, 'answers': answers})));
        for (var i = 0; i < payload.length && i < ExamBleConstants.chunkCount;
            i++) {
          final char = service.characteristics
              .where((c) =>
                  c.uuid.str.toUpperCase() ==
                  ExamBleConstants.answerChunk(i).toUpperCase())
              .firstOrNull;
          if (char == null) return null;
          await char.write(utf8.encode(payload[i]));
        }

        for (var attempt = 0; attempt < 20; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final ackChar = service.characteristics
              .where((c) =>
                  c.uuid.str.toUpperCase() ==
                  ExamBleConstants.answerChunk(0).toUpperCase())
              .firstOrNull;
          if (ackChar == null) return null;
          final ack = utf8.decode(await ackChar.read());
          if (ack.trim().isNotEmpty && ack.contains('score')) {
            final ackPayload = Map<String, dynamic>.from(jsonDecode(ack));
            return (
              ackPayload['score'] as int? ?? 0,
              ackPayload['total'] as int? ?? 0,
            );
          }
        }
        return null;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  Future<blue.BluetoothDevice?> _findHost() async {
    await _permissions();
    try {
      await blue.FlutterBluePlus.startScan(
        withServices: [blue.Guid(ExamBleConstants.serviceUuid)],
        timeout: scanTimeout,
      );
      for (final result in blue.FlutterBluePlus.lastScanResults) {
        final name = result.device.advName;
        if (name.contains(ExamBleConstants.advertisementName)) {
          return result.device;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      try {
        await blue.FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }
}
