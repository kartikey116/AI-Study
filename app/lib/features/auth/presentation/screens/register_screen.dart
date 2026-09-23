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
  void initState() {
    super.initState();
    // Clear any stale error/loading state from a previous attempt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authProvider.notifier).resetForScreen();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

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
      setState(() => _nameError = 'Name is required');
      isValid = false;
    }

    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      isValid = false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      isValid = false;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      isValid = false;
    } else if (password.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
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
        lastName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthState.loading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: isLoading
              ? null // Disable back button while loading
              : () {
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

              // Error banner — only shown when status is error
              if (authState.status == AuthState.error && authState.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
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
                      // Tap X to dismiss the error banner manually
                      GestureDetector(
                        onTap: () => ref.read(authProvider.notifier).clearError(),
                        child: const Icon(Icons.close, color: Colors.red, size: 18),
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
                enabled: !isLoading,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                  if (authState.status == AuthState.error) {
                    ref.read(authProvider.notifier).clearError();
                  }
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
                enabled: !isLoading,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                  if (authState.status == AuthState.error) {
                    ref.read(authProvider.notifier).clearError();
                  }
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
                enabled: !isLoading,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                onChanged: (_) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                  if (authState.status == AuthState.error) {
                    ref.read(authProvider.notifier).clearError();
                  }
                },
                onSubmitted: (_) => isLoading ? null : _validateAndSubmit(),
              ),

              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                text: isLoading ? 'Signing up...' : 'Sign Up',
                // null disables the button properly (greyed out) while loading
                onPressed: isLoading ? null : _validateAndSubmit,
              ),

              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: AppTypography.bodyMedium),
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () {
                            ref.read(authProvider.notifier).clearError();
                            // Use pop() not go('/login') — avoids pushing a duplicate login
                            // route on top of the existing one in the stack.
                            context.pop();
                          },
                    child: Text(
                      'Log In',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isLoading ? AppColors.textMuted : AppColors.primary,
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
