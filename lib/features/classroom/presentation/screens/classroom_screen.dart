import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/features/attendance/presentation/screens/mark_attendance_screen.dart';
import 'package:nexus_edu/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// The Classroom tab: one place for the whole classroom life, right in the
/// bottom bar.
///
/// Students see the join flow (scan the QR their teacher shows, or type the
/// invite code) and mark attendance; teachers see their sections, manage
/// rosters and run attendance sessions. The tab is role-aware — guests and
/// students get the student flow, teachers get the sections flow, and the
/// underlying screens keep their own self-gates for signed-out states.
class ClassroomScreen extends StatelessWidget {
  const ClassroomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SecureApiService().isTeacher
        ? const TeacherAttendanceScreen()
        : const MarkAttendanceScreen();
  }
}
