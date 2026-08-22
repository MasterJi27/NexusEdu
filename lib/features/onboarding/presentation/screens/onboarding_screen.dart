import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/app_theme.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_filter_chips.dart';

const List<String> _boards = ['CBSE', 'ICSE', 'State Board', 'IB', 'Other'];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String? _selectedGrade;
  String? _selectedBoard;
  final Set<String> _selectedSubjects = {};

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return _selectedGrade != null;
      case 1:
        return _selectedBoard != null;
      default:
        return true;
    }
  }

  Future<void> _saveProfile({String? role}) async {
    if (_selectedGrade != null) {
      await LearnerProfileService.setSelectedClass(_selectedGrade);
    }
    if (_selectedBoard != null) {
      await LearnerProfileService.setBoard(_selectedBoard!);
    }
    await LearnerProfileService.setSubjects(_selectedSubjects.toList());
    await LearnerProfileService.markOnboardingProfileDone();
    await AuthState.instance.markOnboardingDone();

    if (SecureApiService().isLoggedIn) {
      await SecureApiService().updateProfile(
        gradeLevel: _selectedGrade,
        schoolBoard: _selectedBoard,
        strongSubjects: _selectedSubjects.toList(),
        role: role,
      );
    }
  }

  void _next() {
    if (!_canProceed) return;
    if (_currentPage == 2) {
      _saveProfile();
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjectOptions = _selectedGrade != null
        ? LearningCatalog.subjectsFor(
            _selectedGrade!,
          ).map((s) => s.name).toList()
        : const <String>[
            'Physics',
            'Chemistry',
            'Mathematics',
            'Biology',
            'English',
          ];

    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (context) {
          final t = context.tokens;
          return Scaffold(
            backgroundColor: t.page,
            body: Stack(
              children: [
                PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: [
                    _buildChoiceStep(
                      context,
                      title: 'What\'s your grade?',
                      subtitle:
                          'This tailors your shorts, quizzes and NCERT solutions.',
                      options: LearningCatalog.classes,
                      selected: _selectedGrade == null
                          ? const {}
                          : {_selectedGrade!},
                      onSelect: (value) =>
                          setState(() => _selectedGrade = value),
                    ),
                    _buildChoiceStep(
                      context,
                      title: 'Which board do you follow?',
                      subtitle: 'We\'ll match content to your curriculum.',
                      options: _boards,
                      selected: _selectedBoard == null
                          ? const {}
                          : {_selectedBoard!},
                      onSelect: (value) =>
                          setState(() => _selectedBoard = value),
                    ),
                    _buildChoiceStep(
                      context,
                      title: 'Pick subjects you want to focus on',
                      subtitle:
                          'Optional — you can change this anytime in Profile.',
                      options: subjectOptions,
                      selected: _selectedSubjects,
                      multiSelect: true,
                      onSelect: (value) => setState(() {
                        if (_selectedSubjects.contains(value)) {
                          _selectedSubjects.remove(value);
                        } else {
                          _selectedSubjects.add(value);
                        }
                      }),
                    ),
                    _buildAuthPage(context),
                  ],
                ),

                if (_currentPage < 3)
                  Positioned(
                    bottom: 50,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpace.xxs,
                          ),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? t.ink : t.inkFaint,
                            borderRadius: AppRadius.brPill,
                          ),
                        );
                      }),
                    ),
                  ),

                if (_currentPage < 3)
                  Positioned(
                    bottom: 36,
                    right: 24,
                    child: FloatingActionButton(
                      backgroundColor: _canProceed ? t.primary : t.surfaceAlt,
                      foregroundColor: _canProceed ? t.onPrimary : t.inkFaint,
                      onPressed: _canProceed ? _next : null,
                      child: const Icon(Icons.arrow_forward_ios),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChoiceStep(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<String> onSelect,
    bool multiSelect = false,
  }) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.xl,
        MediaQuery.paddingOf(context).top + AppSpace.xxl,
        AppSpace.xl,
        140,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.displaySmall?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            subtitle,
            style: context.text.bodyMedium?.copyWith(
              color: t.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Expanded(
            child: SingleChildScrollView(
              child: multiSelect
                  ? NexusFilterChips<String>(
                      options: options,
                      selected: null,
                      multiSelected: selected.cast<String>(),
                      onSelected: onSelect,
                    )
                  : NexusFilterChips<String>(
                      options: options,
                      selected: selected.isEmpty ? null : selected.first,
                      onSelected: onSelect,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPage(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub, size: 100, color: t.primary),
          const SizedBox(height: AppSpace.xl),
          Text(
            'Welcome to NexusEdu',
            style: context.text.displaySmall?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Who are you?',
            style: context.text.titleMedium?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.xl),
          _buildRoleCard(
            context,
            title: 'Student',
            subtitle: 'Personalized learning & AI tutor',
            icon: Icons.school,
            route: '/dashboard',
            role: 'student',
          ),
          const SizedBox(height: AppSpace.md),
          _buildRoleCard(
            context,
            title: 'Parent',
            subtitle: 'Track your child\'s progress',
            icon: Icons.family_restroom,
            route: '/parent-dashboard',
            role: 'parent',
          ),
          const SizedBox(height: AppSpace.md),
          _buildRoleCard(
            context,
            title: 'Teacher',
            subtitle: 'Manage classes & assignments',
            icon: Icons.co_present,
            route: '/teacher-dashboard',
            role: 'teacher',
          ),
          const SizedBox(height: AppSpace.xl),
          NexusButton(
            label: 'Sign in with an account',
            icon: Icons.login,
            variant: NexusButtonVariant.secondary,
            fullWidth: true,
            onPressed: () => context.go('/login'),
          ),
          const SizedBox(height: AppSpace.xs),
          TextButton(
            onPressed: () async {
              await _saveProfile();
              if (context.mounted) {
                context.go(AuthState.instance.roleHome);
              }
            },
            child: Text(
              'Continue as Guest',
              style: context.text.labelLarge?.copyWith(color: t.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    required String role,
  }) {
    final t = ctx.tokens;
    return NexusCard(
      background: t.primaryTint,
      borderColor: t.primaryTintBorder,
      onTap: () async {
        await _saveProfile(role: role);
        if (ctx.mounted) ctx.go(route);
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: t.surface.withValues(alpha: 0.55),
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon, color: t.primary, size: 36),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.headlineSmall?.copyWith(color: t.ink),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: t.inkFaint, size: 18),
        ],
      ),
    );
  }
}
