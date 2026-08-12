import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// The app's text input. Themed entirely through [ThemeData.inputDecorationTheme]
/// in `app_theme.dart`, so this widget only adds the label/helper/error slots
/// feature screens keep re-declaring by hand.
///
/// Replaces an implementation that hardcoded `Colors.black.withAlpha(120)` fill,
/// a coloured shadow, and a cyan icon tint outside the token system.
class NexusTextField extends StatelessWidget {
  const NexusTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: context.text.labelMedium),
          const SizedBox(height: AppSpace.xs),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: isPassword ? 1 : maxLines,
          minLines: minLines,
          enabled: enabled,
          autofocus: autofocus,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            prefixIcon: icon == null ? null : Icon(icon, color: t.inkMuted),
          ),
        ),
      ],
    );
  }
}
