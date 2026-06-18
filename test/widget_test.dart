import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staff_management_app/screens/auth/staff_login_screen.dart';
import 'package:staff_management_app/screens/auth/staff_pin_screen.dart';

void main() {
  Future<void> pumpLoginScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaffLoginScreen(),
      ),
    );
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String keyId) async {
    final finder = find.byKey(ValueKey('phone-key-$keyId'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 160));
  }

  Future<void> pressKeyboardKey(
      WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump(const Duration(milliseconds: 175));
  }

  Future<void> pumpPinScreen(
    WidgetTester tester, {
    ValueChanged<String>? onPinComplete,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StaffPinScreen(
          phoneNumber: '+911234567890',
          onPinComplete: onPinComplete,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapPinKey(WidgetTester tester, String keyId) async {
    final finder = find.byKey(ValueKey('pin-key-$keyId'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 160));
  }

  testWidgets('on-screen keypad formats digits and supports delete and clear',
      (WidgetTester tester) async {
    await pumpLoginScreen(tester);

    for (final digit in <String>['0', '2', '1', '2', '3', '4']) {
      await tapKey(tester, digit);
    }

    expect(find.text('(02) 1234'), findsOneWidget);

    await tapKey(tester, 'backspace');
    expect(find.text('(02) 123'), findsOneWidget);

    await tapKey(tester, 'clear');
    expect(find.text('(0X) XXXX XXXX'), findsOneWidget);
  });

  testWidgets('physical keyboard input updates digits and ignores invalid keys',
      (WidgetTester tester) async {
    await pumpLoginScreen(tester);

    await tester.tap(find.byKey(const ValueKey('phone-number-display')));
    await tester.pump();

    await pressKeyboardKey(tester, LogicalKeyboardKey.digit0);
    await pressKeyboardKey(tester, LogicalKeyboardKey.numpad4);
    await pressKeyboardKey(tester, LogicalKeyboardKey.keyA);

    expect(find.text('(04)'), findsOneWidget);

    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
    ]) {
      await pressKeyboardKey(tester, key);
    }

    expect(find.text('(04) 1234 5678'), findsOneWidget);

    await pressKeyboardKey(tester, LogicalKeyboardKey.digit1);
    expect(find.text('(04) 1234 5678'), findsOneWidget);

    await pressKeyboardKey(tester, LogicalKeyboardKey.backspace);
    expect(find.text('(04) 1234 567'), findsOneWidget);
  });

  testWidgets('phone keypad supports Australian international +61 mode',
      (WidgetTester tester) async {
    await pumpLoginScreen(tester);

    await tester.tap(find.byKey(const ValueKey('phone-mode-international')));
    await tester.pump();

    for (final digit in <String>['4', '1', '2', '3', '4', '5']) {
      await tapKey(tester, digit);
    }

    expect(find.text('+61 4 1234 5'), findsOneWidget);

    for (final digit in <String>['6', '7', '8']) {
      await tapKey(tester, digit);
    }

    expect(find.text('+61 4 1234 5678'), findsOneWidget);
  });

  testWidgets(
      'phone keypad shows Australian validation errors for invalid prefixes',
      (WidgetTester tester) async {
    await pumpLoginScreen(tester);

    await tapKey(tester, '0');
    await tapKey(tester, '5');

    expect(
      find.text('Australian numbers must start with 02, 03, 04, 07, or 08.'),
      findsOneWidget,
    );
  });

  testWidgets('PIN keypad supports taps, delete, and max length completion',
      (WidgetTester tester) async {
    String? completedPin;
    await pumpPinScreen(
      tester,
      onPinComplete: (pin) => completedPin = pin,
    );

    for (final digit in <String>['1', '2', '3']) {
      await tapPinKey(tester, digit);
    }
    expect(find.text('3/6 digits'), findsOneWidget);

    await tapPinKey(tester, 'backspace');
    expect(find.text('2/6 digits'), findsOneWidget);

    for (final digit in <String>['4', '5', '6', '7']) {
      await tapPinKey(tester, digit);
    }

    expect(find.text('6/6 digits'), findsOneWidget);
    expect(completedPin, '124567');

    await tapPinKey(tester, '8');
    expect(find.text('6/6 digits'), findsOneWidget);
    expect(completedPin, '124567');
  });

  testWidgets(
      'PIN keypad supports physical keyboard digits, delete, and blocks invalid keys',
      (WidgetTester tester) async {
    await pumpPinScreen(tester);

    await tester.tap(find.byKey(const ValueKey('pin-entry-display')));
    await tester.pump();

    await pressKeyboardKey(tester, LogicalKeyboardKey.digit9);
    await pressKeyboardKey(tester, LogicalKeyboardKey.numpad8);
    await pressKeyboardKey(tester, LogicalKeyboardKey.keyA);
    expect(find.text('2/6 digits'), findsOneWidget);

    await pressKeyboardKey(tester, LogicalKeyboardKey.delete);
    expect(find.text('1/6 digits'), findsOneWidget);

    await pressKeyboardKey(tester, LogicalKeyboardKey.digit7);
    await pressKeyboardKey(tester, LogicalKeyboardKey.digit6);
    expect(find.text('3/6 digits'), findsOneWidget);
  });
}
