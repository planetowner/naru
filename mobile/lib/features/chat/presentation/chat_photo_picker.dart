import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_radius.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/app_media_viewer_chrome.dart';
import '../data/chat_photo_library.dart';
import '../data/chat_video_transcoder.dart';
import 'chat_duration_formatter.dart';
import 'chat_photo_editor_screen.dart';

final class ChatPhotoSelectionResult {
  ChatPhotoSelectionResult({
    required List<ChatPhotoAsset> assets,
    required this.collage,
    Map<String, Uint8List> previewBytesByAssetId = const <String, Uint8List>{},
    Map<String, ChatPhotoFile> editedFilesByAssetId =
        const <String, ChatPhotoFile>{},
    Map<String, ChatVideoTrimRange> videoTrimRangesByAssetId =
        const <String, ChatVideoTrimRange>{},
  }) : assets = List<ChatPhotoAsset>.unmodifiable(assets),
       previewBytesByAssetId = Map<String, Uint8List>.unmodifiable(
         previewBytesByAssetId,
       ),
       editedFilesByAssetId = Map<String, ChatPhotoFile>.unmodifiable(
         editedFilesByAssetId,
       ),
       videoTrimRangesByAssetId = Map<String, ChatVideoTrimRange>.unmodifiable(
         videoTrimRangesByAssetId,
       );

  final List<ChatPhotoAsset> assets;
  final bool collage;
  final Map<String, Uint8List> previewBytesByAssetId;
  final Map<String, ChatPhotoFile> editedFilesByAssetId;
  final Map<String, ChatVideoTrimRange> videoTrimRangesByAssetId;
}

typedef ChatPhotoSendCallback =
    Future<void> Function(ChatPhotoSelectionResult result);

final class ChatPhotoPicker extends StatefulWidget {
  // 격자와 사진 추가·삭제 시 이동 계산이 같은 열 수와 간격을 사용해요.
  static const int _gridCrossAxisCount = 3;

  static const double _gridSpacing = 2;

  static const double _albumThumbnailDimension = 60;

  static const double _collageIndicatorSize = 22;

  static const double _collageControlHeight = 48;

  static const double _photoEditButtonSize = 40;

  static const double _photoEditButtonRight = 10;

  static const double _photoEditButtonBottom = 25;

  static const double _tileHorizontalInset = 7;

  static const double _selectionBadgeDimension = 28;

  // 선택 순서 배지와 묶어 보내기는 같은 원형 테두리를 쓰되 미선택 색은 달라요.
  static BoxDecoration _selectionDecoration({
    required bool selected,
    required Color unselectedColor,
    required Color unselectedBorderColor,
  }) => BoxDecoration(
    color: selected ? AppColors.blue500 : unselectedColor,
    shape: BoxShape.circle,
    border: Border.all(
      color: selected ? AppColors.blue500 : unselectedBorderColor,
      width: 1.5,
    ),
  );

  static const double _assetScaleChange = 0.12;

  const ChatPhotoPicker({
    required this.photoLibrary,
    required this.onClose,
    required this.onSend,
    this.expanded = false,
    this.onHandleDragStart,
    this.onHandleDragUpdate,
    this.onHandleDragEnd,
    super.key,
  }) : onSelected = null,
       selectedAssetId = null,
       autoSelectFirst = false,
       onCamera = null;

  // 프로필도 앨범·권한·격자 갱신을 공유하고 선택 방식만 한 장으로 바꿔요.
  const ChatPhotoPicker.single({
    required this.photoLibrary,
    required this.selectedAssetId,
    required ValueChanged<ChatPhotoAsset> this.onSelected,
    required VoidCallback this.onCamera,
    this.autoSelectFirst = true,
    super.key,
  }) : onClose = null,
       onSend = null,
       expanded = true,
       onHandleDragStart = null,
       onHandleDragUpdate = null,
       onHandleDragEnd = null;

  final ValueChanged<ChatPhotoAsset>? onSelected;
  final bool autoSelectFirst;
  final String? selectedAssetId;
  final VoidCallback? onCamera;
  final ChatPhotoLibrary photoLibrary;
  final VoidCallback? onClose;
  final ChatPhotoSendCallback? onSend;

  final bool expanded;

  final GestureDragStartCallback? onHandleDragStart;

  final GestureDragUpdateCallback? onHandleDragUpdate;

  final GestureDragEndCallback? onHandleDragEnd;

  @override
  State<ChatPhotoPicker> createState() {
    return _ChatPhotoPickerState();
  }
}

