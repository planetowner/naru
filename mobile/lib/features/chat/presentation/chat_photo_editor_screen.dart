import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../design_system/app_typography.dart';
import '../../../design_system/components/app_media_viewer_chrome.dart';
import '../data/chat_photo_library.dart';
import '../data/chat_video_transcoder.dart';
import 'chat_video_trim_editor.dart';

bool get isChatPhotoEditorSupported => Platform.isIOS;

Future<ChatPhotoEditorResult?> openChatPhotoEditor({
  required BuildContext context,
  required List<ChatPhotoAsset> assets,
  required ChatPhotoLibrary photoLibrary,
}) async {
  return _openChatPhotoEditor(
    context: context,
    assets: assets,
    loadOriginalFile: (String assetId) {
      return photoLibrary.loadOriginalFile(assetId: assetId);
    },
  );
}

Future<ChatPhotoEditorResult?> openChatPhotoFileEditor({
  required BuildContext context,
  required ChatPhotoAsset asset,
  required ChatPhotoFile sourceFile,
}) {
  return _openChatPhotoEditor(
    context: context,
    assets: <ChatPhotoAsset>[asset],
    loadOriginalFile: (String assetId) async {
      return assetId == asset.id ? sourceFile : null;
    },
  );
}

Future<ChatPhotoEditorResult?> _openChatPhotoEditor({
  required BuildContext context,
  required List<ChatPhotoAsset> assets,
  required Future<ChatPhotoFile?> Function(String assetId) loadOriginalFile,
}) async {
  final _PreparedChatPhotoEditor prepared = await _PreparedChatPhotoEditor.load(
    assets: assets,
    loadOriginalFile: loadOriginalFile,
  );

  try {
    if (!context.mounted) {
      return null;
    }

    return await Navigator.of(context).push<ChatPhotoEditorResult>(
      MaterialPageRoute<ChatPhotoEditorResult>(
        builder: (BuildContext context) {
          return ChatPhotoEditorScreen(inputs: prepared.inputs);
        },
      ),
    );
  } finally {
    await prepared.dispose();
  }
}

final class _PreparedChatPhotoEditor {
  const _PreparedChatPhotoEditor({
    required this.inputs,
    required this.temporaryInputs,
  });

  final List<ChatPhotoEditorInput> inputs;
  final List<File> temporaryInputs;

  static Future<_PreparedChatPhotoEditor> load({
    required List<ChatPhotoAsset> assets,
    required Future<ChatPhotoFile?> Function(String assetId) loadOriginalFile,
  }) async {
    if (assets.isEmpty) {
      throw ArgumentError.value(assets, 'assets');
    }

    final Directory temporaryDirectory = await getTemporaryDirectory();
    final Directory editorInputDirectory = Directory(
      '${temporaryDirectory.path}/naru-pencil-kit-inputs',
    );
    await editorInputDirectory.create(recursive: true);

    final List<ChatPhotoEditorInput> inputs = <ChatPhotoEditorInput>[];
    final List<File> temporaryInputs = <File>[];
    final String sessionId = DateTime.now().microsecondsSinceEpoch.toString();

    try {
      for (int index = 0; index < assets.length; index++) {
        final ChatPhotoAsset asset = assets[index];
        final ChatPhotoFile? sourceFile = await loadOriginalFile(asset.id);

        if (sourceFile == null) {
          throw StateError('The selected media file is unavailable.');
        }

        String inputPath;

        if (sourceFile.localPath case final String localPath) {
          inputPath = localPath;
        } else {
          final File temporaryInput = File(
            '${editorInputDirectory.path}/$sessionId-$index'
            '${_fileExtension(sourceFile.fileName, isVideo: asset.isVideo)}',
          );
          await temporaryInput.writeAsBytes(sourceFile.bytes, flush: true);
          temporaryInputs.add(temporaryInput);
          inputPath = temporaryInput.path;
        }

        inputs.add(
          ChatPhotoEditorInput(
            asset: asset,
            sourceFile: sourceFile,
            inputPath: inputPath,
            editorId: '$sessionId-$index',
          ),
        );
      }
    } on Object {
      await _deleteTemporaryInputs(temporaryInputs);
      rethrow;
    }

    return _PreparedChatPhotoEditor(
      inputs: List<ChatPhotoEditorInput>.unmodifiable(inputs),
      temporaryInputs: List<File>.unmodifiable(temporaryInputs),
    );
  }

  Future<void> dispose() {
    return _deleteTemporaryInputs(temporaryInputs);
  }

