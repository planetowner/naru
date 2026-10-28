part of 'chat_conversation_view.dart';

// 채팅의 썸네일·영상 다운로드·링크 열기를 그대로 공유하기 위해 같은 라이브러리에 둬요.

final class _ChatSearchTopBar extends StatelessWidget {
  static const EdgeInsets _inputPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.space16,
    vertical: AppSpacing.space12,
  );

  static const double _inputIconDimension = 20;

  static const EdgeInsets _rowPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.space16,
  );

  static const double _tabHeight = 44;

  static const double _dividerThickness = 1;

  static const double _statusHeight = 32;

  // 안내 줄 아래에도 기존 페이드 여유 공간을 남겨요.
  static double _tabsHeightFor({required bool showStatus}) =>
      _tabHeight +
      _dividerThickness +
      AppSpacing.space12 +
      (showStatus ? _statusHeight : 0);

  const _ChatSearchTopBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onCancel,
    required this.category,
    required this.onCategoryChanged,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });
  // 실제 배치와 가려지는 높이가 같은 치수를 사용해요.
  static double heightFor({required bool loading, required bool failed}) =>
      AppNavigationBar.height +
      AppControlStyle.height +
      _inputPadding.vertical +
      _tabsHeightFor(
        showStatus: _showsStatus(loading: loading, failed: failed),
      );

  // 높이 계산과 안내 줄 표시가 같은 상태 조건을 사용해요.
  static bool _showsStatus({required bool loading, required bool failed}) =>
      loading || failed;

  bool get showStatus => _showsStatus(loading: loading, failed: failed);
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final ChatSearchCategory category;
  final ValueChanged<ChatSearchCategory> onCategoryChanged;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('chat-search-top-bar'),
    type: MaterialType.transparency,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: AppColors.white,
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppNavigationBar(
                  title: 'Search chat',
                  backTooltip: 'Close search',
                  onBack: onCancel,
                ),
                Padding(
                  padding: _inputPadding,
                  child: AppTextField(
                    inputKey: const ValueKey('chat-search-input'),
                    controller: controller,
                    focusNode: focusNode,
                    hintText: category.hint,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: onChanged,
                    onFieldSubmitted: onSubmitted,
                    prefixIcon: const Icon(
                      AppIcons.search,
                      size: _inputIconDimension,
                    ),
                    suffixIcon: hasText
                        ? IconButton(
                            tooltip: 'Clear search',
                            onPressed: onClear,
                            icon: const Icon(
                              AppIcons.close,
                              size: _inputIconDimension,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 제목·입력은 읽기 쉽게 가리고, 탭 아래는 채팅 상단과 같은 페이드를 사용해요.
        _TranslucentTopBarSurface(
          height: _tabsHeightFor(showStatus: showStatus),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: _rowPadding,
                child: Row(
                  children: [
                    for (final tab in ChatSearchCategory.values)
                      Expanded(
                        child: Semantics(
                          selected: category == tab,
                          button: true,
                          child: InkWell(
                            key: ValueKey('chat-search-tab-${tab.name}'),
                            onTap: () => onCategoryChanged(tab),
                            child: Container(
                              height: _tabHeight,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    width: 2.0,
                                    color: (category == tab)
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Text(
                                tab.label,
                                style: AppTypography.body.copyWith(
                                  color: (category == tab)
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: (category == tab)
                                      ? AppTypography.bold
                                      : AppTypography.regular,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(
                height: _dividerThickness,
                thickness: _dividerThickness,
                color: AppColors.divider,
              ),
              if (showStatus)
                SizedBox(
                  height: _statusHeight,
                  child: Padding(
                    padding: _rowPadding,
                    child: Row(
                      children: [
                        if (loading) ...[
                          const SizedBox.square(
                            dimension: 12.0,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          ),
                          const SizedBox(width: AppSpacing.space8),
                          const Expanded(
                            child: Text(
                              'Searching chat history…',
                              style: AppTypography.caption,
                            ),
                          ),
                        ] else if (failed) ...[
                          const Expanded(
                            child: Text(
                              'Couldn’t load all messages',
                              style: AppTypography.caption,
                            ),
                          ),
                          TextButton(
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _ChatSearchAttachments extends StatelessWidget {
  const _ChatSearchAttachments({
    required this.category,
    required this.entries,
    required this.mediaFilter,
    required this.onMediaFilterChanged,
    required this.selectedDate,
    required this.onDatePressed,
    required this.onClearDate,
    required this.hasQuery,
    required this.loading,
    required this.failed,
    required this.onClear,
    required this.currentUserId,
    required this.otherParticipantName,
    required this.onCreateThumbnailAccessUrl,
    required this.onCreateMediaAssetAccessUrl,
    required this.onPhotoTap,
    required this.onVideoTap,
    required this.onFileTap,
    required this.onBackgroundTap,
  });
  final ChatSearchCategory category;
  final List<ChatSearchEntry> entries;
  final ChatSearchMediaFilter mediaFilter;
  final ValueChanged<ChatSearchMediaFilter> onMediaFilterChanged;
  final DateTime? selectedDate;
  final VoidCallback onDatePressed;
  final VoidCallback onClearDate;
  final bool hasQuery;
  final bool loading;
  final bool failed;
  final VoidCallback onClear;
  final String currentUserId;
  final String otherParticipantName;
  final ChatMediaAssetAccessUrlCreator? onCreateThumbnailAccessUrl;
  final ChatMediaAssetAccessUrlCreator? onCreateMediaAssetAccessUrl;
  final _PhotoMessageTapCallback onPhotoTap;
  final _VideoMessageTapCallback onVideoTap;
  final ValueChanged<ChatMessage> onFileTap;
  final VoidCallback onBackgroundTap;

  @override
  Widget build(BuildContext context) {
    final bool media = category == ChatSearchCategory.media;
    final Map<DateTime, List<ChatSearchEntry>> groups = {};
    if (media) {
      for (final entry in entries) {
        groups
            .putIfAbsent(_dateOnly(entry.message.createdAt), () => [])
            .add(entry);
      }
    }
    return Material(
      color: AppColors.white,
      child: Column(
        children: [
          // 자료 탭이 바뀌어도 날짜 버튼의 위치와 크기는 같아야 해요.
          SizedBox(
            height: 56.0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.space16),
              child: Row(
                children: [
                  Expanded(
                    child: media
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final filter
                                    in ChatSearchMediaFilter.values) ...[
                                  _SearchFilterChip(
                                    label: switch (filter) {
                                      ChatSearchMediaFilter.all => 'All',
                                      ChatSearchMediaFilter.photos => 'Photos',
                                      ChatSearchMediaFilter.videos => 'Videos',
                                    },
                                    selected: mediaFilter == filter,
                                    onPressed: () =>
                                        onMediaFilterChanged(filter),
                                  ),
                                  const SizedBox(width: AppSpacing.space8),
                                ],
                              ],
                            ),
                          )
                        : Text(
                            'Newest first',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  AppIconButton(
                    icon: AppIcons.calendar,
                    tooltip: 'Filter by date',
                    onPressed: onDatePressed,
                  ),
                ],
              ),
            ),
          ),
          if (selectedDate != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
                vertical: AppSpacing.space8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SearchFilterChip(
                  label: MaterialLocalizations.of(
                    context,
                  ).formatShortMonthDay(selectedDate!.toLocal()),
                  selected: true,
                  onPressed: onClearDate,
                  trailingIcon: AppIcons.close,
                  tooltip: 'Clear date filter',
                ),
              ),
            ),
          Expanded(
            child: entries.isEmpty
                ? _SearchEmptyState(
                    category: category,
                    loading: loading,
                    failed: failed,
                    hasQuery: hasQuery,
                    hasDate: selectedDate != null,
                    onClear: () {
                      onClear();
                      onClearDate();
                    },
                  )
                : CustomScrollView(
                    key: ValueKey('chat-search-${category.name}-results'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (media)
                        for (final group in groups.entries) ...[
                          _heading(
                            _shortDate(context, group.key),
                            '${group.value.length} items',
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.space16,
                              0,
                              AppSpacing.space16,
                              AppSpacing.space12,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: AppSpacing.space8,
                                    crossAxisSpacing: AppSpacing.space8,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _mediaTile(group.value[index]),
                                childCount: group.value.length,
                              ),
                            ),
                          ),
                        ]
                      else ...[
                        _heading(
                          hasQuery
                              ? '${entries.length} results'
                              : category == ChatSearchCategory.links
                              ? 'Shared links'
                              : 'Shared files',
                          hasQuery ? '' : '${entries.length} ${category.name}',
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.space16,
                            0,
                            AppSpacing.space16,
                            AppSpacing.space16,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: AppSpacing.space12,
                                  crossAxisSpacing: AppSpacing.space12,
                                  mainAxisExtent: _SearchResultCard.heightFor(
                                    MediaQuery.textScalerOf(context),
                                  ),
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _card(context, entries[index]),
                              childCount: entries.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
  Widget _heading(String title, String detail) => SliverPadding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.space16,
      AppSpacing.space8,
      AppSpacing.space16,
      AppSpacing.space12,
    ),
    sliver: SliverToBoxAdapter(
      child: Row(
        children: [
          Expanded(child: Text(title, style: _SearchResultCard._titleLabel)),
          Text(
            detail,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _mediaTile(ChatSearchEntry entry) => LayoutBuilder(
    builder: (context, constraints) {
      final Size size = Size.square(constraints.maxWidth);
      if (entry.video != null) {
        return _VideoMessage(
          key: ValueKey('search-media-${entry.id}'),
          message: entry.message,
          isOutgoing: entry.message.senderId == currentUserId,
          measurementKey: ValueKey('search-video-${entry.id}'),
          onCreateMediaAssetAccessUrl: onCreateMediaAssetAccessUrl,
          onCreateThumbnailAccessUrl: onCreateThumbnailAccessUrl,
          onVideoTap: onVideoTap,
          searchTileSize: size,
        );
      }
      return Semantics(
        button: true,
        label: entry.title,
        child: InkWell(
          key: ValueKey('search-media-${entry.id}'),
          onTap: () {
            onBackgroundTap();
            onPhotoTap(entry.message, entry.photoIndex!);
          },
          child: ClipRRect(
            borderRadius: AppRadius.borderRadius12,
            child: _PhotoMessageImage(
              attachment: entry.photo!,
              itemIndex: entry.photoIndex!,
              width: size.width,
              height: size.height,
              onCreateMediaAssetAccessUrl: onCreateThumbnailAccessUrl,
              persistToDisk: true,
              placeholderColor: AppColors.grey100,
            ),
          ),
        ),
      );
    },
  );

  Widget _card(BuildContext context, ChatSearchEntry entry) {
    final ChatLinkPreview? link = entry.link;
    final ChatFileAttachment? file = entry.file;
    final String extension = file == null || !file.name.contains('.')
        ? 'FILE'
        : file.name.split('.').last.toUpperCase();
    final String meta =
        link?.domain ?? '$extension · ${_formatFileSize(file!.sizeBytes)}';
    return _SearchResultCard(
      key: ValueKey('search-card-${entry.id}'),
      title: entry.title,
      meta: meta,
      isLink: link != null,
      sender:
          '${entry.message.senderId == currentUserId ? 'You' : otherParticipantName} · ${_shortDate(context, entry.message.createdAt)}',
      preview: link != null
          ? LayoutBuilder(
              builder: (context, constraints) => _LinkPreviewImage(
                preview: link,
                width: constraints.maxWidth,
                height: _SearchResultCard._cardPreviewHeight,
              ),
            )
          : const Center(
              child: Icon(
                AppIcons.file,
                size: 32.0,
                color: AppColors.textPrimary,
              ),
            ),
      onTap: () {
        onBackgroundTap();
        if (link != null) {
          final Uri? uri = _linkPreviewLaunchUri(link);
          if (uri != null) unawaited(_openChatWebUri(context, uri));
        } else {
          onFileTap(entry.message);
        }
      },
    );
  }
}

final class _SearchFilterChip extends StatelessWidget {
  const _SearchFilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.trailingIcon,
    this.tooltip,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? trailingIcon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected
        ? AppColors.primary
        : AppColors.textSecondary;
    final Widget chip = Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryMuted : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusFull,
          side: BorderSide(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.borderRadiusFull,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space12,
              vertical: AppSpacing.space8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.body.copyWith(color: foreground),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: AppSpacing.space8),
                  Icon(trailingIcon, size: 20, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

final class _SearchResultCard extends StatelessWidget {
  // 카드 높이 계산과 실제 미리보기가 같은 높이를 사용해요.
  static const double _cardPreviewHeight = 104;

  static const double _textScaleReferenceSize = 14;

  static double heightFor(TextScaler textScaler) {
    // 기존 14 기준 확대 비율을 설명 영역에만 적용해요.
    return _cardPreviewHeight +
        128.0 *
            textScaler.scale(_textScaleReferenceSize) /
            _textScaleReferenceSize;
  }

  // 목록 제목과 카드 제목은 같은 본문 굵기를 사용해요.
  static final TextStyle _titleLabel = AppTypography.body.copyWith(
    fontWeight: AppTypography.bold,
  );

  static final TextStyle _metadataLabel = AppTypography.caption.copyWith(
    color: AppColors.textSecondary,
  );

  const _SearchResultCard({
    required this.title,
    required this.meta,
    required this.sender,
    required this.isLink,
    required this.preview,
    required this.onTap,
    super.key,
  });
  final String title;
  final String meta;
  final String sender;
  final bool isLink;
  final Widget preview;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.borderRadius16,
      side: BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _cardPreviewHeight,
            child: ColoredBox(color: AppColors.grey100, child: preview),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _titleLabel,
                  ),
                  const Spacer(),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isLink
                        ? _metadataLabel.copyWith(color: AppColors.primary)
                        : _metadataLabel,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    sender,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _metadataLabel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.category,
    required this.loading,
    required this.failed,
    required this.hasQuery,
    required this.hasDate,
    required this.onClear,
  });
  final ChatSearchCategory category;
  final bool loading;
  final bool failed;
  final bool hasQuery;
  final bool hasDate;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    final String name = category == ChatSearchCategory.media
        ? 'photos or videos'
        : category.name;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.blue50,
                borderRadius: AppRadius.borderRadius16,
              ),
              child: const Icon(
                AppIcons.search,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              loading
                  ? 'Searching chat history…'
                  : failed
                  ? 'Search is incomplete'
                  : 'No $name found',
              textAlign: TextAlign.center,
              style: AppTypography.screenTitle,
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              loading
                  ? 'Results will appear as messages load.'
                  : failed
                  ? 'Retry to include the rest of this chat.'
                  : hasQuery || hasDate
                  ? 'Try a different search or date.'
                  : 'Shared $name will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (hasQuery || hasDate) ...[
              const SizedBox(height: AppSpacing.space12),
              AppButton(
                label: 'Clear search',
                onPressed: onClear,
                secondary: true,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
