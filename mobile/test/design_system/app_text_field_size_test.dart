import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/design_system/components/app_text_field.dart';

import '../support/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets(
    'Auto line height keeps every input border at 46 with errors below',
    (tester) async {
      final form = GlobalKey<FormState>();
      final controllers = List.generate(3, (_) => TextEditingController());
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Form(
              key: form,
              child: Column(
                children: [
                  for (int i = 0; i < controllers.length; i++)
                    AppTextField(
                      controller: controllers[i],
                      labelText: '입력 $i',
                      hintText: '이름을 입력해 주세요',
                      prefixIcon: i == 1 ? const Icon(Icons.search) : null,
                      suffixIcon: i == 2 ? const Icon(Icons.visibility) : null,
                      validator: (_) => '입력해 주세요',
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      void expectBorders() {
        for (final element in find.byType(EditableText).evaluate()) {
          expect(
            InputDecorator.containerOf(element)!.size.height,
            closeTo(46, 0.01),
          );
        }
      }

      expectBorders();
      form.currentState!.validate();
      await tester.pumpAndSettle();
      expectBorders();
      expect(find.text('입력해 주세요'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
}
