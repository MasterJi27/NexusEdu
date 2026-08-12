import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Server sync for a student's own notes ("My Notes" tab).
///
/// The local cache (SharedPreferences) stays the instant UI store; the server
/// is the durable copy for logged-in users. Notes carry two bookkeeping keys:
/// - `id`    — server uuid, absent until the note has been uploaded
/// - `dirty` — set by edits, cleared once the server confirms the update
///
/// Guest users are fully offline: every method is a no-op without a session.
class NotesSyncService {
  NotesSyncService._();

  static bool _syncing = false;

  /// Uploads notes that are not on the server yet (`id` null) and edits that
  /// are (`dirty` true). Writes server ids back into the local cache so a
  /// later edit goes to PUT instead of duplicating.
  static Future<void> pushDirty(List<Map<String, dynamic>> notes) async {
    if (_syncing || !SecureApiService().isLoggedIn) return;
    _syncing = true;
    try {
      final api = SecureApiService();
      for (var i = 0; i < notes.length; i++) {
        final note = notes[i];
        if (note['demo'] == true) continue;
        final id = note['id']?.toString();
        if (id == null) {
          final created = await api.createNote(
            title: (note['title'] ?? 'Untitled').toString(),
            content: (note['content'] ?? '').toString(),
            latitude: (note['latitude'] as num?)?.toDouble(),
            longitude: (note['longitude'] as num?)?.toDouble(),
          );
          final serverId = created['id']?.toString();
          if (serverId != null) notes[i] = {...note, 'id': serverId};
        } else if (note['dirty'] == true) {
          await api.updateNote(
            id: id,
            title: (note['title'] ?? 'Untitled').toString(),
            content: (note['content'] ?? '').toString(),
            latitude: (note['latitude'] as num?)?.toDouble(),
            longitude: (note['longitude'] as num?)?.toDouble(),
          );
          notes[i] = {...note, 'dirty': false};
        }
      }
      AppSettings.instance.saveCachedNotes(notes);
    } catch (_) {
      // Offline: the local cache keeps the note; the next save retries.
    } finally {
      _syncing = false;
    }
  }

  /// Removes a note from the server. No-op for guest notes (`id` null).
  static Future<void> deleteOnServer(String? id) async {
    if (id == null || !SecureApiService().isLoggedIn) return;
    try {
      await SecureApiService().deleteNote(id);
    } catch (_) {
      // The local delete stands; the server copy lingers until it is
      // deleted again while online.
    }
  }

  /// Pulls the server copy and merges it with the local cache. Server wins
  /// on ids; local notes without an id (never uploaded) are kept and get
  /// uploaded by [pushDirty]; guest demo seeds are dropped for logged-in
  /// users.
  static Future<List<Map<String, dynamic>>> pull(
    List<Map<String, dynamic>> local,
  ) async {
    if (!SecureApiService().isLoggedIn) return local;
    try {
      final serverRaw = await SecureApiService().getNotes();
      final server = serverRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final merged = merge(local, server);
      AppSettings.instance.saveCachedNotes(merged);
      return merged;
    } catch (_) {
      return local;
    }
  }

  /// Pure 3-way merge, extracted for tests. [server] entries carry at least
  /// `id`, `title`, `content`; [local] entries may carry extra display keys
  /// (`date`, `subject`, `color`) and bookkeeping (`id`, `dirty`, `demo`).
  static List<Map<String, dynamic>> merge(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> server,
  ) {
    final serverById = <String, Map<String, dynamic>>{
      for (final s in server)
        if (s['id'] != null) s['id'].toString(): Map<String, dynamic>.from(s),
    };
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final n in local) {
      final id = n['id']?.toString();
      if (n['demo'] == true) continue;
      if (id == null) {
        merged.add(n); // never uploaded: keep local, pushDirty uploads it
        continue;
      }
      seen.add(id);
      final s = serverById[id];
      if (s == null) continue; // deleted on another device: drop
      merged.add({
        ...s,
        'date': n['date'],
        'subject': n['subject'],
        'color': n['color'],
        'dirty': n['dirty'] == true,
      });
    }
    for (final s in server) {
      final id = s['id'].toString();
      if (!seen.contains(id)) {
        merged.add({
          ...s,
          'date': relativeDate(s['updatedAt']?.toString()),
          'subject': 'General',
        });
      }
    }
    return merged;
  }

  /// 'Today' / 'Yesterday' / 'N days ago' for server timestamps.
  static String relativeDate(String? iso) {
    final date = DateTime.tryParse(iso ?? '');
    if (date == null) return '';
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(date.year, date.month, date.day);
    final days = d0.difference(d1).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }
}
