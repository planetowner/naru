import 'package:flutter/material.dart';

import '../app_control_style.dart';

final class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.autofillHints,
    this.onChanged,
    this.onTap,
    this.onFieldSubmitted,
    this.validator,
    this.autofocus = false,
    this.inputKey,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enabled;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final Key? inputKey;

  @override
  Widget build(BuildContext context) {
    final TextPainter metrics = TextPainter(
      text: const TextSpan(text: ' ', style: AppControlStyle.inputText),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    // dense 입력은 최소 제약보다 글자·패딩으로 테두리 높이를 정하므로 Auto 행간에 맞춰 계산해요.
    final double verticalPadding =
        ((AppControlStyle.height - metrics.preferredLineHeight) / 2).clamp(
          0.0,
          AppControlStyle.height,
        );
    metrics.dispose();
    final Widget input = TextFormField(
      key: inputKey,
      autofocus: autofocus,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enabled: enabled,
      readOnly: readOnly,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onTap: onTap,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: AppControlStyle.inputText,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        // 여러 줄 메시지 입력에는 이 높이를 강제하지 않아요.
        constraints: const BoxConstraints(minHeight: AppControlStyle.height),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppControlStyle.horizontalInset,
          vertical: verticalPadding,
        ),
        hintText: hintText,
        prefixIcon: _icon(prefixIcon),
        suffixIcon: _icon(suffixIcon),
      ).applyDefaults(AppControlStyle.inputTheme),
    );
    if (labelText == null) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(labelText!, style: AppControlStyle.inputLabel),
        const SizedBox(height: 10),
        input,
      ],
    );
  }

  // Material 아이콘 버튼의 기본 48 높이가 입력 규격 46을 늘리지 않게 해요.
  Widget? _icon(Widget? icon) => icon == null
      ? null
      : SizedBox.square(dimension: AppControlStyle.height, child: icon);
}
