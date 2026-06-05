// ===============================
// FILE: lib/commons/widgets/custom_textfield.dart
// ===============================

import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? suffixSemanticLabel;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.suffixIcon,
    this.onSuffixTap,
    this.suffixSemanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon == null
              ? null
              : IconButton(
                  onPressed: onSuffixTap,
                  tooltip: suffixSemanticLabel,
                  icon: Icon(suffixIcon),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

class CustomPasswordTextField extends StatefulWidget {
  const CustomPasswordTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CustomPasswordTextField> createState() =>
      _CustomPasswordTextFieldState();
}

class _CustomPasswordTextFieldState extends State<CustomPasswordTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      hint: widget.hint,
      icon: widget.icon,
      obscure: _obscure,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      suffixIcon: _obscure
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
      suffixSemanticLabel: _obscure ? 'Hiển thị mật khẩu' : 'Ẩn mật khẩu',
      onSuffixTap: () => setState(() => _obscure = !_obscure),
    );
  }
}