  static String _fileExtension(String fileName, {required bool isVideo}) {
    final int extensionIndex = fileName.lastIndexOf('.');

    if (extensionIndex <= 0 || extensionIndex == fileName.length - 1) {
      return isVideo ? '.mp4' : '.jpg';
    }

    final String extension = fileName.substring(extensionIndex);
    final RegExp safeExtension = RegExp(r'^\.[A-Za-z0-9]{1,8}$');

    return safeExtension.hasMatch(extension) ? extension : '.jpg';
  }

  static Future<void> _deleteTemporaryInputs(Iterable<File> files) async {
    for (final File file in files) {
      try {
        await file.delete();
      } on FileSystemException {
        // 편집용 임시 파일 삭제 실패는 사진 전송 결과에 영향을 주지 않아요.
      }
    }
  }
}

final class ChatPhotoEditorInput {
  const ChatPhotoEditorInput({
    required this.asset,
    required this.sourceFile,
    required this.inputPath,
    required this.editorId,
  });

  final ChatPhotoAsset asset;
  final ChatPhotoFile sourceFile;
  final String inputPath;
  final String editorId;
}

final class ChatPhotoEditorResult {
  ChatPhotoEditorResult({
    Map<String, ChatPhotoFile> editedFilesByAssetId =
        const <String, ChatPhotoFile>{},
    Map<String, Uint8List> previewBytesByAssetId = const <String, Uint8List>{},
    Map<String, ChatVideoTrimRange> videoTrimRangesByAssetId =
        const <String, ChatVideoTrimRange>{},
  }) : editedFilesByAssetId = Map<String, ChatPhotoFile>.unmodifiable(
         editedFilesByAssetId,
       ),
       previewBytesByAssetId = Map<String, Uint8List>.unmodifiable(
         previewBytesByAssetId,
       ),
       videoTrimRangesByAssetId = Map<String, ChatVideoTrimRange>.unmodifiable(
         videoTrimRangesByAssetId,
       );

  final Map<String, ChatPhotoFile> editedFilesByAssetId;
  final Map<String, Uint8List> previewBytesByAssetId;
  final Map<String, ChatVideoTrimRange> videoTrimRangesByAssetId;
}

final class ChatPhotoEditorScreen extends StatefulWidget {
  const ChatPhotoEditorScreen({required this.inputs, super.key})
    : assert(inputs.length > 0);

  final List<ChatPhotoEditorInput> inputs;

  @override
  State<ChatPhotoEditorScreen> createState() {
    return _ChatPhotoEditorScreenState();
  }
}

final class _ChatPhotoEditorScreenState extends State<ChatPhotoEditorScreen> {
  static const MethodChannel _channel = MethodChannel('naru/pencil-kit-editor');

  late final PageController _pageController;
  final Map<String, ChatVideoTrimRange> _videoTrimRanges =
      <String, ChatVideoTrimRange>{};

