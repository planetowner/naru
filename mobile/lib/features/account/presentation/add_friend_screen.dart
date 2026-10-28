import 'package:flutter/material.dart';

import '../../../core/forms/text_validation.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/components.dart';
import '../../chat/data/chat_api.dart';
import '../domain/friend_search_result.dart';
import 'user_tile.dart';

final class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({required this.chatApi, super.key});
  final ChatApi chatApi;

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

final class _AddFriendScreenState extends State<AddFriendScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  FriendSearchResult? _result;
  bool _searching = false;
  bool _adding = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searching || _adding || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _result = null;
      _error = null;
      _searched = false;
    });
    try {
      final result = await widget.chatApi.searchUser(_controller.text);
      if (mounted) {
        setState(() {
          _result = result;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.requestFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFriend() async {
    final result = _result;
    if (result == null || result.isFriend || _adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final user = await widget.chatApi.addFriend(result.user.id);
      if (mounted) {
        setState(
          () => _result = FriendSearchResult(user: user, isFriend: true),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.requestFailed);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_adding,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppNavigationBar(
              title: context.l10n.addFriend,
              backTooltip: context.l10n.back,
              onBack: () {
                if (!_adding) Navigator.of(context).pop();
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.space24),
                      child: Form(
                        key: _formKey,
                        child: AppTextField(
                          controller: _controller,
                          labelText: context.l10n.username,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          enabled: !_searching && !_adding,
                          onFieldSubmitted: (_) => _search(),
                          onChanged: (_) => setState(() {
                            _result = null;
                            _searched = false;
                            _error = null;
                          }),
                          validator: (value) => validateRequiredText(
                            value,
                            maxLength: 50,
                            emptyMessage: context.l10n.enterUsername,
                            lengthMessage: context.l10n.textLengthLimit(50),
                          ),
                        ),
                      ),
                    ),
                    if (_searching)
                      const Center(child: CircularProgressIndicator()),
                    if (_result case final result?)
                      UserTile(
                        user: result.user,
                        trailing: result.isFriend
                            ? Semantics(
                                label: context.l10n.friendAdded,
                                child: const SizedBox.square(
                                  dimension:
                                      AppMediaViewerChrome.buttonDimension,
                                  child: Icon(
                                    AppIcons.check,
                                    size: 24,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              )
                            : AppRoundIconButton(
                                icon: AppIcons.add,
                                tooltip: context.l10n.addFriend,
                                onPressed: _adding ? null : _addFriend,
                                isLoading: _adding,
                              ),
                      ),
                    if (_error != null || (_searched && _result == null))
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space24,
                        ),
                        child: Text(
                          _error ?? context.l10n.userNotFound,
                          style: AppTypography.body.copyWith(
                            color: _error == null
                                ? AppColors.textSecondary
                                : AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
