import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscureText;
  final TextEditingController? controller;
  final Widget? prefixIcon;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.controller,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}
