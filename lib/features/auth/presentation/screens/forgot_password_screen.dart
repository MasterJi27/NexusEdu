import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    setState(() { _isLoading = true; _error = null; });
    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty) {
      setState(() { _isLoading = false; _error = 'Please enter your email'; });
      return;
    }

    if (!_emailSent) {
      await Future.delayed(const Duration(seconds: 1));
      setState(() { _isLoading = false; _emailSent = true; });
      return;
    }

    if (newPassword.isEmpty || confirm.isEmpty) {
      setState(() { _isLoading = false; _error = 'Please fill all fields'; });
      return;
    }
    if (newPassword != confirm) {
      setState(() { _isLoading = false; _error = 'Passwords do not match'; });
      return;
    }
    if (newPassword.length < 6) {
      setState(() { _isLoading = false; _error = 'Password must be at least 6 characters'; });
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('user_email');

    if (savedEmail == email) {
      await prefs.setString('user_password', newPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successful!'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } else {
      setState(() { _isLoading = false; _error = 'Email not found. Please sign up first.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 20),
              Icon(Icons.lock_reset, color: const Color(0xFF7C5CFF), size: 64),
              const SizedBox(height: 24),
              const Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                _emailSent ? 'Enter your new password' : 'Enter your email to reset password',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              ),
              const SizedBox(height: 40),
              if (!_emailSent) ...[
                _buildTextField(_emailController, 'Email', Icons.email_outlined),
              ] else ...[
                _buildTextField(_newPasswordController, 'New Password', Icons.lock_outlined, isPassword: true),
                const SizedBox(height: 16),
                _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock_outlined, isPassword: true),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _emailSent ? 'Reset Password' : 'Send Reset Link',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: Icon(icon, color: const Color(0xFF7C5CFF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
