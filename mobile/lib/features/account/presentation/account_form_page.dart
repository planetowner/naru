import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/components/app_navigation_bar.dart';

// 설정과 언어 선택은 같은 여백·하단 버튼 위치를 쓰고 키보드가 뜨면 함께 스크롤해요.
final class AccountFormPage extends StatelessWidget {
  const AccountFormPage({
    required this.title,
    required this.content,
    required this.action,
    this.busy = false,
    super.key,
  });
  final String title;
  final Widget content;
  final Widget action;
  final bool busy;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppNavigationBar(
              title: title,
              backTooltip: context.l10n.back,
              onBack: () {
                if (!busy) Navigator.of(context).pop();
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 480,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space24),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              content,
                              const Spacer(),
                              const SizedBox(height: AppSpacing.space24),
                              action,
                            ],
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
