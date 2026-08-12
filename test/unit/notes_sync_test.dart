import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/services/notes_sync_service.dart';

void main() {
  group('NotesSyncService.merge', () {
    test('server note replaces local by id, keeping display extras', () {
      final local = [
        {'id': 'a', 'title': 'Old title', 'content': 'old', 'date': 'Today', 'subject': 'Physics'},
        {'title': 'Local only', 'content': 'x', 'date': 'Yesterday'},
      ];
      final server = [
        {'id': 'a', 'title': 'New title', 'content': 'new', 'updatedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
        {'id': 'c', 'title': 'From other device', 'content': 'y', 'updatedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
      ];
      final merged = NotesSyncService.merge(local, server);
      expect(merged.length, 3);
      final a = merged.firstWhere((n) => n['id'] == 'a');
      expect(a['title'], 'New title');
      expect(a['date'], 'Today');
      expect(a['subject'], 'Physics');
      final b = merged.firstWhere((n) => n['id'] == null);
      expect(b['title'], 'Local only'); // unsynced: kept for upload
      final c = merged.firstWhere((n) => n['id'] == 'c');
      expect(c['subject'], 'General');
      expect(c['date'], 'Yesterday');
    });

    test('local note deleted on server disappears; demo notes dropped', () {
      final local = [
        {'id': 'gone', 'title': 'Deleted elsewhere', 'content': 'x'},
        {'id': 'keep', 'title': 'Keeper', 'content': 'y'},
        {'title': 'Demo', 'content': 'z', 'demo': true},
        {'title': 'New local', 'content': 'w'},
      ];
      final server = [
        {'id': 'keep', 'title': 'Keeper', 'content': 'y'},
      ];
      final merged = NotesSyncService.merge(local, server);
      expect(merged.map((n) => n['title']), ['Keeper', 'New local']);
    });

    test('dirty local edits survive merge onto server content', () {
      final local = [
        {'id': 'a', 'title': 'Dirty edit', 'content': 'edited', 'dirty': true, 'date': 'Today'},
      ];
      final server = [
        {'id': 'a', 'title': 'Server copy', 'content': 'stale', 'updatedAt': '2026-08-01T00:00:00Z'},
      ];
      final merged = NotesSyncService.merge(local, server);
      expect(merged.single['title'], 'Server copy');
      expect(merged.single['dirty'], true); // pushDirty will PUT it
      expect(merged.single['content'], 'stale');
    });

    test('relativeDate formats server timestamps', () {
      expect(NotesSyncService.relativeDate(null), '');
      expect(NotesSyncService.relativeDate('garbage'), '');
      final today = DateTime.now().toIso8601String();
      expect(NotesSyncService.relativeDate(today), 'Today');
    });
  });
}
