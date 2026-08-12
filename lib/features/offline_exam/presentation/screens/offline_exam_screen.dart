import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_edu/core/services/question_bank_local.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/services/sync_queue_service.dart';
import 'package:nexus_edu/core/theme/app_theme.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/features/offline_exam/data/exam_ble.dart';
import 'package:nexus_edu/features/offline_exam/data/exam_client.dart';
import 'package:nexus_edu/features/offline_exam/data/exam_server.dart';
import 'package:nexus_edu/features/offline_exam/domain/offline_exam_models.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

/// Hosts and writes exams without internet: a teacher starts a paper over
/// the WiFi hotspot (HTTP) or Bluetooth, students join, answer and get
/// graded — all locally, all offline.
class OfflineExamScreen extends StatefulWidget {
  const OfflineExamScreen({super.key});

  @override
  State<OfflineExamScreen> createState() => _OfflineExamScreenState();
}

class _OfflineExamScreenState extends State<OfflineExamScreen> {
  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: 'Offline Exams',
      body: SecureApiService().isTeacher
          ? const _TeacherExamView()
          : const _StudentExamView(),
    );
  }
}

// ---------------------------------------------------------------------------
// Paper helpers

List<OfflineExamQuestion> _questionBankPick(int count) {
  const subjects = ['physics', 'chemistry', 'maths', 'biology'];
  final questions = <OfflineExamQuestion>[];
  for (final subject in subjects) {
    for (final q in QuestionBankLocal.getQuestions(subject, count: 4)) {
      questions.add(OfflineExamQuestion(
        question: q['q'] as String? ?? '',
        options: (q['options'] as List? ?? []).map((o) => o.toString()).toList(),
        correctIndex: q['correct'] as int? ?? 0,
      ));
    }
    if (questions.length >= count) break;
  }
  return questions.take(count).toList();
}

// ---------------------------------------------------------------------------
// Teacher view

class _TeacherExamView extends StatefulWidget {
  const _TeacherExamView();

  @override
  State<_TeacherExamView> createState() => _TeacherExamViewState();
}

class _TeacherExamViewState extends State<_TeacherExamView> {
  final OfflineExamServer _server = OfflineExamServer();
  final OfflineExamBleHost _bleHost = OfflineExamBleHost();

  OfflineExamPaper? _paper;
  int _questionCount = 8;
  String? _error;
  List<String> _localIps = [];
  final List<OfflineExamResult> _results = [];
  Timer? _pollTimer;
  StreamSubscription<OfflineExamResult>? _bleSub;

