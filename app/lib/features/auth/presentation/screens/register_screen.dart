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
  
  bool _obscurePassword = true;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool isValid = true;

    if (name.isEmpty) {
      _nameError = 'Name is required';
      isValid = false;
    }

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
    } else if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters';
      isValid = false;
    }

    if (isValid) {
      ref.read(authProvider.notifier).clearError();
      final nameParts = name.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      ref.read(authProvider.notifier).register(
        email, 
        password,
        firstName,
        lastName
      );
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
              Text('Create Account', style: AppTypography.heading1),
              const SizedBox(height: AppSpacing.sm),
              Text('Start your personalized learning journey.', style: AppTypography.bodyLarge),
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
                controller: _nameController,
                label: 'Name',
                hint: 'Enter your full name',
                errorText: _nameError,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted),
                enabled: authState.status != AuthState.loading,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                  ref.read(authProvider.notifier).clearError();
                },
              ),
              const SizedBox(height: AppSpacing.lg),
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
                hint: 'Create a password',
                obscureText: _obscurePassword,
                errorText: _passwordError,
                helperText: 'Must be at least 8 characters',
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
                text: authState.status == AuthState.loading ? 'Signing up...' : 'Sign Up',
                onPressed: authState.status == AuthState.loading ? () {} : _validateAndSubmit,
              ),
              
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account? ", style: AppTypography.bodyMedium),
                  GestureDetector(
                    onTap: () {
                      ref.read(authProvider.notifier).clearError();
                      context.go('/login');
                    },
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
