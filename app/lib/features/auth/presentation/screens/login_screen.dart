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

  @override
  void dispose() {
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
              const SizedBox(height: AppSpacing.xl),
              Text('Welcome back!', style: AppTypography.heading1),
              const SizedBox(height: AppSpacing.sm),
              Text('Ready to study today?', style: AppTypography.bodyLarge),
              const SizedBox(height: AppSpacing.xxl),
              
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
                hint: 'Enter your password',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(authState.errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                text: authState.status == AuthState.loading ? 'Logging in...' : 'Log In',
                onPressed: authState.status == AuthState.loading 
                  ? () {} 
                  : () {
                      ref.read(authProvider.notifier).login(_emailController.text, _passwordController.text);
                  },
              ),
              
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: AppTypography.bodyMedium),
                  GestureDetector(
                    onTap: () => context.go('/register'),
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
