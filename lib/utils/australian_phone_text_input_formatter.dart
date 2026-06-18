import 'package:flutter/services.dart';

import 'australian_phone_number.dart';

class AustralianLocalPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = AustralianPhoneNumber.digitsOnly(newValue.text);
    final limitedDigits = digits.length > AustralianPhoneNumber.localLength
        ? digits.substring(0, AustralianPhoneNumber.localLength)
        : digits;
    final formatted = AustralianPhoneNumber.formatLocalDigits(limitedDigits);

    return TextEditingValue(
      text:
          formatted == AustralianPhoneNumber.localPlaceholder ? '' : formatted,
      selection: TextSelection.collapsed(
        offset: formatted == AustralianPhoneNumber.localPlaceholder
            ? 0
            : formatted.length,
      ),
    );
  }
}
