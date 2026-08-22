import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_edu/features/attendance/data/attendance_hotspot.dart';

AttendanceHotspotSession _session({bool fenced = true}) {
  return AttendanceHotspotSession(
    sessionId: 'sess-1',
    subject: 'Physics',
    teacherName: 'Mrs Rao',
    code: '123456',
    codeExpiresAt: DateTime.now().add(const Duration(seconds: 25)),
    lat: fenced ? 19.076 : null,
    lng: fenced ? 72.8777 : null,
    radiusMeters: fenced ? 75 : null,
  );
}

void main() {
  test('distanceMetersBetween: same point is 0, ~111m per 0.001 deg lat',
      () {
    expect(
      distanceMetersBetween(19.076, 72.8777, 19.076, 72.8777),
      closeTo(0, 0.001),
    );
    final d = distanceMetersBetween(19.076, 72.8777, 19.077, 72.8777);
    expect(d, closeTo(111.2, 1));
  });

  test('hotspot server: session round trip + mark + duplicate + roster',
      () async {
    final server = AttendanceHotspotServer(port: 0);
    await server.start(_session());
    final port = server.boundPort;

    final client = AttendanceHotspotClient();
    final session = await client.fetchSession('127.0.0.1', port);
    expect(session, isNotNull);
    expect(session!.subject, 'Physics');
    expect(session.teacherName, 'Mrs Rao');
    expect(session.code, '123456');
    expect(session.isFenced, isTrue);

    final mark = AttendanceHotspotMark(
      studentId: 'u1',
      clientMarkedAt: DateTime.now(),
      code: '123456',
      lat: 19.076,
      lng: 72.8777,
    );
    final ack = await client.submitMark('127.0.0.1', port, mark);
    expect(ack, isNotNull);
    expect(ack!['ok'], isTrue);

    final dup = await client.submitMark('127.0.0.1', port, mark);
    expect(dup!['error'], 'duplicate');

    expect(server.marks, hasLength(1));
    expect(server.marks.single.studentId, 'u1');
    await server.stop();
  });

  test('hotspot server: geofence rejects out-of-range and mock marks',
      () async {
    final server = AttendanceHotspotServer(port: 0);
    await server.start(_session());
    final port = server.boundPort;
    final client = AttendanceHotspotClient();

    final far = await client.submitMark(
      '127.0.0.1',
      port,
      AttendanceHotspotMark(
        studentId: 'u2',
        clientMarkedAt: DateTime.now(),
        code: '123456',
        lat: 19.0,
        lng: 72.8,
      ),
    );
    expect(far!['error'], 'outside_zone');

    final mock = await client.submitMark(
      '127.0.0.1',
      port,
      AttendanceHotspotMark(
        studentId: 'u3',
        clientMarkedAt: DateTime.now(),
        code: '123456',
        lat: 19.076,
        lng: 72.8777,
        isMocked: true,
      ),
    );
    expect(mock!['error'], 'mock_location');

    final noLoc = await client.submitMark(
      '127.0.0.1',
      port,
      AttendanceHotspotMark(
        studentId: 'u4',
        clientMarkedAt: DateTime.now(),
        code: '123456',
      ),
    );
    expect(noLoc!['error'], 'no_location');

    expect(server.marks, isEmpty);
    await server.stop();
  });

  test('unfenced session accepts marks without location', () async {
    final server = AttendanceHotspotServer(port: 0);
    await server.start(_session(fenced: false));
    final port = server.boundPort;
    final client = AttendanceHotspotClient();

    final ack = await client.submitMark(
      '127.0.0.1',
      port,
      AttendanceHotspotMark(
        studentId: 'u5',
        clientMarkedAt: DateTime.now(),
        code: '123456',
      ),
    );
    expect(ack!['ok'], isTrue);
    expect(server.marks, hasLength(1));
    await server.stop();
  });

  test('session json round trip survives the ble chunk budget', () {
    final session = _session();
    final encoded = base64Url.encode(utf8.encode(jsonEncode(session.toJson())));
    final chunks = _chunk(encoded);
    expect(chunks.length, lessThanOrEqualTo(4));

    final decoded = utf8.decode(
      base64Url.decode(chunks.join().replaceAll('~', '')),
    );
    final restored = AttendanceHotspotSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(decoded)),
    );
    expect(restored!.sessionId, session.sessionId);
    expect(restored.lat, session.lat);
  });
}

List<String> _chunk(String payload) {
  const chunkSize = 120;
  final chunks = <String>[];
  for (var i = 0; i < 4; i++) {
    final start = i * chunkSize;
    if (start >= payload.length) break;
    final end = (start + chunkSize).clamp(0, payload.length);
    var part = payload.substring(start, end);
    if (part.length < chunkSize) part = part.padRight(chunkSize, '~');
    chunks.add(part);
  }
  return chunks;
}
