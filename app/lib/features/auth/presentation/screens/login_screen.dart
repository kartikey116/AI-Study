import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool isValid = true;

    if (email.isEmpty) {
      _emailError = 'Email is required';
      isValid = false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _emailError = 'Please enter a valid email address';
      isValid = false;
    }

    if (password.isEmpty) {
      _passwordError = 'Password is required';
      isValid = false;
    }

    if (isValid) {
      ref.read(authProvider.notifier).clearError();
      ref.read(authProvider.notifier).login(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            ref.read(authProvider.notifier).clearError();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Welcome back!', style: AppTypography.heading1),
              const SizedBox(height: AppSpacing.sm),
              Text('Ready to study today?', style: AppTypography.bodyLarge),
              const SizedBox(height: AppSpacing.xxl),
              
              if (authState.status == AuthState.error && authState.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: AppTypography.bodyMedium.copyWith(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                errorText: _emailError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
                enabled: authState.status != AuthState.loading,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                  ref.read(authProvider.notifier).clearError();
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                obscureText: _obscurePassword,
                errorText: _passwordError,
                textInputAction: TextInputAction.done,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                enabled: authState.status != AuthState.loading,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                onChanged: (_) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                  ref.read(authProvider.notifier).clearError();
                },
                onSubmitted: (_) => _validateAndSubmit(),
              ),
              
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                text: authState.status == AuthState.loading ? 'Logging in...' : 'Log In',
                onPressed: authState.status == AuthState.loading ? () {} : _validateAndSubmit,
              ),
              
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: AppTypography.bodyMedium),
                  GestureDetector(
                    onTap: () {
                      ref.read(authProvider.notifier).clearError();
                      context.go('/register');
                    },
                    child: Text(
                      'Sign Up',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
