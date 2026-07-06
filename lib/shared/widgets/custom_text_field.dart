import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';


class SafeTraceTextField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final Function(String)? onChanged;

  const SafeTraceTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(
        color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
              )
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