  int _currentIndex = 0;
  bool _controlsVisible = true;
  bool _closing = false;
  bool _sending = false;
  double _controlCenterFromBottom =
      ChatVideoTrimTimeline.referenceControlCenterFromBottom;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handlePencilKitMethodCall);
    // 선택 목록의 첫 사진부터 보여주는 줄리아톡의 편집 순서를 유지해요.
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_activateEditor(_currentIndex));
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _channel.setMethodCallHandler(null);
    unawaited(
      _channel.invokeMethod<void>('dispose', <String, Object>{
        'editor_ids': widget.inputs
            .where((ChatPhotoEditorInput input) => !input.asset.isVideo)
            .map((ChatPhotoEditorInput input) => input.editorId)
            .toList(growable: false),
      }),
    );
    super.dispose();
  }

  Future<void> _handlePencilKitMethodCall(MethodCall call) async {
    if (call.method != 'tool-picker-frame-changed' || !mounted) {
      return;
    }

    final Object? arguments = call.arguments;
    if (arguments is! Map<Object?, Object?>) {
      return;
    }

    final Object? value = arguments['center_from_bottom'];
    if (value is! num || value <= 0) {
      return;
    }

    setState(() {
      _controlCenterFromBottom = value.toDouble();
    });
  }

  Future<void> _activateEditor(int index) async {
    try {
      await _channel.invokeMethod<void>('activate', <String, Object>{
        'editor_id': widget.inputs[index].editorId,
      });
      await _setEditorControlsVisible(index, _controlsVisible);
    } on PlatformException {
      // 플랫폼 뷰가 만들어지는 같은 프레임에는 자체적으로 도구를 활성화해요.
    }
  }

  Future<void> _setEditorControlsVisible(int index, bool visible) async {
    if (widget.inputs[index].asset.isVideo) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(
        'set-controls-visible',
        <String, Object>{
          'editor_id': widget.inputs[index].editorId,
          'visible': visible,
        },
      );
    } on PlatformException {
      // 플랫폼 뷰 생성 전 상태는 생성 인자로 다시 전달해요.
    }
  }

  void _toggleControls() {
    final bool visible = !_controlsVisible;

    setState(() {
      _controlsVisible = visible;
    });
    unawaited(_setEditorControlsVisible(_currentIndex, visible));
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    unawaited(_activateEditor(index));
  }

  void _handleVideoTrimChanged(
    ChatPhotoEditorInput input,
    ChatVideoTrimRange range,
  ) {
    _videoTrimRanges[input.asset.id] = range;
  }

  Future<void> _close() async {
    if (_closing || _sending) {
      return;
    }

    _closing = true;
    final List<String> photoEditorIds = widget.inputs
        .where((ChatPhotoEditorInput input) => !input.asset.isVideo)
        .map((ChatPhotoEditorInput input) => input.editorId)
        .toList(growable: false);

    if (photoEditorIds.isNotEmpty) {
      try {
        // Flutter 화면 전환 전에 시스템 툴바부터 내려야 닫기 반응이 즉시 보여요.
        await _channel.invokeMethod<void>('deactivate', <String, Object>{
          'editor_ids': photoEditorIds,
        });
      } on PlatformException {
        // 플랫폼 뷰가 이미 해제된 경우에도 편집 화면은 정상적으로 닫아요.
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _send() async {
    if (_sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final List<Object?>? rendered = await _channel
          .invokeListMethod<Object?>('render', <String, Object>{
            'editor_ids': widget.inputs
                .where((ChatPhotoEditorInput input) => !input.asset.isVideo)
                .map((ChatPhotoEditorInput input) => input.editorId)
                .toList(growable: false),
          });
      final Map<String, ChatPhotoEditorInput> inputsByEditorId =
          <String, ChatPhotoEditorInput>{
            for (final ChatPhotoEditorInput input in widget.inputs)
              input.editorId: input,
          };
      final Map<String, ChatPhotoFile> editedFiles = <String, ChatPhotoFile>{};
      final Map<String, Uint8List> previewBytes = <String, Uint8List>{};

      for (final Object? item in rendered ?? const <Object?>[]) {
        if (item is! Map<Object?, Object?>) {
          continue;
        }

        final String? editorId = item['editor_id'] as String?;
        final String? outputPath = item['output_path'] as String?;
        final String? previewPath = item['preview_path'] as String?;
        final ChatPhotoEditorInput? input = inputsByEditorId[editorId];

        if (input == null || outputPath == null || previewPath == null) {
          continue;
        }

        final Uint8List output = await File(outputPath).readAsBytes();
        final Uint8List preview = await File(previewPath).readAsBytes();
        final String editedFileName = _editedFileName(
          input.sourceFile.fileName,
        );

        editedFiles[input.asset.id] = ChatPhotoFile(
          bytes: output,
          fileName: editedFileName,
          mimeType: 'image/jpeg',
          sizeBytes: output.length,
          localPath: outputPath,
        );
        previewBytes[input.asset.id] = preview;
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        ChatPhotoEditorResult(
          editedFilesByAssetId: editedFiles,
          previewBytesByAssetId: previewBytes,
          videoTrimRangesByAssetId: _videoTrimRanges,
        ),
      );
    } on Object {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Media editing could not be completed.'),
          ),
        );
      setState(() {
        _sending = false;
      });
    }
  }

  static String _editedFileName(String sourceFileName) {
    final int extensionIndex = sourceFileName.lastIndexOf('.');
    final String baseName = extensionIndex <= 0
        ? sourceFileName
        : sourceFileName.substring(0, extensionIndex);

    return '$baseName-edited.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safeArea = MediaQuery.paddingOf(context);
    final double topBarHeight = AppMediaViewerChrome.topBarHeight(safeArea.top);
    final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle.light
        .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppMediaViewerChrome.backgroundColor,
          systemNavigationBarIconBrightness: Brightness.light,
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: !_sending,
        child: Scaffold(
          backgroundColor: AppMediaViewerChrome.backgroundColor,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  key: const ValueKey<String>('photo-editor-page-view'),
                  controller: _pageController,
                  itemCount: widget.inputs.length,
                  onPageChanged: _handlePageChanged,
                  itemBuilder: (BuildContext context, int index) {
                    final ChatPhotoEditorInput input = widget.inputs[index];

                    if (input.asset.isVideo) {
                      return ChatVideoTrimEditor(
                        key: ValueKey<String>(
                          'video-trim-editor-${input.asset.id}',
                        ),
                        inputPath: input.inputPath,
                        duration: input.asset.duration,
                        active: index == _currentIndex,
                        controlsVisible: _controlsVisible,
                        controlCenterFromBottom: _controlCenterFromBottom,
                        onTrimChanged: (ChatVideoTrimRange range) {
                          _handleVideoTrimChanged(input, range);
                        },
                      );
                    }

                    return UiKitView(
                      key: ValueKey<String>(
                        'photo-editor-canvas-${input.asset.id}',
                      ),
                      viewType: 'naru/pencil-kit-editor',
                      creationParams: <String, Object>{
                        'editor_id': input.editorId,
                        'input_path': input.inputPath,
                        'image_width': input.asset.width,
                        'image_height': input.asset.height,
                        'active': index == _currentIndex,
                        'controls_visible': _controlsVisible,
                      },
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: (_) {
                        if (index == _currentIndex) {
                          unawaited(_activateEditor(index));
                        }
                      },
                    );
                  },
                ),
                ChatPhotoEditorTopBar(
                  visible: _controlsVisible,
                  height: topBarHeight,
                  topPadding: safeArea.top,
                  currentIndex: _currentIndex,
                  photoCount: widget.inputs.length,
                  sending: _sending,
                  onBackPressed: () {
                    unawaited(_close());
                  },
                  onSendPressed: () {
                    unawaited(_send());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class ChatPhotoEditorTopBar extends StatelessWidget {
  const ChatPhotoEditorTopBar({
    required this.visible,
    required this.height,
    required this.topPadding,
    required this.currentIndex,
    required this.photoCount,
    required this.sending,
    required this.onBackPressed,
    required this.onSendPressed,
    super.key,
  });

  final bool visible;
  final double height;
  final double topPadding;
  final int currentIndex;
  final int photoCount;
  final bool sending;
  final VoidCallback onBackPressed;
  final VoidCallback onSendPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey<String>('photo-editor-top-bar'),
      left: 0,
      top: 0,
      right: 0,
      height: height,
      child: AppMediaViewerControlsTransition(
        slideKey: const ValueKey<String>('photo-editor-top-bar-slide'),
        opacityKey: const ValueKey<String>('photo-editor-top-bar-opacity'),
        visible: visible,
        hiddenOffset: const Offset(0, -1),
        child: AppMediaViewerControlTapRegion(
          child: ColoredBox(
            color: AppMediaViewerChrome.backgroundColor,
            child: Stack(
              children: [
                Positioned(
                  key: const ValueKey<String>('photo-editor-back-position'),
                  left: AppMediaViewerChrome.horizontalMargin,
                  top: topPadding,
                  child: AppMediaViewerChromeButton(
                    key: const ValueKey<String>('photo-editor-back'),
                    onPressed: onBackPressed,
                    child: const AppTopBarBackIcon(),
                  ),
                ),
                Positioned(
                  key: const ValueKey<String>('photo-editor-counter-position'),
                  left:
                      AppMediaViewerChrome.horizontalMargin +
                      AppMediaViewerChrome.buttonDimension +
                      11.0,
                  top: topPadding,
                  height: AppMediaViewerChrome.buttonDimension,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${currentIndex + 1} / $photoCount',
                      key: const ValueKey<String>('photo-editor-counter'),
                      maxLines: 1,
                      // 기존 상단바의 한 줄 높이를 유지해 글자 위치가 바뀌지 않게 해요.
                      style: AppTypography.subTypography9.copyWith(
                        color: AppMediaViewerChrome.foregroundColor,
                        fontWeight: AppTypography.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: AppMediaViewerChrome.horizontalMargin,
                  top: topPadding,
                  child: AppTopBarButtonSurface(
                    key: const ValueKey<String>('photo-editor-send'),
                    height: AppMediaViewerChrome.buttonDimension,
                    color: AppMediaViewerChrome.buttonColor,
                    borderColor: AppMediaViewerChrome.buttonBorderColor,
                    child: InkWell(
                      onTap: sending ? null : onSendPressed,
                      borderRadius:
                          AppTopBarButtonSurface.borderRadiusForHeight(
                            AppMediaViewerChrome.buttonDimension,
                          ),
                      child: Padding(
                        key: const ValueKey<String>(
                          'photo-editor-send-padding',
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        child: Center(
                          child: Text.rich(
                            TextSpan(
                              children: <InlineSpan>[
                                TextSpan(text: '$photoCount'),
                                const TextSpan(text: ' Send'),
                              ],
                            ),
                            key: const ValueKey<String>(
                              'photo-editor-send-label',
                            ),
                            maxLines: 1,
                            softWrap: false,
                            style: AppTypography.subTypography10.copyWith(
                              color: AppMediaViewerChrome.foregroundColor,
                              fontWeight: AppTypography.regular,
                              height: 1,
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
      ),
    );
  }
}