final class _ChatPhotoPickerState extends State<ChatPhotoPicker>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const int _pageSize = 60;
  static const int _maximumSelectionCount = 10;
  static const Duration _libraryRefreshDebounceDuration = Duration(
    milliseconds: 180,
  );

  final ScrollController _gridController = ScrollController();

  late final AnimationController _assetTransitionController;

  final List<ChatPhotoAlbum> _albums = <ChatPhotoAlbum>[];

  final List<ChatPhotoAsset> _assets = <ChatPhotoAsset>[];

  final List<ChatPhotoAsset> _selectedAssets = <ChatPhotoAsset>[];

  final Set<String> _pendingDeletedAssetIds = <String>{};
  final Map<String, Uint8List> _thumbnailBytesByAssetId = <String, Uint8List>{};

  ChatPhotoAccessState? _accessState;
  ChatPhotoAlbum? _selectedAlbum;

  ChatPhotoLibraryChangeSource? _changeSource;

  Timer? _libraryRefreshTimer;

  _PhotoGridTransition? _photoGridTransition;
  List<ChatPhotoAsset>? _queuedAssetSnapshot;

  late AppLifecycleState _appLifecycleState;

  int _nextPage = 0;

  bool _initializing = true;
  bool _loadingMore = false;
  bool _hasMoreAssets = true;
  bool _sending = false;
  bool _openingEditor = false;
  bool _refreshingLibrary = false;
  bool _libraryRefreshRequested = false;
  bool _collagePhotos = true;

  bool _albumListOpen = false;
  bool _selectedInitialAsset = false;

  bool get _singleSelection => widget.onSelected != null;
  int get _leadingTileCount => widget.onCamera == null ? 0 : 1;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _assetTransitionController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 160),
    )..addStatusListener(_handleAssetTransitionStatus);
    _appLifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

    WidgetsBinding.instance.addObserver(this);
    _gridController.addListener(_handleGridScroll);

    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(ChatPhotoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.photoLibrary != widget.photoLibrary) {
      _unsubscribeFromLibraryChanges();
      _pendingDeletedAssetIds.clear();
      _thumbnailBytesByAssetId.clear();
      _selectedInitialAsset = false;
      unawaited(_reinitializeForPhotoLibraryChange());
    }

    if (oldWidget.expanded && !widget.expanded && _albumListOpen) {
      _albumListOpen = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _libraryRefreshTimer?.cancel();
    _unsubscribeFromLibraryChanges();
    _assetTransitionController
      ..removeStatusListener(_handleAssetTransitionStatus)
      ..dispose();

    _gridController
      ..removeListener(_handleGridScroll)
      ..dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      _scheduleLibraryRefresh();
    } else {
      _libraryRefreshTimer?.cancel();
      _libraryRefreshTimer = null;
    }
  }

  Future<void> _reinitializeForPhotoLibraryChange() async {
    if (!mounted) {
      return;
    }

    _assetTransitionController.stop();

    setState(() {
      _photoGridTransition = null;
      _queuedAssetSnapshot = null;
      _accessState = null;
      _selectedAlbum = null;
      _albums.clear();
      _assets.clear();
      _selectedAssets.clear();
      _nextPage = 0;
      _hasMoreAssets = true;
      _initializing = true;
      _errorMessage = null;
    });

    await _initialize();
  }

  void _subscribeToLibraryChanges() {
    if (_changeSource != null) {
      return;
    }

    final Object photoLibrary = widget.photoLibrary;

    if (photoLibrary is! ChatPhotoLibraryChangeSource) {
      return;
    }

    photoLibrary.addChangeListener(_handlePhotoLibraryChange);
    _changeSource = photoLibrary;
  }

  void _unsubscribeFromLibraryChanges() {
    final ChatPhotoLibraryChangeSource? changeSource = _changeSource;

    if (changeSource == null) {
      return;
    }

    changeSource.removeChangeListener(_handlePhotoLibraryChange);
    _changeSource = null;
  }

  void _handlePhotoLibraryChange(ChatPhotoLibraryChange change) {
    _pendingDeletedAssetIds.addAll(change.deletedAssetIds);
    _scheduleLibraryRefresh();
  }

  void _scheduleLibraryRefresh() {
    if (!mounted ||
        _accessState == null ||
        _accessState == ChatPhotoAccessState.denied) {
      return;
    }

    _libraryRefreshRequested = true;
    _libraryRefreshTimer?.cancel();

    if (_appLifecycleState != AppLifecycleState.resumed) {
      _libraryRefreshTimer = null;
      return;
    }

    _libraryRefreshTimer = Timer(_libraryRefreshDebounceDuration, () {
      _libraryRefreshTimer = null;
      unawaited(_refreshLibrary());
    });
  }

  void _schedulePendingLibraryRefresh() {
    if (_libraryRefreshRequested && !_refreshingLibrary) {
      _scheduleLibraryRefresh();
    }
  }

  Future<void> _refreshLibrary() async {
    if (!mounted) {
      return;
    }

    if (_initializing || _loadingMore || _refreshingLibrary) {
      _libraryRefreshRequested = true;
      return;
    }

    _libraryRefreshRequested = false;
    _refreshingLibrary = true;

    try {
      if (widget.photoLibrary case final ChatPhotoLibraryPreloader preloader) {
        preloader.invalidateCache();
      }

      final String? previouslySelectedAlbumId = _selectedAlbum?.id;
      final List<ChatPhotoAlbum> albums = await widget.photoLibrary
          .loadAlbums();

      if (!mounted) {
        return;
      }

      if (albums.isEmpty) {
        setState(() {
          _albums.clear();
          _selectedAlbum = null;
          _selectedAssets.clear();
          _errorMessage = _accessState == ChatPhotoAccessState.limited
              ? context.l10n.noSharedPhotos
              : context.l10n.noDevicePhotos;
          _nextPage = 0;
          _hasMoreAssets = false;
        });

        _applyAssetSnapshot(const <ChatPhotoAsset>[], animate: true);
        _pendingDeletedAssetIds.clear();
        return;
      }

      final ChatPhotoAlbum refreshedAlbum = albums.firstWhere(
        (ChatPhotoAlbum album) => album.id == previouslySelectedAlbumId,
        orElse: () => albums.firstWhere(
          (ChatPhotoAlbum album) => album.isAll,
          orElse: () => albums.first,
        ),
      );

      final bool sameAlbum = refreshedAlbum.id == previouslySelectedAlbumId;
      final int pagesToLoad = sameAlbum && _assets.isNotEmpty
          ? (_assets.length + _pageSize - 1) ~/ _pageSize
          : 1;
      final List<ChatPhotoAsset> refreshedAssets = <ChatPhotoAsset>[];
      final Set<String> refreshedAssetIds = <String>{};

      int loadedPages = 0;
      int lastPageLength = 0;

      for (int page = 0; page < pagesToLoad; page++) {
        final List<ChatPhotoAsset> pageAssets = await widget.photoLibrary
            .loadAssets(
              albumId: refreshedAlbum.id,
              page: page,
              pageSize: _pageSize,
            );

        loadedPages = page + 1;
        lastPageLength = pageAssets.length;

        for (final ChatPhotoAsset asset in pageAssets) {
          if (refreshedAssetIds.add(asset.id)) {
            refreshedAssets.add(asset);
          }
        }

        if (pageAssets.length < _pageSize) {
          break;
        }
      }

      if (!mounted) {
        return;
      }

      // 사용자가 새로고침 도중 다른 앨범을 선택했다면 현재 선택을
      // 유지하고 새 선택을 기준으로 다시 조회해요.
      if (_selectedAlbum?.id != previouslySelectedAlbumId) {
        _libraryRefreshRequested = true;
        return;
      }

      setState(() {
        _albums
          ..clear()
          ..addAll(albums);
        _selectedAlbum = refreshedAlbum;
        _errorMessage = null;
        _nextPage = loadedPages;
        _hasMoreAssets = lastPageLength == _pageSize;
      });

      _applyAssetSnapshot(refreshedAssets, animate: sameAlbum);

      if (_pendingDeletedAssetIds.isNotEmpty) {
        setState(() {
          _selectedAssets.removeWhere(
            (ChatPhotoAsset asset) =>
                _pendingDeletedAssetIds.contains(asset.id),
          );
        });
      }

      _pendingDeletedAssetIds.clear();
    } catch (_) {
      // Photos 조회가 잠시 실패해도 현재 화면을 유지해요.
      // 다음 변경 알림이나 앱 복귀 때 다시 동기화해요.
    } finally {
      _refreshingLibrary = false;

      if (mounted && _libraryRefreshRequested) {
        _scheduleLibraryRefresh();
      }
    }
  }

  void _applyAssetSnapshot(
    List<ChatPhotoAsset> nextAssets, {
    required bool animate,
  }) {
    if (!animate || _initializing || _albumListOpen) {
      _assetTransitionController.stop();

      setState(() {
        _photoGridTransition = null;
        _queuedAssetSnapshot = null;
        _assets
          ..clear()
          ..addAll(nextAssets);
      });

      return;
    }

    if (_assetTransitionController.isAnimating) {
      _queuedAssetSnapshot = List<ChatPhotoAsset>.of(nextAssets);
      return;
    }

    final List<ChatPhotoAsset> previousAssets = List<ChatPhotoAsset>.of(
      _assets,
    );
    final Map<String, int> previousIndexes = <String, int>{
      for (int index = 0; index < previousAssets.length; index++)
        previousAssets[index].id: index,
    };
    final Map<String, int> nextIndexes = <String, int>{
      for (int index = 0; index < nextAssets.length; index++)
        nextAssets[index].id: index,
    };
    final Set<String> addedAssetIds = nextIndexes.keys
        .where((String assetId) => !previousIndexes.containsKey(assetId))
        .toSet();
    final List<_RemovedPhotoGridItem> removedItems = <_RemovedPhotoGridItem>[];
    bool assetsMoved = false;

    for (int index = 0; index < previousAssets.length; index++) {
      final ChatPhotoAsset asset = previousAssets[index];
      final int? nextIndex = nextIndexes[asset.id];

      if (nextIndex == null) {
        final int selectionIndex = _selectionIndex(asset);

        removedItems.add(
          _RemovedPhotoGridItem(
            asset: asset,
            previousIndex: index,
            selectedNumber: selectionIndex < 0 ? null : selectionIndex + 1,
            thumbnailBytes: _thumbnailBytesByAssetId[asset.id],
          ),
        );
      } else if (nextIndex != index) {
        assetsMoved = true;
      }
    }

    if (addedAssetIds.isEmpty && removedItems.isEmpty && !assetsMoved) {
      setState(() {
        _assets
          ..clear()
          ..addAll(nextAssets);
      });

      return;
    }

    final double scrollOffset = _gridController.hasClients
        ? _gridController.position.pixels
        : 0;

    // 각 자산의 이전 인덱스를 유지한 채 새 스냅샷을 먼저 배치해요.
    // 타일은 이전 좌표에서 새 좌표까지 한 타임라인으로 이동해요.
    setState(() {
      _photoGridTransition = _PhotoGridTransition(
        previousIndexes: previousIndexes,
        addedAssetIds: addedAssetIds,
        removedItems: removedItems,
        scrollOffset: scrollOffset,
      );
      _assets
        ..clear()
        ..addAll(nextAssets);
    });

    _assetTransitionController.forward(from: 0);
  }

  void _handleAssetTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }

    final List<ChatPhotoAsset>? queuedSnapshot = _queuedAssetSnapshot;

    setState(() {
      _photoGridTransition = null;
      _queuedAssetSnapshot = null;
    });

    if (queuedSnapshot == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _applyAssetSnapshot(queuedSnapshot, animate: true);
      }
    });
  }

  Future<void> _initialize() async {
    try {
      final ChatPhotoAccessState accessState = await widget.photoLibrary
          .requestAccess();

      if (!mounted) {
        return;
      }

      if (accessState == ChatPhotoAccessState.denied) {
        setState(() {
          _accessState = accessState;
          _initializing = false;
        });

        return;
      }

      _subscribeToLibraryChanges();

      if (widget.photoLibrary case final ChatPhotoLibraryPreloader preloader) {
        // 선택기가 닫힌 동안에는 변경 알림을 구독하지 않아요. 다시 열 때
        // 사진 목록만 새로 조회하고 앨범 정보와 썸네일은 그대로 사용해요.
        preloader.invalidateAssetListingCache();
      }

      final List<ChatPhotoAlbum> albums = await widget.photoLibrary
          .loadAlbums();

      if (!mounted) {
        return;
      }

      if (albums.isEmpty) {
        setState(() {
          _accessState = accessState;
          _initializing = false;
          _errorMessage = accessState == ChatPhotoAccessState.limited
              ? context.l10n.noSharedPhotos
              : context.l10n.noDevicePhotos;
        });

        return;
      }

      final ChatPhotoAlbum initialAlbum = albums.firstWhere(
        (ChatPhotoAlbum album) => album.isAll,
        orElse: () => albums.first,
      );

      setState(() {
        _accessState = accessState;
        _albums
          ..clear()
          ..addAll(albums);
        _selectedAlbum = initialAlbum;
      });

      await _loadFirstPage(initialAlbum);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _initializing = false;
        _errorMessage = context.l10n.photosLoadFailed;
      });
    } finally {
      _schedulePendingLibraryRefresh();
    }
  }

  Future<void> _loadFirstPage(ChatPhotoAlbum album) async {
    _assetTransitionController.stop();

    setState(() {
      _photoGridTransition = null;
      _queuedAssetSnapshot = null;
      _initializing = true;
      _errorMessage = null;
      _nextPage = 0;
      _hasMoreAssets = true;
      _assets.clear();
      _selectedAlbum = album;
    });

    try {
      final List<ChatPhotoAsset> firstPage = await widget.photoLibrary
          .loadAssets(albumId: album.id, page: 0, pageSize: _pageSize);

      if (!mounted || _selectedAlbum?.id != album.id) {
        return;
      }

      setState(() {
        _assets.addAll(firstPage);
        _nextPage = 1;
        _hasMoreAssets = firstPage.length == _pageSize;
        _initializing = false;
      });

      if (_gridController.hasClients) {
        _gridController.jumpTo(0);
      }
      if (_singleSelection && !_selectedInitialAsset && firstPage.isNotEmpty) {
        _selectedInitialAsset = true;
        if (widget.autoSelectFirst && widget.selectedAssetId == null) {
          widget.onSelected!(firstPage.first);
        }
      }
    } catch (_) {
      if (!mounted || _selectedAlbum?.id != album.id) {
        return;
      }

      setState(() {
        _initializing = false;
        _errorMessage = context.l10n.albumLoadFailed;
      });
    } finally {
      _schedulePendingLibraryRefresh();
    }
  }

  Future<void> _loadMoreAssets() async {
    final ChatPhotoAlbum? album = _selectedAlbum;

    if (album == null ||
        _loadingMore ||
        _refreshingLibrary ||
        !_hasMoreAssets) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final List<ChatPhotoAsset> nextPage = await widget.photoLibrary
          .loadAssets(albumId: album.id, page: _nextPage, pageSize: _pageSize);

      if (!mounted || _selectedAlbum?.id != album.id) {
        return;
      }

      final Set<String> existingIds = _assets
          .map((ChatPhotoAsset asset) => asset.id)
          .toSet();
      final List<ChatPhotoAsset> appendedAssets = nextPage
          .where((ChatPhotoAsset asset) => !existingIds.contains(asset.id))
          .toList(growable: false);
      final List<ChatPhotoAsset> nextSnapshot = <ChatPhotoAsset>[
        ..._assets,
        ...appendedAssets,
      ];

      setState(() {
        _nextPage++;
        _hasMoreAssets = nextPage.length == _pageSize;
      });

      _applyAssetSnapshot(nextSnapshot, animate: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });

        _schedulePendingLibraryRefresh();
      }
    }
  }

  void _handleGridScroll() {
    if (!_gridController.hasClients ||
        _loadingMore ||
        _refreshingLibrary ||
        !_hasMoreAssets) {
      return;
    }

    final ScrollPosition position = _gridController.position;

    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(_loadMoreAssets());
    }
  }

  int _selectionIndex(ChatPhotoAsset asset) {
    if (_singleSelection) return widget.selectedAssetId == asset.id ? 0 : -1;
    return _selectedAssets.indexWhere(
      (ChatPhotoAsset selectedAsset) => selectedAsset.id == asset.id,
    );
  }

  void _cacheThumbnail(String assetId, Uint8List bytes) {
    _thumbnailBytesByAssetId
      ..remove(assetId)
      ..[assetId] = bytes;

    while (_thumbnailBytesByAssetId.length > 180) {
      _thumbnailBytesByAssetId.remove(_thumbnailBytesByAssetId.keys.first);
    }
  }

  void _toggleAsset(ChatPhotoAsset asset) {
    if (_singleSelection) {
      _selectedInitialAsset = true;
      widget.onSelected!(asset);
      return;
    }
    final int currentIndex = _selectionIndex(asset);

    if (currentIndex >= 0) {
      setState(() {
        _selectedAssets.removeAt(currentIndex);
      });

      return;
    }

    if (_selectedAssets.length >= _maximumSelectionCount) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.selectionLimit)));

      return;
    }

    setState(() {
      _selectedAssets.add(asset);
    });
  }

  Future<void> _sendSelection({ChatPhotoEditorResult? editorResult}) async {
    if (_selectedAssets.isEmpty || _sending) {
      return;
    }

    _sending = true;

    try {
      await widget.onSend!(
        ChatPhotoSelectionResult(
          assets: _selectedAssets,
          collage: _collagePhotos,
          previewBytesByAssetId: <String, Uint8List>{
            for (final ChatPhotoAsset asset in _selectedAssets)
              if (editorResult?.previewBytesByAssetId[asset.id]
                  case final Uint8List editedPreview)
                asset.id: editedPreview
              else if (_thumbnailBytesByAssetId[asset.id]
                  case final Uint8List thumbnail)
                asset.id: thumbnail,
          },
          editedFilesByAssetId:
              editorResult?.editedFilesByAssetId ??
              const <String, ChatPhotoFile>{},
          videoTrimRangesByAssetId:
              editorResult?.videoTrimRangesByAssetId ??
              const <String, ChatVideoTrimRange>{},
        ),
      );
    } finally {
      _sending = false;

      if (mounted) {
        _schedulePendingLibraryRefresh();
      }
    }
  }

  Future<void> _openEditor() async {
    if (!isChatPhotoEditorSupported ||
        _selectedAssets.isEmpty ||
        _openingEditor ||
        _sending) {
      return;
    }

    setState(() {
      _openingEditor = true;
    });

    try {
      final ChatPhotoEditorResult? editorResult = await openChatPhotoEditor(
        context: context,
        assets: _selectedAssets,
        photoLibrary: widget.photoLibrary,
      );

      if (!mounted || editorResult == null) {
        return;
      }

      await _sendSelection(editorResult: editorResult);
    } on Object {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.mediaEditFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _openingEditor = false;
        });
        _schedulePendingLibraryRefresh();
      }
    }
  }

  String get _selectedAlbumLabel {
    final ChatPhotoAlbum? album = _selectedAlbum;

    if (album == null || album.isAll) {
      return context.l10n.recents;
    }

    return album.name;
  }

  void _toggleAlbumList() {
    setState(() {
      _albumListOpen = !_albumListOpen;
    });
  }

  Future<void> _selectAlbum(ChatPhotoAlbum album) async {
    setState(() {
      _albumListOpen = false;
    });

    if (album.id == _selectedAlbum?.id) {
      return;
    }

    await _loadFirstPage(album);
  }

  Widget _buildPhotoGridTile(
    ChatPhotoAsset asset, {
    int? selectedNumber,
    bool interactive = true,
    Uint8List? thumbnailBytes,
  }) {
    final int selectionIndex = selectedNumber == null
        ? _selectionIndex(asset)
        : -1;
    final int? resolvedSelectedNumber =
        selectedNumber ?? (selectionIndex < 0 ? null : selectionIndex + 1);

    return IgnorePointer(
      ignoring: !interactive,
      child: _PhotoGridTile(
        asset: asset,
        photoLibrary: widget.photoLibrary,
        thumbnailBytes: thumbnailBytes ?? _thumbnailBytesByAssetId[asset.id],
        onThumbnailLoaded: _cacheThumbnail,
        selectedNumber: resolvedSelectedNumber,
        singleSelection: _singleSelection,
        onTap: () {
          _toggleAsset(asset);
        },
      ),
    );
  }

  Offset _photoGridTranslation({
    required int previousIndex,
    required int nextIndex,
    required double itemStep,
  }) {
    // 카메라 셀도 실제 격자 위치에 포함해 추가·삭제 애니메이션을 맞춰요.
    previousIndex += _leadingTileCount;
    nextIndex += _leadingTileCount;
    final int previousColumn =
        previousIndex % ChatPhotoPicker._gridCrossAxisCount;
    final int previousRow =
        previousIndex ~/ ChatPhotoPicker._gridCrossAxisCount;
    final int nextColumn = nextIndex % ChatPhotoPicker._gridCrossAxisCount;
    final int nextRow = nextIndex ~/ ChatPhotoPicker._gridCrossAxisCount;

    return Offset(
      (previousColumn - nextColumn) * itemStep,
      (previousRow - nextRow) * itemStep,
    );
  }

  Widget _buildTransitionedPhotoGridTile(
    ChatPhotoAsset asset,
    int index,
    double itemStep,
  ) {
    final _PhotoGridTransition? transition = _photoGridTransition;
    final Widget tile = _buildPhotoGridTile(asset);
    final Key itemKey = ValueKey<String>('photo-grid-item-${asset.id}');

    if (transition == null) {
      return KeyedSubtree(key: itemKey, child: tile);
    }

    final int? previousIndex = transition.previousIndexes[asset.id];
    final bool entering = transition.addedAssetIds.contains(asset.id);
    final Offset initialOffset = previousIndex == null
        ? Offset.zero
        : _photoGridTranslation(
            previousIndex: previousIndex,
            nextIndex: index,
            itemStep: itemStep,
          );

    return KeyedSubtree(
      key: itemKey,
      child: AnimatedBuilder(
        animation: _assetTransitionController,
        child: tile,
        builder: (BuildContext context, Widget? child) {
          final double movementProgress = Curves.easeInOutCubic.transform(
            _assetTransitionController.value,
          );
          Widget result = Transform.translate(
            offset: Offset.lerp(initialOffset, Offset.zero, movementProgress)!,
            child: child,
          );

          if (entering) {
            final double appearanceProgress = Curves.easeOutCubic.transform(
              _assetTransitionController.value,
            );

            result = Opacity(
              opacity: appearanceProgress,
              child: Transform.scale(
                scale:
                    0.88 +
                    (ChatPhotoPicker._assetScaleChange * appearanceProgress),
                child: result,
              ),
            );
          }

          return result;
        },
      ),
    );
  }

  Widget _buildRemovedPhotoGridTile(
    _RemovedPhotoGridItem item,
    double itemExtent,
    double itemStep,
    double scrollOffset,
  ) {
    final int index = item.previousIndex + _leadingTileCount;
    final int column = index % ChatPhotoPicker._gridCrossAxisCount;
    final int row = index ~/ ChatPhotoPicker._gridCrossAxisCount;

    return Positioned(
      key: ValueKey<String>('photo-grid-removal-${item.asset.id}'),
      left: column * itemStep,
      top: (row * itemStep) - scrollOffset,
      width: itemExtent,
      height: itemExtent,
      child: AnimatedBuilder(
        animation: _assetTransitionController,
        child: _buildPhotoGridTile(
          item.asset,
          selectedNumber: item.selectedNumber,
          interactive: false,
          thumbnailBytes: item.thumbnailBytes,
        ),
        builder: (BuildContext context, Widget? child) {
          final double disappearanceProgress = Curves.easeInCubic.transform(
            _assetTransitionController.value,
          );

          return Opacity(
            opacity: 1 - disappearanceProgress,
            child: Transform.scale(
              scale:
                  1 -
                  (ChatPhotoPicker._assetScaleChange * disappearanceProgress),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double itemExtent =
            (constraints.maxWidth -
                ((ChatPhotoPicker._gridCrossAxisCount - 1) *
                    ChatPhotoPicker._gridSpacing)) /
            ChatPhotoPicker._gridCrossAxisCount;
        final double itemStep = itemExtent + ChatPhotoPicker._gridSpacing;
        final _PhotoGridTransition? transition = _photoGridTransition;
        final Map<Key, int> indexesByItemKey = <Key, int>{
          for (int index = 0; index < _assets.length; index++)
            ValueKey<String>('photo-grid-item-${_assets[index].id}'):
                index + _leadingTileCount,
          if (_leadingTileCount > 0) const ValueKey('photo-picker-camera'): 0,
        };
        final Widget grid = GridView.builder(
          key: const ValueKey<String>('photo-asset-grid'),
          controller: _gridController,
          padding: EdgeInsets.zero,
          physics: transition == null
              ? null
              : const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ChatPhotoPicker._gridCrossAxisCount,
            mainAxisSpacing: ChatPhotoPicker._gridSpacing,
            crossAxisSpacing: ChatPhotoPicker._gridSpacing,
          ),
          findChildIndexCallback: (Key key) => indexesByItemKey[key],
          itemCount: _assets.length + _leadingTileCount,
          itemBuilder: (BuildContext context, int index) {
            if (index < _leadingTileCount) {
              return Material(
                key: const ValueKey('photo-picker-camera'),
                color: AppColors.grey100,
                child: Semantics(
                  button: true,
                  label: context.l10n.camera,
                  child: InkWell(
                    onTap: widget.onCamera,
                    child: const Icon(
                      AppIcons.camera,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }
            index -= _leadingTileCount;
            return _buildTransitionedPhotoGridTile(
              _assets[index],
              index,
              itemStep,
            );
          },
        );
        final Widget interactiveGrid = IgnorePointer(
          ignoring: transition != null,
          child: grid,
        );

        if (transition == null || transition.removedItems.isEmpty) {
          return interactiveGrid;
        }

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: interactiveGrid),
            for (final _RemovedPhotoGridItem item in transition.removedItems)
              _buildRemovedPhotoGridTile(
                item,
                itemExtent,
                itemStep,
                transition.scrollOffset,
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_singleSelection) {
      return Material(
        color: AppColors.surface,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }
    final BorderRadius panelRadius = widget.expanded
        ? BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          )
        : BorderRadius.zero;

    return SizedBox.expand(
      child: DecoratedBox(
        key: const ValueKey<String>('photo-picker-boundary-effect'),
        decoration: BoxDecoration(
          borderRadius: panelRadius,
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          key: const ValueKey<String>('photo-picker'),
          color: AppColors.white,
          borderRadius: panelRadius,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              GestureDetector(
                key: const ValueKey<String>('photo-picker-handle-area'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: widget.onHandleDragStart,
                onVerticalDragUpdate: widget.onHandleDragUpdate,
                onVerticalDragEnd: widget.onHandleDragEnd,
                child: SizedBox(
                  key: const ValueKey<String>('photo-picker-handle-row'),
                  // 3배수 카카오톡 캡처에서 잰 논리 크기로 선택기 컨트롤의 비율을 맞춰요.
                  height: 20.0,
                  width: double.infinity,
                  child: Center(
                    child: Container(
                      key: const ValueKey<String>('photo-picker-handle'),
                      width: 36.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: AppColors.grey400,
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ),
              _buildHeader(),
              Expanded(child: _buildBody()),
              if (_accessState != ChatPhotoAccessState.denied)
                _buildCollageControl(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final int selectedCount = _selectedAssets.length;

    final bool canSend = selectedCount > 0 && !_sending;

    final TextStyle sendLabelStyle = AppTypography.typography6.copyWith(
      color: canSend ? AppColors.white : AppColors.grey500,
    );

    final Widget sendLabel = selectedCount == 0
        ? Text(
            context.l10n.send,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: sendLabelStyle.copyWith(fontWeight: AppTypography.bold),
          )
        : Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$selectedCount',
                  style: const TextStyle(fontWeight: AppTypography.bold),
                ),
                TextSpan(text: ' ${context.l10n.send}'),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: sendLabelStyle.copyWith(fontWeight: AppTypography.regular),
          );

    final Widget title;

    if (widget.expanded) {
      title = Material(
        key: const ValueKey<String>('photo-album-dropdown'),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadius16,
          onTap: _toggleAlbumList,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.space8,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180.0),
                  child: Text(
                    _selectedAlbumLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (_singleSelection
                                ? AppTypography.navigationTitle
                                : AppTypography.typography5)
                            .copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: AppTypography.bold,
                            ),
                  ),
                ),
                const SizedBox(width: 2.0),
                Icon(
                  _albumListOpen
                      ? AppIcons.keyboardArrowUp
                      : AppIcons.keyboardArrowDown,
                  size: 24.0,
                  color: AppColors.grey900,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      title = Text(
        context.l10n.photo,
        key: const ValueKey<String>('photo-picker-title'),
        style: AppTypography.typography6.copyWith(
          color: AppColors.textPrimary,
          fontWeight: AppTypography.bold,
        ),
      );
    }

    return SizedBox(
      key: const ValueKey<String>('photo-picker-header'),
      width: double.infinity,
      height: 52.0,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.center, child: title),
          if (!_singleSelection)
            Positioned(
              left: 2.0,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  key: const ValueKey<String>('photo-picker-close'),
                  tooltip: context.l10n.closePhotoPicker,
                  onPressed: widget.onClose,
                  icon: const Icon(
                    AppIcons.close,
                    size: 26.0,
                    color: AppColors.grey900,
                  ),
                ),
              ),
            ),
          if (!_singleSelection)
            Positioned(
              right: 10.0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  key: const ValueKey<String>('photo-picker-send'),
                  color: canSend ? AppColors.blue500 : AppColors.grey100,
                  borderRadius: AppRadius.borderRadius16,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    onTap: canSend
                        ? () {
                            unawaited(_sendSelection());
                          }
                        : null,
                    child: SizedBox(
                      width: selectedCount == 0 ? 56.0 : null,
                      height: 32.0,
                      child: Padding(
                        key: const ValueKey<String>(
                          'photo-picker-send-padding',
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: selectedCount == 0 ? 0 : 11.0,
                        ),
                        child: Center(
                          child: selectedCount == 0
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: sendLabel,
                                )
                              : sendLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_accessState == ChatPhotoAccessState.denied) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  AppIcons.photoLibrary,
                  size: 42.0,
                  color: AppColors.grey500,
                ),
                const SizedBox(height: AppSpacing.space12),
                Text(
                  context.l10n.photoAccessRequired,
                  textAlign: TextAlign.center,
                  style: AppTypography.subTypography10.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  context.l10n.photoAccessDescription,
                  textAlign: TextAlign.center,
                  style: AppTypography.subTypography11.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space16),
                TextButton(
                  onPressed: () {
                    unawaited(widget.photoLibrary.openSettings());
                  },
                  child: Text(context.l10n.openSettings),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.photoLibrary,
                size: 44.0,
                color: AppColors.grey400,
              ),
              const SizedBox(height: AppSpacing.space12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.subTypography10.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_albumListOpen) {
      return _buildAlbumList();
    }

    return Stack(
      key: const ValueKey<String>('photo-grid'),
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _buildPhotoGrid()),
        if (_loadingMore)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 14.0,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(7),
                  child: SizedBox.square(
                    dimension: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: AppColors.blue500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlbumList() {
    return ListView.separated(
      key: const ValueKey<String>('photo-album-list'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
      itemCount: _albums.length,
      separatorBuilder: (BuildContext context, int index) {
        return const Divider(
          height: 1.0,
          // 구분선을 썸네일 뒤에 있는 앨범 이름의 시작점에 맞춰요.
          indent: ChatPhotoPicker._albumThumbnailDimension + AppSpacing.space16,
          color: AppColors.grey100,
        );
      },
      itemBuilder: (BuildContext context, int index) {
        final ChatPhotoAlbum album = _albums[index];

        final String albumName = album.isAll
            ? context.l10n.recents
            : album.name;

        return InkWell(
          key: ValueKey<String>('photo-album-row-${album.id}'),
          onTap: () {
            unawaited(_selectAlbum(album));
          },
          child: SizedBox(
            height: 88.0,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.borderRadius4,
                  child: SizedBox.square(
                    dimension: ChatPhotoPicker._albumThumbnailDimension,
                    child: album.coverAssetId == null
                        ? const ColoredBox(
                            color: AppColors.grey100,
                            child: Icon(
                              AppIcons.image,
                              color: AppColors.grey500,
                            ),
                          )
                        : _PhotoThumbnail(
                            assetId: album.coverAssetId!,
                            photoLibrary: widget.photoLibrary,
                            size: 180,
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        albumName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.typography5.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        '${album.assetCount}',
                        style: AppTypography.subTypography10.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (album.id == _selectedAlbum?.id)
                  const Icon(AppIcons.check, color: AppColors.blue500),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollageControl() {
    final EdgeInsets viewPadding = MediaQuery.viewPaddingOf(context);
    final double leftPadding = viewPadding.left > AppSpacing.space12
        ? viewPadding.left
        : AppSpacing.space12;
    final double rightPadding =
        viewPadding.right > ChatPhotoPicker._photoEditButtonRight
        ? viewPadding.right
        : ChatPhotoPicker._photoEditButtonRight;
    final double editButtonBottom =
        viewPadding.bottom < ChatPhotoPicker._photoEditButtonBottom
        ? viewPadding.bottom
        : ChatPhotoPicker._photoEditButtonBottom;
    final bool canEdit =
        isChatPhotoEditorSupported &&
        _selectedAssets.isNotEmpty &&
        !_openingEditor &&
        !_sending;

    return Material(
      color: AppColors.white,
      child: SizedBox(
        key: const ValueKey<String>('photo-picker-bottom-control'),
        height: ChatPhotoPicker._collageControlHeight + viewPadding.bottom,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: leftPadding,
              right: rightPadding,
              top: 13.0,
              height: ChatPhotoPicker._collageControlHeight,
              child: SizedBox(
                key: const ValueKey<String>('photo-picker-bottom-row'),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        key: const ValueKey<String>('photo-collage-toggle'),
                        borderRadius: AppRadius.borderRadius12,
                        onTap: () {
                          setState(() {
                            _collagePhotos = !_collagePhotos;
                          });
                        },
                        child: Row(
                          children: [
                            AnimatedContainer(
                              key: const ValueKey<String>(
                                'photo-collage-check',
                              ),
                              duration: Duration(milliseconds: 140),
                              width: ChatPhotoPicker._collageIndicatorSize,
                              height: ChatPhotoPicker._collageIndicatorSize,
                              decoration: ChatPhotoPicker._selectionDecoration(
                                selected: _collagePhotos,
                                unselectedColor: AppColors.white,
                                unselectedBorderColor: AppColors.grey300,
                              ),
                              child: _collagePhotos
                                  ? const Icon(
                                      AppIcons.check,
                                      size: 16.0,
                                      color: AppColors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 7.0),
                            Text(
                              context.l10n.collagePhotos,
                              style: AppTypography.typography6.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: AppTypography.regular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: ChatPhotoPicker._photoEditButtonSize),
                  ],
                ),
              ),
            ),
            Positioned(
              right: rightPadding,
              bottom: editButtonBottom,
              child: Material(
                key: const ValueKey<String>('photo-edit-button'),
                color: canEdit ? AppColors.white : AppColors.grey100,
                elevation: 2.0,
                shadowColor: AppColors.black.withAlpha(48),
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.grey200),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: canEdit
                      ? () {
                          unawaited(_openEditor());
                        }
                      : null,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: ChatPhotoPicker._photoEditButtonSize,
                    child: Center(
                      child: AppMediaEditIcon(
                        key: const ValueKey<String>('photo-edit-icon'),
                        dimension:
                            ChatPhotoPicker._photoEditButtonSize *
                            AppMediaEditIcon.iconToButtonRatio,
                        color: canEdit ? AppColors.grey900 : AppColors.grey400,
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
}

final class _PhotoGridTransition {
  _PhotoGridTransition({
    required Map<String, int> previousIndexes,
    required Set<String> addedAssetIds,
    required List<_RemovedPhotoGridItem> removedItems,
    required this.scrollOffset,
  }) : previousIndexes = Map<String, int>.unmodifiable(previousIndexes),
       addedAssetIds = Set<String>.unmodifiable(addedAssetIds),
       removedItems = List<_RemovedPhotoGridItem>.unmodifiable(removedItems);

  final Map<String, int> previousIndexes;
  final Set<String> addedAssetIds;
  final List<_RemovedPhotoGridItem> removedItems;
  final double scrollOffset;
}

final class _RemovedPhotoGridItem {
  const _RemovedPhotoGridItem({
    required this.asset,
    required this.previousIndex,
    required this.selectedNumber,
    required this.thumbnailBytes,
  });

  final ChatPhotoAsset asset;
  final int previousIndex;
  final int? selectedNumber;
  final Uint8List? thumbnailBytes;
}

final class _PhotoGridTile extends StatelessWidget {
  const _PhotoGridTile({
    required this.asset,
    required this.photoLibrary,
    required this.thumbnailBytes,
    required this.onThumbnailLoaded,
    required this.selectedNumber,
    required this.onTap,
    this.singleSelection = false,
  });

  final bool singleSelection;
  final ChatPhotoAsset asset;
  final ChatPhotoLibrary photoLibrary;
  final Uint8List? thumbnailBytes;
  final void Function(String assetId, Uint8List bytes) onThumbnailLoaded;
  final int? selectedNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool selected = selectedNumber != null;

    return Material(
      key: ValueKey<String>('photo-tile-${asset.id}'),
      color: AppColors.grey100,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailBytes case final Uint8List bytes)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              )
            else
              _PhotoThumbnail(
                assetId: asset.id,
                photoLibrary: photoLibrary,
                size: 320,
                onLoaded: (Uint8List bytes) {
                  onThumbnailLoaded(asset.id, bytes);
                },
              ),
            if (selected)
              singleSelection
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    )
                  : ColoredBox(color: AppColors.black.withAlpha(24)),
            if (!singleSelection || selected)
              Positioned(
                top: singleSelection ? AppSpacing.space8 : 7.0,
                right: singleSelection
                    ? AppSpacing.space8
                    : ChatPhotoPicker._tileHorizontalInset,
                child: _PhotoSelectionBadge(
                  assetId: asset.id,
                  selectedNumber: selectedNumber,
                  useCheck: singleSelection,
                ),
              ),
            if (asset.isVideo)
              Positioned(
                right: ChatPhotoPicker._tileHorizontalInset,
                bottom: 6.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.black.withAlpha(138),
                    borderRadius: AppRadius.borderRadius4,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Text(
                      formatChatVideoDuration(asset.duration),
                      style: AppTypography.subTypography11.copyWith(
                        color: AppColors.white,
                        fontWeight: AppTypography.regular,
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
}

final class _PhotoSelectionBadge extends StatelessWidget {
  const _PhotoSelectionBadge({
    required this.assetId,
    required this.selectedNumber,
    this.useCheck = false,
  });

  final bool useCheck;
  final String assetId;
  final int? selectedNumber;

  @override
  Widget build(BuildContext context) {
    final int? number = selectedNumber;

    return Container(
      key: ValueKey<String>('photo-selection-badge-$assetId'),
      width: ChatPhotoPicker._selectionBadgeDimension,
      height: ChatPhotoPicker._selectionBadgeDimension,
      alignment: Alignment.center,
      decoration: ChatPhotoPicker._selectionDecoration(
        selected: number != null,
        unselectedColor: AppColors.white.withAlpha(200),
        unselectedBorderColor: AppColors.grey400,
      ),
      child: number == null
          ? null
          : useCheck
          ? const Icon(AppIcons.check, color: AppColors.white, size: 24)
          : Text(
              '$number',
              style: AppTypography.subTypography11.copyWith(
                color: AppColors.white,
                fontWeight: AppTypography.bold,
              ),
            ),
    );
  }
}

final class _PhotoThumbnail extends StatefulWidget {
  const _PhotoThumbnail({
    required this.assetId,
    required this.photoLibrary,
    required this.size,
    this.onLoaded,
  });

  final String assetId;
  final ChatPhotoLibrary photoLibrary;
  final int size;
  final ValueChanged<Uint8List>? onLoaded;

  @override
  State<_PhotoThumbnail> createState() {
    return _PhotoThumbnailState();
  }
}

final class _PhotoThumbnailState extends State<_PhotoThumbnail> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _loadThumbnail();
  }

  @override
  void didUpdateWidget(_PhotoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assetId != widget.assetId ||
        oldWidget.photoLibrary != widget.photoLibrary ||
        oldWidget.size != widget.size) {
      _thumbnailFuture = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() async {
    final Uint8List? bytes = await widget.photoLibrary.loadThumbnail(
      assetId: widget.assetId,
      width: widget.size,
      height: widget.size,
    );

    if (bytes != null) {
      widget.onLoaded?.call(bytes);
    }

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        final Uint8List? bytes = snapshot.data;

        if (bytes == null) {
          return const ColoredBox(color: AppColors.grey100);
        }

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          // 참고 영상의 썸네일 페이드는 약 233ms로, 격자 이동 시간과 따로 유지해요.
          duration: Duration(milliseconds: 233),
          curve: Curves.easeInOut,
          builder: (BuildContext context, double opacity, Widget? child) {
            return Opacity(
              key: ValueKey<String>(
                'photo-thumbnail-opacity-${widget.assetId}',
              ),
              opacity: opacity,
              child: child,
            );
          },
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          ),
        );
      },
    );
  }
}
