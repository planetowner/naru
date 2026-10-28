import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/forms/text_validation.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/media/pick_photo.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_radius.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/components.dart';
import '../../auth/domain/app_language.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/app_language_picker.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/data/chat_photo_library.dart';
import 'account_form_page.dart';
import 'profile_photo_picker_screen.dart';

final class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.user,
    required this.chatApi,
    required this.onSaved,
    this.photoLibrary,
    super.key,
  });
  final ChatPhotoLibrary? photoLibrary;
  final AppUser user;
  final ChatApi chatApi;
  final Future<void> Function(AppUser) onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

final class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName);
  late AppLanguage _language = AppLanguage.fromCode(
    widget.user.preferredLanguage,
  );
  late final _languageText = TextEditingController(text: _language.label);
  XFile? _photo;
  Uint8List? _photoBytes;
  String? _photoAssetId;
  bool _saving = false;
  bool _picking = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _languageText.dispose();
    super.dispose();
  }

  Future<void> _chooseLanguage() async {
    final language = await Navigator.of(context).push<AppLanguage>(
      MaterialPageRoute(builder: (_) => _LanguageScreen(initial: _language)),
    );
    if (mounted && language != null) {
      setState(() {
        _language = language;
        _languageText.text = language.label;
      });
    }
  }

  Future<void> _choosePhoto() async {
    if (_saving || _picking) return;
    ImageSource? source;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final XFile? photo;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final photoLibrary =
            widget.photoLibrary ??
            PhotoManagerChatPhotoLibrary(imagesOnly: true);
        photo = await Navigator.of(context).push<XFile>(
          MaterialPageRoute(
            builder: (_) =>
                ProfilePhotoPickerScreen(photoLibrary: photoLibrary),
          ),
        );
      } else {
        // UIKit을 쓰지 않는 플랫폼은 기존 사진 선택·촬영 흐름을 유지해요.
        source = await _choosePhotoSource();
        if (source == null || !mounted) return;
        photo = await pickPhoto(source);
      }
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      if (mounted) {
        setState(() {
          _photo = photo;
          _photoBytes = bytes;
          _photoAssetId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = source == ImageSource.camera
              ? context.l10n.cameraUnavailable
              : context.l10n.photosLoadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<ImageSource?> _choosePhotoSource() =>
      showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        barrierColor: AppColors.black.withValues(alpha: 0.32),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.radius24),
          ),
        ),
        builder: (context) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.changePhoto,
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.space24),
                for (final option in [
                  (ImageSource.gallery, context.l10n.photo, AppIcons.image),
                  (ImageSource.camera, context.l10n.camera, AppIcons.camera),
                ])
                  AppSelectionTile(
                    label: option.$2,
                    icon: option.$3,
                    selected: false,
                    onTap: () => Navigator.of(context).pop(option.$1),
                  ),
                const SizedBox(height: AppSpacing.space24),
                AppButton(
                  label: context.l10n.cancel,
                  secondary: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _save() async {
    if (_saving || _picking || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_photo != null && _photoAssetId == null) {
        _photoAssetId = await widget.chatApi.uploadProfilePhoto(
          bytes: _photoBytes!,
          fileName: _photo!.name,
          mimeType: _photo!.mimeType ?? mimeTypeForFileName(_photo!.name),
        );
      }
      final user = await widget.chatApi.updateProfile(
        displayName: _name.text,
        preferredLanguage: _language.code,
        photoAssetId: _photoAssetId,
      );
      await widget.onSaved(user);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.requestFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountFormPage(
    title: context.l10n.settings,
    busy: _saving,
    action: AppButton(
      label: context.l10n.save,
      isLoading: _saving,
      onPressed: _picking ? null : _save,
    ),
    content: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AppProfileImage.large(
              imageUrl: widget.user.profileImageUrl,
              image: _photoBytes == null ? null : MemoryImage(_photoBytes!),
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          Center(
            child: AppTextLink(
              label: context.l10n.changePhoto,
              onPressed: _saving || _picking ? null : _choosePhoto,
            ),
          ),
          const SizedBox(height: AppSpacing.space24),
          AppTextField(
            controller: _name,
            labelText: context.l10n.displayName,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            enabled: !_saving,
            validator: (value) => validateRequiredText(
              value,
              maxLength: 100,
              emptyMessage: context.l10n.enterDisplayName,
              lengthMessage: context.l10n.textLengthLimit(100),
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          AppTextField(
            controller: _languageText,
            labelText: context.l10n.language,
            readOnly: true,
            enabled: !_saving,
            onTap: _chooseLanguage,
            suffixIcon: const Icon(
              AppIcons.chevronRight,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.space12),
            Text(
              _error!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    ),
  );
}

final class _LanguageScreen extends StatefulWidget {
  const _LanguageScreen({required this.initial});
  final AppLanguage initial;
  @override
  State<_LanguageScreen> createState() => _LanguageScreenState();
}

final class _LanguageScreenState extends State<_LanguageScreen> {
  late AppLanguage _selected = widget.initial;
  @override
  Widget build(BuildContext context) => AccountFormPage(
    title: context.l10n.language,
    content: AppLanguagePicker(
      selected: _selected,
      onChanged: (value) => setState(() => _selected = value),
    ),
    action: AppButton(
      label: context.l10n.done,
      onPressed: () => Navigator.of(context).pop(_selected),
    ),
  );
}
