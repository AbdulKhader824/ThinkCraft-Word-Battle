import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// A large labelled text input with big rounded corners.
class GameTextField extends StatelessWidget {
  const GameTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.validator,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.words,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
      borderSide: BorderSide(color: color, width: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          validator: validator,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: false,
          style: AppText.input,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.input.copyWith(color: AppColors.navySoft),
            errorStyle: AppText.bodySmall.copyWith(color: AppColors.invalid),
            errorMaxLines: 2,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 18,
            ),
            enabledBorder: _border(AppColors.outline),
            focusedBorder: _border(AppColors.mintDeep),
            errorBorder: _border(AppColors.invalid),
            focusedErrorBorder: _border(AppColors.invalid),
          ),
        ),
      ],
    );
  }
}
