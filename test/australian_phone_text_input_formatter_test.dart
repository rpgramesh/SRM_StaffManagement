import 'package:flutter_test/flutter_test.dart';
import 'package:staff_management_app/utils/australian_phone_text_input_formatter.dart';

void main() {
  group('AustralianLocalPhoneInputFormatter', () {
    final formatter = AustralianLocalPhoneInputFormatter();

    test('formats Australian local input as the user types', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '0412345678'),
      );

      expect(result.text, '(04) 1234 5678');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('strips non-digits and keeps the 10-digit limit', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '04 1234 56789'),
      );

      expect(result.text, '(04) 1234 5678');
    });
  });
}