  @override
  void initState() {
    super.initState();
    _discoverIps();
    _bleSub = _bleHost.onSubmit.listen((result) {
      if (!mounted) return;
      setState(() => _results.add(result));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bleSub?.cancel();
    _server.stop();
    _bleHost.stop();
    super.dispose();
  }

  Future<void> _discoverIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      if (!mounted) return;
      setState(() {
        _localIps = interfaces
            .expand((i) => i.addresses)
            .where((a) => a.type == InternetAddressType.IPv4)
            .map((a) => a.address)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _buildPaper() async {
    setState(() => _error = null);
    final questions = _questionBankPick(_questionCount);
    if (questions.isEmpty) {
      setState(() => _error = 'Question bank is empty.');
      return;
    }
    setState(() {
      _paper = OfflineExamPaper(
        id: 'exam-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Class Test',
        durationMinutes: 10,
        questions: questions,
      );
    });
  }

  Future<void> _startHosting() async {
    final paper = _paper;
    if (paper == null) return;
    setState(() => _error = null);
    try {
      await _server.start(paper);
    } catch (_) {
      setState(() =>
          _error = 'Could not start the hotspot server on port 8787.');
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    if (mounted) setState(() {});
  }

  Future<void> _startBle() async {
    final paper = _paper;
    if (paper == null) return;
    setState(() => _error = null);
    try {
      await _bleHost.start(paper);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _refresh() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      try {
        final request =
            await client.getUrl(Uri.parse('http://127.0.0.1:8787/results'));
        final response = await request.close();
        final body = await utf8.decodeStream(response);
        final payload = Map<String, dynamic>.from(jsonDecode(body));
        final fresh = (payload['results'] as List? ?? [])
            .map((r) => OfflineExamResult.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList();
        if (!mounted) return;
        final changed = fresh.length != _results.length ||
            (fresh.isNotEmpty &&
                _results.isNotEmpty &&
                fresh.last.submittedAt != _results.last.submittedAt);
        if (changed) {
          setState(() {
            _results
              ..clear()
              ..addAll(fresh);
          });
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpace.pageH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSetupCard(context),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              _error!,
              style: context.text.bodySmall?.copyWith(color: context.tokens.statusAbsent),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          if (_paper != null) _buildPaperCard(context),
          const SizedBox(height: AppSpace.lg),
          _buildResultsCard(context),
        ],
      ),
    );
  }

  Widget _buildSetupCard(BuildContext ctx) {
    final t = ctx.tokens;
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Host an exam', style: ctx.text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Works with zero internet. Students connect over your phone hotspot '
            'or Bluetooth and the app grades everything locally.',
            style: ctx.text.bodySmall?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.md),
          Text('Questions', style: ctx.text.labelMedium?.copyWith(color: t.inkMuted)),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [4, 8, 12, 16].map((n) {
              final selected = _questionCount == n;
              return ChoiceChip(
                label: Text('$n'),
                selected: selected,
                labelStyle: ctx.text.labelSmall?.copyWith(
                  color: selected ? t.onPrimary : t.ink,
                ),
                selectedColor: t.primary,
                backgroundColor: t.surfaceAlt,
                side: BorderSide(color: selected ? t.primary : t.border),
                onSelected: (_) => setState(() => _questionCount = n),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpace.md),
          NexusButton(
            label: _paper == null ? 'Build paper' : 'Rebuild paper',
            icon: Icons.description_outlined,
            onPressed: _buildPaper,
          ),
          const SizedBox(height: AppSpace.sm),
          NexusButton(
            label: 'Host on hotspot',
            icon: Icons.wifi_tethering,
            onPressed: _server.isRunning ? null : _startHosting,
          ),
          const SizedBox(height: AppSpace.sm),
          NexusButton(
            label: _bleHost.isAdvertising
                ? 'Bluetooth ON — tap to stop'
                : 'Share over Bluetooth',
            icon: Icons.bluetooth,
            variant: NexusButtonVariant.secondary,
            onPressed: () async {
              if (_bleHost.isAdvertising) {
                await _bleHost.stop();
                if (mounted) setState(() {});
              } else {
                await _startBle();
              }
            },
          ),
          if (_server.isRunning || _bleHost.isAdvertising) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: t.statusPresent.withValues(alpha: 0.15),
                borderRadius: AppRadius.brMd,
                border: Border.all(color: t.statusPresent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radio_button_checked, color: t.statusPresent, size: 18),
                      const SizedBox(width: AppSpace.xs),
                      Text(
                        'Students can join now',
                        style: ctx.text.labelLarge?.copyWith(
                          color: t.statusPresent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'How to run: turn on your phone hotspot (or Bluetooth), then '
                    'students open Nexus Edu → Offline Exams → Join, and pick your '
                    'phone. Results appear below as they submit.',
                    style: ctx.text.bodySmall?.copyWith(color: t.inkMuted),
                  ),
                  if (_server.isRunning) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'Hotspot address: ${_localIps.isNotEmpty ? _localIps.join(', ') : 'unknown (check your hotspot IP)'} : 8787',
                      style: ctx.text.labelMedium?.copyWith(color: t.primary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaperCard(BuildContext ctx) {
    final t = ctx.tokens;
    final paper = _paper!;
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, color: t.primary, size: 20),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Text(
                  paper.title,
                  style: ctx.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${paper.questions.length} Q · ${paper.durationMinutes} min',
                style: ctx.text.labelSmall?.copyWith(color: t.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Sample question: ${paper.questions.first.question}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ctx.text.bodySmall?.copyWith(color: t.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard(BuildContext ctx) {
    final t = ctx.tokens;
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: t.secondary, size: 20),
              const SizedBox(width: AppSpace.xs),
              Text(
                'Results (${_results.length})',
                style: ctx.text.titleSmall?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          if (_results.isEmpty)
            Text(
              'No submissions yet. Tell students to connect and start.',
              style: ctx.text.bodySmall?.copyWith(color: t.inkMuted),
            )
          else
            for (final result in _results)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: t.surfaceAlt,
                      child: Text(
                        result.studentName.isEmpty
                            ? '?'
                            : result.studentName[0].toUpperCase(),
                        style: ctx.text.labelSmall?.copyWith(color: t.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        result.studentName,
                        style: ctx.text.bodyMedium?.copyWith(color: t.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${result.score}/${result.total}',
                      style: ctx.text.titleSmall?.copyWith(
                        color: result.percent >= 60 ? t.statusPresent : t.statusLate,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Student view

class _StudentExamView extends StatefulWidget {
  const _StudentExamView();

  @override
  State<_StudentExamView> createState() => _StudentExamViewState();
}

class _StudentExamViewState extends State<_StudentExamView> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '8787');

  final List<OfflineExamResult> _attempts = [];

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_exam_attempts');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _attempts
          ..clear()
          ..addAll(list.map(
              (e) => OfflineExamResult.fromJson(Map<String, dynamic>.from(e as Map))));
      });
    }
  }

  Future<void> _saveAttempt(OfflineExamResult attempt) async {
    setState(() => _attempts.insert(0, attempt));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline_exam_attempts',
      jsonEncode(_attempts.map((a) => a.toJson()).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(icon: Icon(Icons.wifi, color: t.inkMuted), text: 'Hotspot'),
              Tab(icon: Icon(Icons.bluetooth, color: t.inkMuted), text: 'Bluetooth'),
              Tab(icon: Icon(Icons.history, color: t.inkMuted), text: 'Attempts'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildHotspotTab(context),
                _buildBleTab(context),
                _buildAttemptsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotTab(BuildContext ctx) {
    final t = ctx.tokens;
    return SingleChildScrollView(
      padding: AppSpace.pageH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NexusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join a hotspot exam', style: ctx.text.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Ask your teacher for the hotspot address shown on their '
                  'screen (example: 192.168.0.1).',
                  style: ctx.text.bodySmall?.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: AppSpace.md),
                NexusTextField(
                  controller: _hostController,
                  label: 'Teacher hotspot IP',
                  hint: '192.168.0.1',
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.lan_outlined,
                ),
                const SizedBox(height: AppSpace.sm),
                NexusTextField(
                  controller: _portController,
                  label: 'Port',
                  keyboardType: TextInputType.number,
                  icon: Icons.numbers,
                ),
                const SizedBox(height: AppSpace.md),
                NexusButton(
                  label: 'Fetch exam',
                  icon: Icons.download_outlined,
                  onPressed: _joinHotspot,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Tip: everything works offline — the teacher is the "server" '
            'and this phone is the "client".',
            style: ctx.text.bodySmall?.copyWith(color: t.inkFaint),
          ),
        ],
      ),
    );
  }

  Future<void> _joinHotspot() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8787;
    if (host.isEmpty) return;

    final client = OfflineExamClient();
    final paper = await client.fetchPaper(host, port);
    if (!mounted) return;
    if (paper == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach the teacher. Check the IP and hotspot.')),
      );
      return;
    }
    final submitted = await _runExam(paper, transport: 'hotspot');
    if (submitted == null || !mounted) return;
    final result = await client.submit(
      host,
      port,
      SecureApiService().userName,
      submitted,
    );
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answers saved locally, but the teacher '
            'could not be reached to submit. Try again while still on the hotspot.')),
      );
      return;
    }
    final attempt = OfflineExamResult(
      studentName: SecureApiService().userName,
      answers: submitted,
      score: result.$1,
      total: result.$2,
      submittedAt: DateTime.now(),
    );
    await _saveAttempt(attempt);
    // Queue the score so the student's history reaches the backend even when
    // the teacher never came back online; flushed on reconnect.
    await SyncQueueService.instance.enqueue('quiz_result', {
      'title': 'Offline exam · ${paper.title}',
      'score': attempt.score,
      'total': attempt.total,
      'percent': attempt.percent,
      'takenAt': attempt.submittedAt.toUtc().toIso8601String(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submitted! You scored ${attempt.score}/${attempt.total}.')),
      );
    }
  }

  Widget _buildBleTab(BuildContext ctx) {
    final t = ctx.tokens;
    return SingleChildScrollView(
      padding: AppSpace.pageH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NexusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join over Bluetooth', style: ctx.text.titleMedium),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Works on old phones without WiFi. Your teacher taps '
                  '"Share over Bluetooth" and you pick their phone here.',
                  style: ctx.text.bodySmall?.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: AppSpace.md),
                NexusButton(
                  label: 'Find teacher & download exam',
                  icon: Icons.bluetooth_searching,
                  onPressed: _joinBle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinBle() async {
    final client = OfflineExamBleClient();
    final paper = await client.downloadPaper();
    if (!mounted) return;
    if (paper == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exam found nearby. Make sure '
            'Bluetooth is on and the teacher is advertising.')),
      );
      return;
    }
    final submitted = await _runExam(paper, transport: 'bluetooth');
    if (submitted == null || !mounted) return;
    final result = await client.submitAnswers(
      SecureApiService().userName,
      submitted,
    );
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send answers. Stay near the '
            'teacher and try again.')),
      );
      return;
    }
    final attempt = OfflineExamResult(
      studentName: SecureApiService().userName,
      answers: submitted,
      score: result.$1,
      total: result.$2,
      submittedAt: DateTime.now(),
    );
    await _saveAttempt(attempt);
    await SyncQueueService.instance.enqueue('quiz_result', {
      'title': 'Offline exam · ${paper.title}',
      'score': attempt.score,
      'total': attempt.total,
      'percent': attempt.percent,
      'takenAt': attempt.submittedAt.toUtc().toIso8601String(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submitted! You scored ${attempt.score}/${attempt.total}.')),
      );
    }
  }

  /// Runs the shared offline quiz UI; returns the chosen answers
  /// (null if the student backed out).
  Future<List<int?>?> _runExam(
    OfflineExamPaper paper, {
    required String transport,
  }) {
    return Navigator.of(context).push<List<int?>>(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: AppTheme.darkTheme,
          child: _ExamRunner(paper: paper),
        ),
      ),
    );
  }

  Widget _buildAttemptsTab(BuildContext ctx) {
    final t = ctx.tokens;
    return ListView(
      padding: AppSpace.pageH,
      children: [
        if (_attempts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xl),
            child: Column(
              children: [
                Icon(Icons.history, size: 40, color: t.inkFaint),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'No attempts yet. Join a hotspot or Bluetooth exam.',
                  textAlign: TextAlign.center,
                  style: ctx.text.bodySmall?.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          )
        else
          for (final attempt in _attempts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: NexusCard(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: t.primary.withValues(alpha: 0.2),
                      child: Text(
                        '${attempt.percent}%',
                        style: ctx.text.labelSmall?.copyWith(
                          color: t.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${attempt.score}/${attempt.total} correct',
                            style: ctx.text.titleSmall?.copyWith(color: t.ink),
                          ),
                          Text(
                            _formatTime(attempt.submittedAt),
                            style: ctx.text.labelSmall?.copyWith(color: t.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      attempt.percent >= 60
                          ? Icons.check_circle
                          : Icons.refresh,
                      color: attempt.percent >= 60
                          ? t.statusPresent
                          : t.statusLate,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} · $h:$m';
  }
}

// ---------------------------------------------------------------------------
// Shared offline quiz runner

class _ExamRunner extends StatefulWidget {
  const _ExamRunner({required this.paper});

  final OfflineExamPaper paper;

  @override
  State<_ExamRunner> createState() => _ExamRunnerState();
}

class _ExamRunnerState extends State<_ExamRunner> {
  int _index = 0;
  final List<int?> _answers = [];
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = Duration(minutes: widget.paper.durationMinutes);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 1) {
        _timer?.cancel();
        _finish();
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (mounted) Navigator.of(context).pop(_answers);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final questions = widget.paper.questions;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam')),
        body: const Center(child: Text('This exam has no questions.')),
      );
    }
    final question = questions[_index];
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.paper.title,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
            Text(
              'Question ${_index + 1} of ${questions.length}',
              style: context.text.labelSmall?.copyWith(color: t.inkMuted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.md),
            child: Center(
              child: Text(
                '${minutes.toString().padLeft(2, '0')}:'
                '${seconds.toString().padLeft(2, '0')}',
                style: context.text.titleSmall?.copyWith(
                  color: _remaining.inMinutes < 1
                      ? t.statusAbsent
                      : t.statusPresent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpace.pageH,
        children: [
          NexusCard(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Text(
              question.question,
              style: context.text.titleMedium?.copyWith(
                color: t.ink,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          for (var i = 0; i < question.options.length; i++) ...[
            _optionTile(context, i, question.options[i]),
            const SizedBox(height: AppSpace.xs),
          ],
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              if (_index > 0) ...[
                Expanded(
                  child: NexusButton(
                    label: 'Back',
                    icon: Icons.chevron_left,
                    variant: NexusButtonVariant.secondary,
                    onPressed: () => setState(() => _index--),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
              ],
              Expanded(
                child: NexusButton(
                  label: _index == questions.length - 1
                      ? 'Submit'
                      : 'Next',
                  icon: _index == questions.length - 1
                      ? Icons.send
                      : Icons.chevron_right,
                  onPressed: () {
                    if (_index == questions.length - 1) {
                      _finish();
                    } else {
                      setState(() => _index++);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
        ],
      ),
    );
  }

  Widget _optionTile(BuildContext ctx, int index, String option) {
    final t = ctx.tokens;
    final selected = _answers.length > _index && _answers[_index] == index;
    return InkWell(
      borderRadius: AppRadius.brMd,
      onTap: () => setState(() {
        if (_answers.length <= _index) {
          _answers.add(index);
        } else {
          _answers[_index] = index;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: selected ? t.primary.withValues(alpha: 0.15) : t.surfaceAlt,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: selected ? t.primary : t.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? t.primary : t.inkFaint,
              size: 20,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                option,
                style: ctx.text.bodyMedium?.copyWith(
                  color: selected ? t.ink : t.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
