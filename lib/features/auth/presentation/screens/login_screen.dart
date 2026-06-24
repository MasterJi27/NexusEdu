import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/shared/constants/app_constants.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  String _selectedRole = 'Student';
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    final success = _isLogin
        ? await notifier.login(_emailController.text, _passwordController.text)
        : await notifier.signup(_nameController.text, _emailController.text, _passwordController.text);

    if (success && mounted) {
      context.go(_selectedRole == 'Teacher' ? '/teacher-dashboard'
          : _selectedRole == 'Parent' ? '/parental-report'
          : '/dashboard');
    } else if (mounted) {
      final error = ref.read(authProvider).error ?? 'Authentication failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _googleLogin() async {
    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.login('google_user@gmail.com', '123456');
    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [Color(0xFF0F0F1A), Color(0xFF1A0F2E), AppColors.background],
                    begin: Alignment.topLeft,
                    end: Alignment(0.5 + _bgController.value, 1.0),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: -100, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.purple.withAlpha(40),
                boxShadow: [BoxShadow(color: AppColors.purple.withAlpha(20), blurRadius: 100)],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: 0, end: 100, duration: 6.seconds),
          ),
          Positioned(
            bottom: -150, right: -100,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan.withAlpha(30),
                boxShadow: [BoxShadow(color: AppColors.cyan.withAlpha(20), blurRadius: 100)],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -100, duration: 8.seconds),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 40, spreadRadius: -5)],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.purple.withAlpha(30),
                                border: Border.all(color: AppColors.cyan.withAlpha(50)),
                              ),
                              child: const Icon(Icons.rocket_launch, size: 50, color: AppColors.cyan),
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.95, end: 1.05, duration: 2.seconds),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(80),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withAlpha(20)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildRoleTab('Student', Icons.school),
                                  _buildRoleTab('Teacher', Icons.menu_book),
                                  _buildRoleTab('Parent', Icons.family_restroom),
                                ],
                              ),
                            ).animate().fadeIn(delay: 100.ms),
                            const SizedBox(height: 24),
                            Text(
                              _isLogin ? 'Welcome Back' : 'Create Account',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                            ).animate(target: _isLogin ? 0 : 1).fadeIn(),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin ? 'Log in to your Nexus account' : 'Join the future of education',
                              style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 14),
                            ),
                            const SizedBox(height: 32),
                            AnimatedSize(
                              duration: AppDurations.normal,
                              curve: Curves.easeInOutBack,
                              child: Column(
                                children: [
                                  if (!_isLogin)
                                    NexusTextField(
                                      controller: _nameController,
                                      hintText: 'Full Name',
                                      icon: Icons.person_outline,
                                      validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                                    ).animate().slideX(begin: -0.2).fadeIn(),
                                  if (!_isLogin) const SizedBox(height: 16),
                                  NexusTextField(
                                    controller: _emailController,
                                    hintText: 'Email Address',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                                  ).animate().slideX(begin: -0.2, delay: 100.ms).fadeIn(),
                                  const SizedBox(height: 16),
                                  NexusTextField(
                                    controller: _passwordController,
                                    hintText: 'Password',
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                                  ).animate().slideX(begin: -0.2, delay: 200.ms).fadeIn(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            NexusButton(
                              label: _isLogin ? 'Log In' : 'Sign Up',
                              isLoading: authState.isLoading,
                              onPressed: _submit,
                            ).animate().scale(delay: 300.ms),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white.withAlpha(50))),
                                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12))),
                                Expanded(child: Divider(color: Colors.white.withAlpha(50))),
                              ],
                            ).animate().fadeIn(delay: 400.ms),
                            const SizedBox(height: 20),
                            _buildSocialButton(
                              icon: Icons.g_mobiledata, label: 'Continue with Google',
                              color: Colors.white, onTap: authState.isLoading ? () {} : _googleLogin,
                            ).animate().slideY(begin: 0.2, delay: 500.ms).fadeIn(),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: authState.isLoading ? null : () => setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin ? "Don't have an account? Sign Up" : 'Already have an account? Log In',
                                style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ).animate().fadeIn(delay: 600.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().slideY(begin: 0.1, duration: 800.ms, curve: Curves.easeOutQuart).fadeIn(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTab(String role, IconData icon) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: AppDurations.normal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyan.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.cyan : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.cyan : Colors.white54, size: 16),
            if (isSelected) ...[const SizedBox(width: 6), Text(role, style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12))],
          ],
        ),
      ),
    );
  }
}
