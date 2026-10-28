import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/components.dart';
import '../data/auth_exception.dart';

typedef AuthSubmit =
    Future<void> Function({
      required String username,
      required String password,
      String? passwordConfirmation,
    });

final class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onSubmit,
    this.isSigningUp = false,
    super.key,
  });

  final AuthSubmit onSubmit;
  final bool isSigningUp;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

final class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isSubmitting = false;
  bool _didSubmit = false;
  String? _errorMessage;

  bool get _canSubmit =>
      !_isSubmitting &&
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      (!widget.isSigningUp || _confirmationController.text.isNotEmpty);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _handleInputChanged(String value) {
    setState(() => _errorMessage = null);
    // 첫 제출 뒤에는 원래 비밀번호를 바꿔도 확인 칸을 함께 검사해요.
    if (_didSubmit) _formKey.currentState!.validate();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    _didSubmit = true;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: widget.isSigningUp
            ? _confirmationController.text
            : null,
      );
      TextInput.finishAutofillContext();
      // 세션이 활성화된 뒤 가입 경로를 닫아 기존 채팅 홈으로 돌아가요.
      if (mounted && widget.isSigningUp) Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not complete the request. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openSignUp() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            AuthScreen(onSubmit: widget.onSubmit, isSigningUp: true),
      ),
    );
  }

  Widget _fields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      AppTextField(
        controller: _usernameController,
        labelText: 'Username',
        hintText: 'Username',
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: false,
        enabled: !_isSubmitting,
        autofillHints: [
          widget.isSigningUp
              ? AutofillHints.newUsername
              : AutofillHints.username,
        ],
        onChanged: _handleInputChanged,
        validator: (value) {
          final String username = value?.trim() ?? '';
          if (username.isEmpty) return 'Enter your username.';
          if (username.runes.length > 50) {
            return 'Use 50 characters or fewer.';
          }
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.space16),
      _PasswordField(
        controller: _passwordController,
        label: 'Password',
        enabled: !_isSubmitting,
        isNewPassword: widget.isSigningUp,
        textInputAction: widget.isSigningUp
            ? TextInputAction.next
            : TextInputAction.done,
        onChanged: _handleInputChanged,
        onSubmitted: widget.isSigningUp ? null : (_) => _submit(),
      ),
      if (widget.isSigningUp) ...[
        const SizedBox(height: AppSpacing.space16),
        _PasswordField(
          controller: _confirmationController,
          label: 'Confirm password',
          enabled: !_isSubmitting,
          isNewPassword: true,
          textInputAction: TextInputAction.done,
          onChanged: _handleInputChanged,
          onSubmitted: (_) => _submit(),
          validator: (value) => value == _passwordController.text
              ? null
              : 'Passwords do not match.',
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          if (widget.isSigningUp)
            AppNavigationBar(
              title: 'Sign up',
              backTooltip: 'Back',
              onBack: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    // 가운데 정렬 뒤에도 화면 높이를 유지하고, 키보드가 뜨면 스크롤해요.
                    constraints: BoxConstraints(
                      maxWidth: 480,
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.space24,
                        widget.isSigningUp ? AppSpacing.space24 : 0,
                        AppSpacing.space24,
                        widget.isSigningUp
                            ? AppSpacing.space24
                            : AppSpacing.space32,
                      ),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!widget.isSigningUp)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.space24,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const ExcludeSemantics(
                                            child: AppLogo(size: 96),
                                          ),
                                          const SizedBox(
                                            height: AppSpacing.space8,
                                          ),
                                          Text(
                                            'naru',
                                            style: AppTypography.display
                                                .copyWith(
                                                  color: AppColors.textPrimary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                _fields(),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: AppSpacing.space12),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                                if (widget.isSigningUp) const Spacer(),
                                const SizedBox(height: AppSpacing.space24),
                                AppButton(
                                  label: widget.isSigningUp
                                      ? 'Sign up'
                                      : 'Sign in',
                                  onPressed: _canSubmit ? _submit : null,
                                  isLoading: _isSubmitting,
                                ),
                                if (!widget.isSigningUp) ...[
                                  const SizedBox(height: AppSpacing.space12),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: AppSpacing.space4,
                                    children: [
                                      Text(
                                        'Don’t have an account?',
                                        style: AppTypography.body.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _openSignUp,
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          textStyle: AppTypography.button,
                                          minimumSize: Size.zero,
                                          padding: EdgeInsets.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Sign up'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// 비밀번호와 확인 입력은 가리기·자동 완성·아이콘 동작을 함께 관리해요.
final class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.isNewPassword,
    required this.textInputAction,
    required this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool isNewPassword;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

final class _PasswordFieldState extends State<_PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: widget.controller,
    labelText: widget.label,
    hintText: widget.label,
    enabled: widget.enabled,
    textInputAction: widget.textInputAction,
    obscureText: _obscured,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    onChanged: widget.onChanged,
    onFieldSubmitted: widget.onSubmitted,
    validator: widget.validator,
    suffixIcon: IconButton(
      tooltip: '${_obscured ? 'Show' : 'Hide'} ${widget.label.toLowerCase()}',
      onPressed: widget.enabled
          ? () => setState(() => _obscured = !_obscured)
          : null,
      icon: Icon(
        _obscured ? AppIcons.visibilityOff : AppIcons.visibility,
        size: 24,
      ),
    ),
  );
}
