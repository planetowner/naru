import 'package:flutter/material.dart';

import '../../../design_system/app_spacing.dart';
import '../../../design_system/components/app_selection_tile.dart';
import '../domain/app_language.dart';

// 가입과 설정에서 언어 순서·표시 이름·선택 영역을 함께 관리해요.
final class AppLanguagePicker extends StatelessWidget {
  const AppLanguagePicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final AppLanguage? selected;
  final ValueChanged<AppLanguage>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final language in AppLanguage.values) ...[
        if (language != AppLanguage.values.first)
          const SizedBox(height: AppSpacing.space4),
        AppSelectionTile(
          label: language.label,
          selected: selected == language,
          onTap: onChanged == null ? null : () => onChanged!(language),
        ),
      ],
    ],
  );
}
