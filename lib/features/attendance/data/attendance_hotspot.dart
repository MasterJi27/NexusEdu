import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ble_peripheral/ble_peripheral.dart' as peripheral;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue;
import 'package:http/http.dart' as http;

import 'package:nexus_edu/features/offline_exam/data/exam_ble.dart';

/// Peer-to-peer attendance for classrooms with no internet at all. The
/// teacher's phone hosts the session — over the WiFi hotspot (HTTP, port
/// 8788) and/or a BLE beacon (for the phones an old hotspot's ~8-device
/// limit leaves out). Marks land on the teacher's phone, get queued in the
/// sync outbox, and flush to `POST /api/attendance/sessions/:id/batch` when
/// connectivity returns.

class AttendanceHotspotSession {
  AttendanceHotspotSession({
    required this.sessionId,
    required this.subject,
    required this.teacherName,
    required this.code,
    required this.codeExpiresAt,
    this.lat,
    this.lng,
    this.radiusMeters,
  });

  final String sessionId;
  final String subject;
  final String teacherName;
  String code;
  DateTime codeExpiresAt;
  final double? lat;
  final double? lng;
  final int? radiusMeters;

  bool get isFenced => lat != null && lng != null && radiusMeters != null;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'subject': subject,
        'teacherName': teacherName,
        'code': code,
        'codeExpiresAt': codeExpiresAt.toUtc().toIso8601String(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusMeters != null) 'radiusMeters': radiusMeters,
      };

  static AttendanceHotspotSession? fromJson(Map<String, dynamic> json) {
    final sessionId = json['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) return null;
    return AttendanceHotspotSession(
      sessionId: sessionId,
      subject: json['subject'] as String? ?? 'Attendance',
      teacherName: json['teacherName'] as String? ?? 'Teacher',
      code: json['code'] as String? ?? '',
      codeExpiresAt:
          DateTime.tryParse(json['codeExpiresAt'] as String? ?? '') ??
              DateTime.now(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      radiusMeters: (json['radiusMeters'] as num?)?.toInt(),
    );
  }
}

class AttendanceHotspotMark {
  AttendanceHotspotMark({
    required this.studentId,
    required this.clientMarkedAt,
    this.lat,
    this.lng,
    this.isMocked,
  });

  final String studentId;
  final DateTime clientMarkedAt;
  final double? lat;
  final double? lng;
  final bool? isMocked;

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'clientMarkedAt': clientMarkedAt.toUtc().toIso8601String(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (isMocked != null) 'isMocked': isMocked,
      };

  static AttendanceHotspotMark? fromJson(Map<String, dynamic> json) {
    final studentId = json['studentId'] as String?;
    if (studentId == null || studentId.isEmpty) return null;
    return AttendanceHotspotMark(
      studentId: studentId,
      clientMarkedAt:
          DateTime.tryParse(json['clientMarkedAt'] as String? ?? '') ??
              DateTime.now(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isMocked: json['isMocked'] as bool?,
    );
  }
}

/// Mirrors the server's haversine so the teacher's phone can fail fast at
/// mark time; the backend re-checks authoritatively at batch upload.
double distanceMetersBetween(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusMeters = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Same checks the backend batch route applies, minus enrollment (the
/// teacher's phone does not know the roster offline). Returns an error code
/// or null when the mark is acceptable.
String? validateHotspotMark(
  AttendanceHotspotSession session,
  AttendanceHotspotMark mark, {
  required Set<String> alreadyMarked,
}) {
  if (alreadyMarked.contains(mark.studentId)) return 'duplicate';
  if (session.isFenced) {
    if (mark.isMocked == true) return 'mock_location';
    final lat = mark.lat;
    final lng = mark.lng;
    if (lat == null || lng == null) return 'no_location';
    final distance =
        distanceMetersBetween(session.lat!, session.lng!, lat, lng);
    if (distance > (session.radiusMeters ?? 75) + 20) return 'outside_zone';
  }
  return null;
}

/// Teacher side, WiFi-hotspot transport. Students reach it at
/// `http://<teacherIp>:8788`.
class AttendanceHotspotServer {
  AttendanceHotspotServer({this.port = 8788});

  final int port;
  HttpServer? _server;
  AttendanceHotspotSession? _session;
  final List<AttendanceHotspotMark> _marks = [];
  final Set<String> _markedStudents = {};
  final _onMark = StreamController<AttendanceHotspotMark>.broadcast();

  bool get isRunning => _server != null;
  int get boundPort => _server?.port ?? port;
  List<AttendanceHotspotMark> get marks => List.unmodifiable(_marks);
  Stream<AttendanceHotspotMark> get onMark => _onMark.stream;

  Future<void> start(AttendanceHotspotSession session) async {
    await stop();
    _session = session;
    _marks.clear();
    _markedStudents.clear();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void updateCode(String code, DateTime codeExpiresAt) {
    final session = _session;
    if (session != null) {
      session.code = code;
      session.codeExpiresAt = codeExpiresAt;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final response = request.response;
      if (path == '/health') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({
          'ok': true,
          'subject': _session?.subject ?? '',
        }));
      } else if (path == '/session') {
        final session = _session;
        if (session == null) {
          response.statusCode = HttpStatus.notFound;
          response.write('No session hosted.');
        } else {
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(session.toJson()));
        }
      } else if (path == '/mark' && request.method == 'POST') {
        final payload = Map<String, dynamic>.from(
          jsonDecode(await utf8.decodeStream(request)),
        );
        final mark = AttendanceHotspotMark.fromJson(payload);
        final session = _session;
        if (mark == null || session == null) {
          response.statusCode = HttpStatus.badRequest;
          response.write(jsonEncode({'ok': false, 'error': 'bad_mark'}));
        } else {
          final error = validateHotspotMark(
            session,
            mark,
            alreadyMarked: _markedStudents,
          );
          if (error != null) {
            response.statusCode = HttpStatus.badRequest;
            response.write(jsonEncode({'ok': false, 'error': error}));
          } else {
            _marks.add(mark);
            _markedStudents.add(mark.studentId);
            _onMark.add(mark);
            response.headers.contentType = ContentType.json;
            response.write(jsonEncode({'ok': true, 'queued': _marks.length}));
          }
        }
      } else if (path == '/roster') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({
          'count': _marks.length,
          'marks': _marks.map((m) => m.toJson()).toList(),
        }));
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write('Not found.');
      }
      await response.close();
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }
}

/// Student side, WiFi-hotspot transport.
class AttendanceHotspotClient {
  AttendanceHotspotClient({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;

  Future<AttendanceHotspotSession?> fetchSession(String host, int port) async {
    try {
      final response = await http
          .get(Uri.parse('http://$host:$port/session'))
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      return AttendanceHotspotSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body)),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns {'ok': true} on success, {'error': code} on rejection, or null
  /// when the teacher could not be reached.
  Future<Map<String, dynamic>?> submitMark(
    String host,
    int port,
    AttendanceHotspotMark mark,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://$host:$port/mark'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(mark.toJson()),
          )
          .timeout(timeout);
      final decoded =
          Map<String, dynamic>.from(jsonDecode(response.body));
      return decoded['ok'] == true
          ? decoded
          : {
              'error': decoded['error'] ?? 'Mark rejected by the teacher.',
            };
    } catch (_) {
      return null;
    }
  }
}

/// BLE characteristic layout for attendance (reuses the exam GATT service so
/// scans filter on one UUID; chunks are `...4520-23` for the session and
/// `...4530-33` for marks, `4530` also carrying the ack).
abstract final class AttendanceBleConstants {
  static const String advertisementName = 'NexusAttend';

  static String sessionChunk(int i) =>
      'a1e5b0ff-0ff1-4e1d-8f0f-0ff1c311e452${i.toRadixString(16)}';
  static String markChunk(int i) =>
      'a1e5b0ff-0ff1-4e1d-8f0f-0ff1c311e453${i.toRadixString(16)}';
}

/// Teacher side, BLE transport: advertises the session and collects marks
/// over the same chunked protocol the offline exam uses.
class AttendanceBleHost {
  final List<AttendanceHotspotMark> marks = [];
  final _onMark = StreamController<AttendanceHotspotMark>.broadcast();

  bool _advertising = false;
  AttendanceHotspotSession? _session;
  final Map<String, String> _markChunks = {};
  final Set<String> _markedStudents = {};
  bool _initialized = false;

  Stream<AttendanceHotspotMark> get onSubmit => _onMark.stream;
  bool get isAdvertising => _advertising;

  Future<void> start(AttendanceHotspotSession session) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('BLE hosting is not supported on this platform.');
    }
    _session = session;
    try {
      await peripheral.BlePeripheral.initialize();
      _initialized = true;
    } catch (_) {
      throw StateError('Bluetooth not available. Turn it on and try again.');
    }

    await peripheral.BlePeripheral.clearServices();

    final chars = <peripheral.BleCharacteristic>[];
    final sessionChunks = ExamBleConstants.chunk(
      ExamBleConstants.encode(jsonEncode(session.toJson())),
    );
    for (var i = 0; i < ExamBleConstants.chunkCount; i++) {
      chars.add(peripheral.BleCharacteristic(
        uuid: AttendanceBleConstants.sessionChunk(i),
        properties: [
          peripheral.CharacteristicProperties.read.index,
          peripheral.CharacteristicProperties.notify.index,
        ],
        value: i < sessionChunks.length ? utf8.encode(sessionChunks[i]) : null,
        permissions: [peripheral.AttributePermissions.readable.index],
      ));
    }
    for (var i = 0; i < ExamBleConstants.chunkCount; i++) {
      chars.add(peripheral.BleCharacteristic(
        uuid: AttendanceBleConstants.markChunk(i),
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

    _markChunks.clear();
    marks.clear();
    _markedStudents.clear();
    peripheral.BlePeripheral.setWriteRequestCallback(
        (deviceId, characteristicId, offset, value) {
      if (value == null) return null;
      final chunkIndex = _chunkIndexOf(characteristicId);
      if (chunkIndex == null) return null;
      _markChunks[chunkIndex] = utf8.decode(value);
      if (_markChunks.length == ExamBleConstants.chunkCount) {
        _handleMarkAndAck();
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
      localName: AttendanceBleConstants.advertisementName,
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
          AttendanceBleConstants.markChunk(i).toUpperCase()) {
        return '$i';
      }
    }
    return null;
  }

  Future<void> _handleMarkAndAck() async {
    final session = _session;
    if (session == null) return;
    final encoded = _markChunks.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    final raw = ExamBleConstants.decode(encoded.map((e) => e.value).join());
    Map<String, dynamic>? payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {}
    final mark = payload == null ? null : AttendanceHotspotMark.fromJson(payload);
    final error =
        mark == null ? 'bad_mark' : validateHotspotMark(session, mark, alreadyMarked: _markedStudents);
    if (error == null && mark != null) {
      marks.add(mark);
      _markedStudents.add(mark.studentId);
      _onMark.add(mark);
    }
    _markChunks.clear();
    try {
      await peripheral.BlePeripheral.updateCharacteristic(
        characteristicId: AttendanceBleConstants.markChunk(0),
        value: utf8.encode(jsonEncode({
          'ok': error == null,
          'error': ?error,
        })),
      );
    } catch (_) {}
  }
}

/// Student side, BLE transport: finds the teacher's beacon and transfers
/// the session and the mark.
class AttendanceBleClient {
  AttendanceBleClient({this.scanTimeout = const Duration(seconds: 12)});

  final Duration scanTimeout;

  Future<void> _permissions() async {
    if (!Platform.isAndroid) return;
    try {
      await blue.FlutterBluePlus.turnOn();
    } catch (_) {}
  }

  Future<AttendanceHotspotSession?> fetchSession() async {
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
                  AttendanceBleConstants.sessionChunk(i).toUpperCase())
              .firstOrNull;
          if (char == null) continue;
          chunks.add(utf8.decode(await char.read()));
        }
        final decoded = ExamBleConstants.decode(chunks.join());
        return AttendanceHotspotSession.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(utf8.decode(base64Url.decode(decoded))),
          ),
        );
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

  /// Sends the mark and waits for the teacher's ack. Returns {'ok': true},
  /// {'error': code}, or null when the teacher could not be reached.
  Future<Map<String, dynamic>?> submitMark(AttendanceHotspotMark mark) async {
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
        final payload = ExamBleConstants.chunk(
          ExamBleConstants.encode(jsonEncode(mark.toJson())),
        );
        for (var i = 0; i < payload.length && i < ExamBleConstants.chunkCount;
            i++) {
          final char = service.characteristics
              .where((c) =>
                  c.uuid.str.toUpperCase() ==
                  AttendanceBleConstants.markChunk(i).toUpperCase())
              .firstOrNull;
          if (char == null) return null;
          await char.write(utf8.encode(payload[i]));
        }

        for (var attempt = 0; attempt < 20; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final ackChar = service.characteristics
              .where((c) =>
                  c.uuid.str.toUpperCase() ==
                  AttendanceBleConstants.markChunk(0).toUpperCase())
              .firstOrNull;
          if (ackChar == null) return null;
          final ack = utf8.decode(await ackChar.read());
          if (ack.trim().isNotEmpty && ack.contains('ok')) {
            final ackPayload = Map<String, dynamic>.from(jsonDecode(ack));
            return ackPayload['ok'] == true
                ? ackPayload
                : {
                    'error': ackPayload['error'] ?? 'Mark rejected by the teacher.',
                  };
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
        if (name.contains(AttendanceBleConstants.advertisementName)) {
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
