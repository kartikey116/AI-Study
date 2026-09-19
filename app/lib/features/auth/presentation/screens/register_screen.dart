import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create Account', style: AppTypography.heading1),
              const SizedBox(height: AppSpacing.sm),
              Text('Start your personalized learning journey.', style: AppTypography.bodyLarge),
              const SizedBox(height: AppSpacing.xxl),
              
              AppTextField(
                controller: _nameController,
                label: 'Name',
                hint: 'Enter your full name',
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(authState.errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                text: authState.status == AuthState.loading ? 'Signing up...' : 'Sign Up',
                onPressed: authState.status == AuthState.loading
                  ? () {}
                  : () {
                      final nameParts = _nameController.text.trim().split(' ');
                      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
                      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
                      ref.read(authProvider.notifier).register(
                        _emailController.text, 
                        _passwordController.text,
                        firstName,
                        lastName
                      );
                  },
              ),
              
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account? ", style: AppTypography.bodyMedium),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text(
                      'Log In',
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
