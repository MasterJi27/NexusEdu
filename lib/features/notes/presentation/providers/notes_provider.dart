import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/providers/app_providers.dart';
import 'package:nexus_edu/core/repositories/notes_repository.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/notes_sync_service.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Typed note model — replaces `Map<String,dynamic>` in screens.
class Note {
  Note({
    this.id,
    required this.title,
    required this.content,
    required this.date,
    this.subject = 'General',
    this.colorIndex = 0,
    this.dirty = false,
  });

  final String? id;
  String title;
  String content;
  String date;
  String subject;
  int colorIndex;
  bool dirty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date,
        'subject': subject,
        'color': colorIndex,
        'dirty': dirty,
      };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        id: m['id']?.toString(),
        title: m['title']?.toString() ?? '',
        content: m['content']?.toString() ?? '',
        date: m['date']?.toString() ?? '',
        subject: m['subject']?.toString() ?? 'General',
        colorIndex: m['color'] is int ? m['color'] as int : 0,
        dirty: m['dirty'] == true,
      );
}

class NotesState {
  const NotesState({required this.notes, this.isSyncing = false});
  final List<Note> notes;
  final bool isSyncing;
}

class NotesNotifier extends AsyncNotifier<NotesState> {
  NotesRepository get _repo => ref.read(notesRepositoryProvider);
  AppSettings get _settings => ref.read(appSettingsProvider);

  @override
  Future<NotesState> build() async {
    // Cache-first: instant UI from local, then server merge in background.
    final cached = _settings.cachedNotes.map((e) => Note.fromMap(e)).toList();
    // Kick off sync without blocking UI — merge result will update state.
    Future.microtask(_syncWithServer);
    if (cached.isEmpty && !_isLoggedIn) {
      // Guest demo seeding — keep inline for now.
      final demos = _demoNotes();
      await _settings.saveCachedNotes(demos.map((n) => n.toMap()).toList());
      return NotesState(notes: demos);
    }
    return NotesState(notes: cached);
  }

  bool get _isLoggedIn => ref.read(secureApiServiceProvider).isLoggedIn;

  List<Note> _demoNotes() => [
        Note(title: 'Welcome to Nexus Edu', content: 'Your AI study companion.', date: 'Today', subject: 'General'),
        Note(title: 'Physics — Motion', content: 'Speed = distance / time', date: 'Today', subject: 'Physics', colorIndex: 1),
      ];

  Future<void> _syncWithServer() async {
    if (!_isLoggedIn) return;
    final current = state.value?.notes ?? [];
    // Use existing NotesSyncService merge (pure + tested) via cached maps.
    final cachedMaps = current.map((n) => n.toMap()).toList();
    final mergedMaps = await NotesSyncService.pull(cachedMaps);
    // pull already saved to AppSettings; now reflect in provider.
    final merged = mergedMaps.map((e) => Note.fromMap(Map<String, dynamic>.from(e))).toList();
    if (merged.length != current.length || !_listsEqual(current, merged)) {
      state = AsyncValue.data(NotesState(notes: merged));
    }
    // Push dirty afterwards (fire-and-forget).
    final toPush = merged.map((n) => n.toMap()).toList();
    await NotesSyncService.pushDirty(toPush);
  }

  bool _listsEqual(List<Note> a, List<Note> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].title != b[i].title) return false;
    }
    return true;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final res = await _repo.getNotes();
    if (res is Success<List<dynamic>>) {
      final notes = res.data.map((e) => Note.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      await _settings.saveCachedNotes(notes.map((n) => n.toMap()).toList());
      state = AsyncValue.data(NotesState(notes: notes));
    } else if (res is Failure<List<dynamic>>) {
      state = AsyncValue.error(res.message, StackTrace.current);
    } else {
      state = await AsyncValue.guard(() => build().then((s) => s));
    }
  }

  Future<void> addNote(Note note) async {
    final current = state.value?.notes ?? [];
    final updated = [note, ...current];
    state = AsyncValue.data(NotesState(notes: updated, isSyncing: true));
    await _settings.saveCachedNotes(updated.map((n) => n.toMap()).toList());
    // Mark dirty push
    await NotesSyncService.pushDirty(updated.map((n) => n.toMap()).toList());
    state = AsyncValue.data(NotesState(notes: updated));
  }

  Future<void> updateNote(int index, Note note) async {
    final current = List<Note>.from(state.value?.notes ?? []);
    if (index < 0 || index >= current.length) return;
    current[index] = note..dirty = true;
    state = AsyncValue.data(NotesState(notes: current, isSyncing: true));
    await _settings.saveCachedNotes(current.map((n) => n.toMap()).toList());
    await NotesSyncService.pushDirty(current.map((n) => n.toMap()).toList());
    state = AsyncValue.data(NotesState(notes: current));
  }

  Future<void> deleteNote(int index) async {
    final current = List<Note>.from(state.value?.notes ?? []);
    if (index < 0 || index >= current.length) return;
    final removed = current.removeAt(index);
    state = AsyncValue.data(NotesState(notes: current));
    await _settings.saveCachedNotes(current.map((n) => n.toMap()).toList());
    if (removed.id != null) {
      await NotesSyncService.deleteOnServer(removed.id!);
    }
  }

  /// QR codec extracted from `notes_screen.dart:375` — pure, testable.
  static String encodeNoteToQrPayload(Note note) {
    final jsonStr = jsonEncode(note.toMap());
    final b64 = base64Url.encode(utf8.encode(jsonStr));
    return 'nexusedu://note/$b64';
  }

  static Note? decodeNoteFromQrPayload(String payload) {
    try {
      final uri = Uri.parse(payload);
      if (uri.scheme != 'nexusedu' || uri.host != 'note') return null;
      final b64 = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      final jsonStr = utf8.decode(base64Url.decode(b64));
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Note.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}

final notesProvider = AsyncNotifierProvider<NotesNotifier, NotesState>(NotesNotifier.new);

/// Class notes (teacher-published) — separate AsyncNotifier so empty vs error distinct.
class ClassNotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final repo = ref.read(notesRepositoryProvider);
    final isLoggedIn = ref.read(secureApiServiceProvider).isLoggedIn;
    if (!isLoggedIn) return [];
    final res = await repo.getTeacherNotes();
    if (res is Success<List<dynamic>>) {
      return res.data.map((e) => Note.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    }
    // Failure → throw to surface as AsyncError, not empty.
    if (res is Failure<List<dynamic>>) throw Exception(res.message);
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final classNotesProvider = AsyncNotifierProvider<ClassNotesNotifier, List<Note>>(ClassNotesNotifier.new);
