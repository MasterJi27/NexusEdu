import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/models/app_user.dart';
import 'package:nexus_edu/core/models/study_note.dart';

void main() {
  group('AppUser', () {
    test('creates with default values', () {
      final user = AppUser(id: '1', name: 'Test', email: 'test@test.com');
      expect(user.id, '1');
      expect(user.name, 'Test');
      expect(user.email, 'test@test.com');
      expect(user.role, UserRole.student);
      expect(user.xp, 0);
      expect(user.streak, 0);
    });

    test('serializes to and from map', () {
      final user = AppUser(
        id: '1',
        name: 'Test',
        email: 'test@test.com',
        role: UserRole.teacher,
        xp: 500,
        streak: 7,
      );
      final map = user.toMap();
      final restored = AppUser.fromMap(map, '1');
      expect(restored.id, user.id);
      expect(restored.name, user.name);
      expect(restored.email, user.email);
      expect(restored.role, user.role);
      expect(restored.xp, user.xp);
      expect(restored.streak, user.streak);
    });

    test('handles missing optional fields in fromMap', () {
      final map = <String, dynamic>{'name': 'Test', 'email': 'test@test.com'};
      final user = AppUser.fromMap(map, '1');
      expect(user.role, UserRole.student);
      expect(user.xp, 0);
    });
  });

  group('StudyNote', () {
    test('creates with default timestamps', () {
      final note = StudyNote(id: '1', userId: 'u1', title: 'Title', content: 'Content', topic: 'Math');
      expect(note.isFavorite, false);
      expect(note.createdAt, isNotNull);
      expect(note.updatedAt, isNotNull);
    });

    test('copyWith updates fields', () {
      final note = StudyNote(id: '1', userId: 'u1', title: 'Title', content: 'Content', topic: 'Math');
      final updated = note.copyWith(title: 'New Title', isFavorite: true);
      expect(updated.title, 'New Title');
      expect(updated.isFavorite, true);
      expect(updated.content, 'Content');
    });

    test('serializes to and from map', () {
      final note = StudyNote(id: '1', userId: 'u1', title: 'Title', content: 'Content', topic: 'Math', isFavorite: true);
      final map = note.toMap();
      final restored = StudyNote.fromMap(map, '1');
      expect(restored.title, note.title);
      expect(restored.content, note.content);
      expect(restored.isFavorite, note.isFavorite);
    });
  });
}
