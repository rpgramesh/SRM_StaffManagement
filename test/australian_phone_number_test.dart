import 'package:flutter_test/flutter_test.dart';
import 'package:staff_management_app/utils/australian_phone_number.dart';

void main() {
  group('AustralianPhoneNumber', () {
    test('formats local landline and mobile numbers', () {
      expect(
        AustralianPhoneNumber.formatLocalDigits('0212345678'),
        '(02) 1234 5678',
      );
      expect(
        AustralianPhoneNumber.formatLocalDigits('0412345678'),
        '(04) 1234 5678',
      );
    });

    test('formats +61 international numbers', () {
      expect(
        AustralianPhoneNumber.formatInternationalDigits('212345678'),
        '+61 2 1234 5678',
      );
      expect(
        AustralianPhoneNumber.formatInternationalDigits('412345678'),
        '+61 4 1234 5678',
      );
    });

    test('normalizes valid local and international input to +61 storage', () {
      expect(
        AustralianPhoneNumber.normalizeToStorageFormat('0412 345 678'),
        '+61412345678',
      );
      expect(
        AustralianPhoneNumber.normalizeToStorageFormat('+61 2 1234 5678'),
        '+61212345678',
      );
    });

    test('formats stored Australian numbers for user-facing display', () {
      expect(
        AustralianPhoneNumber.formatForDisplay('+61412345678'),
        '(04) 1234 5678',
      );
      expect(
        AustralianPhoneNumber.formatForDisplay(
          '+61212345678',
          preferInternational: true,
        ),
        '+61 2 1234 5678',
      );
      expect(
        AustralianPhoneNumber.formatForDisplay('', emptyFallback: 'N/A'),
        'N/A',
      );
    });

    test('validates required Australian prefixes and lengths', () {
      expect(AustralianPhoneNumber.isValidPhoneNumber('0212345678'), isTrue);
      expect(AustralianPhoneNumber.isValidPhoneNumber('+61212345678'), isTrue);
      expect(AustralianPhoneNumber.isValidPhoneNumber('0412345678'), isTrue);
      expect(AustralianPhoneNumber.isValidPhoneNumber('+61412345678'), isTrue);

      expect(AustralianPhoneNumber.isValidPhoneNumber('0512345678'), isFalse);
      expect(AustralianPhoneNumber.isValidPhoneNumber('+61512345678'), isFalse);
      expect(AustralianPhoneNumber.isValidPhoneNumber('021234567'), isFalse);
      expect(AustralianPhoneNumber.isValidPhoneNumber('+6121234567'), isFalse);
    });
  });
}
