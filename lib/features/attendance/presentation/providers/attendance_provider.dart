import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/providers/app_providers.dart';
import 'package:nexus_edu/core/repositories/attendance_repository.dart';
import 'package:nexus_edu/core/repositories/classroom_repository.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Sections owned by teacher
class TeacherSectionsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.getSections();
    if (res is Success<List<dynamic>>) return res.data;
    if (res is Failure<List<dynamic>>) throw Exception(res.message);
    return [];
  }

  Future<void> createSection({
    required String label,
    required String gradeLevel,
    String? subject,
    String? semester,
  }) async {
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.createSection(
      label: label,
      gradeLevel: gradeLevel,
      subject: subject,
      semester: semester,
    );
    if (res is Success<Map<String, dynamic>>) {
      ref.invalidateSelf();
    } else if (res is Failure<Map<String, dynamic>>) {
      throw Exception((res as Failure).message);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final teacherSectionsProvider =
    AsyncNotifierProvider<TeacherSectionsNotifier, List<dynamic>>(
      TeacherSectionsNotifier.new,
    );

/// My sections (student)
class MySectionsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.getMySections();
    if (res is Success<List<dynamic>>) return res.data;
    return [];
  }
}

final mySectionsProvider =
    AsyncNotifierProvider<MySectionsNotifier, List<dynamic>>(
      MySectionsNotifier.new,
    );

/// Roster for a section
class RosterState {
  const RosterState({required this.students, this.isLoading = false});
  final List<dynamic> students;
  final bool isLoading;
}

class RosterNotifier extends AsyncNotifier<RosterState> {
  String? sectionId;

  void init(String id) => sectionId = id;

  @override
  Future<RosterState> build() async {
    // sectionId may be null before init — return empty safely.
    if (sectionId == null) return const RosterState(students: []);
    return const RosterState(students: []);
  }

  Future<void> load(String id) async {
    sectionId = id;
    state = const AsyncValue.loading();
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.getSectionRoster(id);
    if (res is Success<List<dynamic>>) {
      state = AsyncValue.data(RosterState(students: res.data));
    } else if (res is Failure<List<dynamic>>) {
      state = AsyncValue.error(res.message, StackTrace.current);
    }
  }

  Future<void> addStudent(String email, {String? rollNumber}) async {
    if (sectionId == null) throw StateError('sectionId not set');
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.addStudentToSection(
      sectionId!,
      email,
      rollNumber: rollNumber,
    );
    if (res is Success<Map<String, dynamic>>) {
      await load(sectionId!);
    } else if (res is Failure<Map<String, dynamic>>) {
      throw Exception((res as Failure).message);
    }
  }

  Future<void> removeStudent(String studentId) async {
    if (sectionId == null) throw StateError('sectionId not set');
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.removeStudentFromSection(sectionId!, studentId);
    if (res is Success) {
      await load(sectionId!);
    } else if (res is Failure) {
      throw Exception((res as Failure).message);
    }
  }

  Future<void> importCsv(String csv) async {
    if (sectionId == null) throw StateError('sectionId not set');
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.importCsv(sectionId!, csv);
    if (res is Success<Map<String, dynamic>>) {
      await load(sectionId!);
    } else if (res is Failure<Map<String, dynamic>>) {
      throw Exception((res as Failure).message);
    }
  }
}

final rosterProvider = AsyncNotifierProvider<RosterNotifier, RosterState>(
  RosterNotifier.new,
);

/// Mark attendance flow (student)
class MarkAttendanceState {
  const MarkAttendanceState({
    this.openSessions = const [],
    this.selectedSession,
    this.isSubmitting = false,
    this.error,
    this.successStatus,
  });
  final List<dynamic> openSessions;
  final Map<String, dynamic>? selectedSession;
  final bool isSubmitting;
  final String? error;
  final String? successStatus;

  MarkAttendanceState copyWith({
    List<dynamic>? openSessions,
    Map<String, dynamic>? selectedSession,
    bool? isSubmitting,
    String? error,
    String? successStatus,
  }) => MarkAttendanceState(
    openSessions: openSessions ?? this.openSessions,
    selectedSession: selectedSession ?? this.selectedSession,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: error,
    successStatus: successStatus,
  );
}

class MarkAttendanceNotifier extends AsyncNotifier<MarkAttendanceState> {
  @override
  Future<MarkAttendanceState> build() async {
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.getMyOpenSessions();
    if (res is Success<List<dynamic>>) {
      return MarkAttendanceState(openSessions: res.data);
    }
    return const MarkAttendanceState();
  }

  void selectSession(Map<String, dynamic> session) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncValue.data(cur.copyWith(selectedSession: session));
  }

  Future<Result<Map<String, dynamic>>> submitCode(
    String sessionId,
    String code, {
    double? lat,
    double? lng,
    bool? isMocked,
  }) async {
    final cur = state.value;
    if (cur != null)
      state = AsyncValue.data(cur.copyWith(isSubmitting: true, error: null));
    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.markAttendance(
      sessionId,
      code,
      lat: lat,
      lng: lng,
      isMocked: isMocked,
    );
    final after = state.value ?? cur;
    if (after != null) {
      if (res is Success<Map<String, dynamic>>) {
        state = AsyncValue.data(
          after.copyWith(
            isSubmitting: false,
            successStatus: res.data['status']?.toString() ?? 'present',
          ),
        );
      } else if (res is Failure<Map<String, dynamic>>) {
        state = AsyncValue.data(
          after.copyWith(isSubmitting: false, error: res.message),
        );
      }
    }
    return res;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final markAttendanceProvider =
    AsyncNotifierProvider<MarkAttendanceNotifier, MarkAttendanceState>(
      MarkAttendanceNotifier.new,
    );

/// Attendance session details (teacher — code + roster polling)
class AttendanceSessionNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;

  void setSession(Map<String, dynamic> session) => state = session;
  void clear() => state = null;
}

final attendanceSessionProvider =
    NotifierProvider<AttendanceSessionNotifier, Map<String, dynamic>?>(
      AttendanceSessionNotifier.new,
    );

/// Classroom tasks + notifications
class ClassroomTasksNotifier extends AsyncNotifier<List<dynamic>> {
  String? sectionId;
  @override
  Future<List<dynamic>> build() async {
    final repo = ref.read(classroomRepositoryProvider);
    final res = await repo.getTasks(sectionId: sectionId);
    if (res is Success<List<dynamic>>) return res.data;
    return [];
  }

  Future<void> load({String? forSection}) async {
    sectionId = forSection;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> create({
    required String sectionId,
    required String title,
    String? description,
    DateTime? dueDate,
    int points = 0,
  }) async {
    final repo = ref.read(classroomRepositoryProvider);
    final res = await repo.createTask(
      sectionId: sectionId,
      title: title,
      description: description,
      dueDate: dueDate,
      points: points,
    );
    if (res is Success<Map<String, dynamic>>) {
      ref.invalidateSelf();
    } else if (res is Failure<Map<String, dynamic>>) {
      throw Exception((res as Failure).message);
    }
  }

  Future<void> submit(
    String taskId, {
    required String status,
    String? content,
  }) async {
    final repo = ref.read(classroomRepositoryProvider);
    final res = await repo.submitTask(taskId, status: status, content: content);
    if (res is Failure<Map<String, dynamic>>)
      throw Exception((res as Failure).message);
  }
}

final classroomTasksProvider =
    AsyncNotifierProvider<ClassroomTasksNotifier, List<dynamic>>(
      ClassroomTasksNotifier.new,
    );
