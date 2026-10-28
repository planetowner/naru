import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/media/pick_photo.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/components.dart';
import '../../chat/data/chat_photo_library.dart';
import '../../chat/presentation/chat_photo_picker.dart';

final class ProfilePhotoPickerScreen extends StatefulWidget {
  const ProfilePhotoPickerScreen({required this.photoLibrary, super.key});

  final ChatPhotoLibrary photoLibrary;

  @override
  State<ProfilePhotoPickerScreen> createState() =>
      _ProfilePhotoPickerScreenState();
}

final class _ProfilePhotoPickerScreenState
    extends State<ProfilePhotoPickerScreen> {
  Uint8List? _photoBytes;
  String? _selectedAssetId;
  MethodChannel? _channel;
  int _selectionRequest = 0;
  bool _loading = false;
  bool _ready = false;
  bool _cropping = false;
  bool _takingPhoto = false;
  String? _error;

  Future<void> _selectAsset(ChatPhotoAsset asset) async {
    if (_selectedAssetId == asset.id && _ready) return;
    await _loadPhoto(() async {
      final file = await widget.photoLibrary.loadOriginalFile(
        assetId: asset.id,
      );
      if (file == null) throw PlatformException(code: 'photo_unavailable');
      return file.bytes;
    }, assetId: asset.id);
  }

  Future<void> _loadPhoto(
    Future<Uint8List> Function() load, {
    String? assetId,
  }) async {
    final request = ++_selectionRequest;
    setState(() {
      _selectedAssetId = assetId;
      _photoBytes = null;
      _channel = null;
      _ready = false;
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await load();
      // 빠르게 다른 사진을 누르면 늦게 도착한 이전 사진이 선택을 덮지 않아요.
      if (!mounted || request != _selectionRequest) return;
      setState(() {
        _photoBytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _selectionRequest) return;
      setState(() {
        _loading = false;
        _error = context.l10n.photosLoadFailed;
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto || _cropping) return;
    setState(() {
      _takingPhoto = true;
      _error = null;
    });
    try {
      final photo = await pickPhoto(ImageSource.camera);
      // 촬영을 취소하면 기존 사진과 조절한 크롭 위치를 유지해요.
      if (photo != null && mounted) await _loadPhoto(photo.readAsBytes);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.cameraUnavailable);
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _onCreated(int id) async {
    final channel = MethodChannel('naru/photo-crop/$id');
    _channel = channel;
    try {
      await channel.invokeMethod<void>('ready');
      if (mounted && _channel == channel) setState(() => _ready = true);
    } on PlatformException {
      if (mounted && _channel == channel) {
        setState(() => _error = context.l10n.photosLoadFailed);
      }
    }
  }

  Future<void> _crop() async {
    if (!_ready || _cropping || _takingPhoto) return;
    setState(() {
      _cropping = true;
      _error = null;
    });
    try {
      final bytes = await _channel!.invokeMethod<Uint8List>('crop');
      if (bytes == null) throw PlatformException(code: 'crop_failed');
      if (!mounted) return;
      setState(() => _cropping = false);
      Navigator.of(context).pop(
        XFile.fromData(
          bytes,
          // iOS의 XFile은 name 대신 path에서 업로드할 파일명을 읽어요.
          path: 'profile-photo.jpg',
          mimeType: 'image/jpeg',
        ),
      );
    } on PlatformException {
      if (mounted) {
        setState(() {
          _cropping = false;
          _error = context.l10n.photosLoadFailed;
        });
      }
    }
  }

  Widget _buildCrop() => Stack(
    key: const ValueKey('profile-photo-crop'),
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: AppColors.grey100),
      if (_photoBytes case final Uint8List bytes)
        UiKitView(
          key: ValueKey(bytes),
          viewType: 'naru/photo-crop',
          creationParams: {'bytes': bytes},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onCreated,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
          },
        )
      else
        Center(
          child: _loading
              ? const CircularProgressIndicator()
              : AppRoundIconButton(
                  icon: AppIcons.camera,
                  tooltip: context.l10n.camera,
                  onPressed: _takingPhoto ? null : _takePhoto,
                ),
        ),
      const IgnorePointer(child: CustomPaint(painter: _ProfileCropMask())),
      if (_error case final String error)
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space12),
            child: ColoredBox(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space8),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_cropping,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppNavigationBar(
              title: context.l10n.profilePhoto,
              backIcon: AppIcons.close,
              backTooltip: context.l10n.cancel,
              onBack: _cropping ? null : () => Navigator.of(context).pop(),
              trailing: AppRoundIconButton(
                key: const ValueKey('profile-photo-done'),
                icon: AppIcons.check,
                tooltip: context.l10n.done,
                isLoading: _cropping,
                foregroundColor: _ready
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
                onPressed: _ready && !_takingPhoto ? _crop : null,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 가로 화면에서도 크롭과 앨범을 함께 보여주고 같은 네이티브 뷰를 유지해요.
                  final horizontal =
                      constraints.maxWidth > constraints.maxHeight;
                  final side = horizontal
                      ? constraints.maxHeight
                      : constraints.maxWidth;
                  return IgnorePointer(
                    ignoring: _cropping || _takingPhoto,
                    child: Flex(
                      direction: horizontal ? Axis.horizontal : Axis.vertical,
                      children: [
                        SizedBox.square(dimension: side, child: _buildCrop()),
                        Expanded(
                          child: ChatPhotoPicker.single(
                            photoLibrary: widget.photoLibrary,
                            selectedAssetId: _selectedAssetId,
                            // 앨범이 늦게 로딩돼도 먼저 촬영한 사진을 덮지 않아요.
                            autoSelectFirst:
                                _photoBytes == null && !_takingPhoto,
                            onSelected: (asset) =>
                                unawaited(_selectAsset(asset)),
                            onCamera: () => unawaited(_takePhoto()),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _ProfileCropMask extends CustomPainter {
  const _ProfileCropMask();

  @override
  void paint(Canvas canvas, Size size) {
    // 사진을 최대한 쓰도록 여백 없이 네 모서리만 실제 프로필 모양으로 가려요.
    final rect = Offset.zero & size;
    final profile = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * AppProfileImage.cornerRadiusFraction),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect)
        ..addRRect(profile),
      Paint()..color = AppColors.black.withValues(alpha: 0.48),
    );
    canvas.drawRRect(
      profile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_ProfileCropMask oldDelegate) => false;
}
