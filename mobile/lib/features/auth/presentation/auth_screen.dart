import '../../../core/forms/text_validation.dart';
import 'app_language_picker.dart';
import '../../../core/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/components.dart';
import '../data/auth_exception.dart';
import '../domain/app_language.dart';

typedef AuthSubmit =
    Future<void> Function({
      required String username,
      required String password,
      String? displayName,
      String? passwordConfirmation,
      String? preferredLanguage,
    });

final class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onSubmit,
    this.isSigningUp = false,
    this.onLanguageChanged,
    super.key,
  });

  final AuthSubmit onSubmit;
  final bool isSigningUp;
  final ValueChanged<AppLanguage>? onLanguageChanged;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

final class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isSubmitting = false;
  bool _didSubmit = false;
  bool _choosingLanguage = false;
  AppLanguage? _language;
  String? _errorMessage;

  bool get _canSubmit =>
      !_isSubmitting &&
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      (!widget.isSigningUp ||
          (_displayNameController.text.trim().isNotEmpty &&
              _confirmationController.text.isNotEmpty)) &&
      (!_choosingLanguage || _language != null);

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
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
    if (!_choosingLanguage) {
      _didSubmit = true;
      if (!_formKey.currentState!.validate()) return;
      if (widget.isSigningUp) {
        FocusScope.of(context).unfocus();
        setState(() => _choosingLanguage = true);
        return;
      }
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(
        username: _usernameController.text.trim(),
        displayName: widget.isSigningUp
            ? _displayNameController.text.trim()
            : null,
        password: _passwordController.text,
        passwordConfirmation: widget.isSigningUp
            ? _confirmationController.text
            : null,
        preferredLanguage: _language?.code,
      );
      TextInput.finishAutofillContext();
      // 세션이 활성화된 뒤 가입 경로를 닫아 기존 채팅 홈으로 돌아가요.
      if (mounted && widget.isSigningUp) Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = switch (error.message) {
            'Invalid username or password' ||
            'Check your username and password.' =>
              context.l10n.invalidCredentials,
            'This username is already taken' => context.l10n.usernameTaken,
            'Passwords do not match' => context.l10n.passwordMismatch,
            'Could not save your session securely. Please sign in again.' =>
              context.l10n.sessionSaveFailed,
            _ => context.l10n.requestFailed,
          },
        );
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = context.l10n.requestFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openSignUp() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(
          onSubmit: widget.onSubmit,
          isSigningUp: true,
          onLanguageChanged: widget.onLanguageChanged,
        ),
      ),
    );
  }

  void _back() {
    if (_isSubmitting) return;
    if (_choosingLanguage) {
      setState(() {
        _choosingLanguage = false;
        _errorMessage = null;
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Widget _languages() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.languageDescription,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.space16),
      AppLanguagePicker(
        selected: _language,
        onChanged: _isSubmitting
            ? null
            : (language) => setState(() {
                _language = language;
                _errorMessage = null;
                widget.onLanguageChanged?.call(language);
              }),
      ),
    ],
  );

  Widget _fields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      AppTextField(
        controller: _usernameController,
        labelText: context.l10n.username,
        hintText: context.l10n.username,
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
        validator: (value) => validateRequiredText(
          value,
          maxLength: 50,
          emptyMessage: context.l10n.enterUsername,
          lengthMessage: context.l10n.textLengthLimit(50),
        ),
      ),
      if (widget.isSigningUp) ...[
        const SizedBox(height: AppSpacing.space16),
        AppTextField(
          inputKey: const ValueKey('auth-display-name'),
          controller: _displayNameController,
          labelText: context.l10n.displayName,
          hintText: context.l10n.displayNameHint,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enabled: !_isSubmitting,
          autofillHints: const [AutofillHints.nickname],
          onChanged: _handleInputChanged,
          validator: (value) => validateRequiredText(
            value,
            maxLength: 100,
            emptyMessage: context.l10n.enterDisplayName,
            lengthMessage: context.l10n.textLengthLimit(100),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.space16),
      _PasswordField(
        controller: _passwordController,
        label: context.l10n.password,
        showTooltip: context.l10n.showPassword,
        hideTooltip: context.l10n.hidePassword,
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
          label: context.l10n.confirmPassword,
          showTooltip: context.l10n.showConfirmation,
          hideTooltip: context.l10n.hideConfirmation,
          enabled: !_isSubmitting,
          isNewPassword: true,
          textInputAction: TextInputAction.done,
          onChanged: _handleInputChanged,
          onSubmitted: (_) => _submit(),
          validator: (value) => value == _passwordController.text
              ? null
              : context.l10n.passwordMismatch,
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_choosingLanguage && !_isSubmitting,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.isSigningUp)
              AppNavigationBar(
                title: _choosingLanguage
                    ? context.l10n.yourLanguage
                    : context.l10n.signUp,
                backTooltip: context.l10n.back,
                onBack: _back,
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
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (_choosingLanguage)
                                    _languages()
                                  else
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
                                    label: _choosingLanguage
                                        ? context.l10n.startChatting
                                        : widget.isSigningUp
                                        ? context.l10n.continueAction
                                        : context.l10n.logIn,
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
                                          context.l10n.noAccount,
                                          style: AppTypography.body.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        AppTextLink(
                                          label: context.l10n.signUp,
                                          onPressed: _isSubmitting
                                              ? null
                                              : _openSignUp,
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
    ),
  );
}

// 비밀번호와 확인 입력은 가리기·자동 완성·아이콘 동작을 함께 관리해요.
final class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.showTooltip,
    required this.hideTooltip,
    required this.enabled,
    required this.isNewPassword,
    required this.textInputAction,
    required this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String showTooltip;
  final String hideTooltip;
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
      tooltip: _obscured ? widget.showTooltip : widget.hideTooltip,
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
