class AustralianPhoneNumber {
  AustralianPhoneNumber._(this.localDigits);

  static const int localLength = 10;
  static const int internationalLength = 9;
  static const String countryCode = '+61';
  static const String localPlaceholder = '(0X) XXXX XXXX';
  static const String internationalPlaceholder = '+61 X XXXX XXXX';

  static const Set<String> _validPrefixes = <String>{'2', '3', '4', '7', '8'};

  final String localDigits;

  String get nationalDigits => localDigits.substring(1);
  String get storageFormat => '$countryCode$nationalDigits';
  String get localDisplay => formatLocalDigits(localDigits);
  String get internationalDisplay => formatInternationalDigits(nationalDigits);

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static AustralianPhoneNumber? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final digits = digitsOnly(trimmed);
    if (digits.length == localLength && _isValidLocalDigits(digits)) {
      return AustralianPhoneNumber._(digits);
    }

    if (trimmed.startsWith(countryCode) ||
        (digits.startsWith('61') && digits.length == 11)) {
      final internationalDigits =
          digits.startsWith('61') ? digits.substring(2) : digits;
      if (internationalDigits.length == internationalLength &&
          _isValidInternationalDigits(internationalDigits)) {
        return AustralianPhoneNumber._('0$internationalDigits');
      }
    }

    return null;
  }

  static String? normalizeToStorageFormat(String input) {
    return tryParse(input)?.storageFormat;
  }

  static String formatForDisplay(
    String? input, {
    String emptyFallback = '',
    bool preferInternational = false,
  }) {
    final trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) {
      return emptyFallback;
    }

    final parsed = tryParse(trimmed);
    if (parsed == null) {
      return trimmed;
    }

    return preferInternational
        ? parsed.internationalDisplay
        : parsed.localDisplay;
  }

  static List<String> lookupVariants(String input) {
    final parsed = tryParse(input);
    if (parsed == null) {
      final raw = input.trim();
      return raw.isEmpty ? <String>[] : <String>[raw];
    }

    return {
      parsed.storageFormat,
      parsed.localDigits,
      formatLocalDigits(parsed.localDigits),
      formatInternationalDigits(parsed.nationalDigits),
    }.toList();
  }

  static bool isValidPhoneNumber(String input) => tryParse(input) != null;

  static bool isValidLocalDigits(String digits) => _isValidLocalDigits(digits);

  static bool isValidInternationalDigits(String digits) =>
      _isValidInternationalDigits(digits);

  static String formatLocalDigits(String digits) {
    if (digits.isEmpty) {
      return localPlaceholder;
    }

    final buffer = StringBuffer();
    final prefixLength = digits.length >= 2 ? 2 : digits.length;
    buffer.write('(');
    buffer.write(digits.substring(0, prefixLength));
    if (digits.length >= 2) {
      buffer.write(')');
    }

    if (digits.length > 2) {
      final middleEnd = digits.length >= 6 ? 6 : digits.length;
      buffer.write(' ');
      buffer.write(digits.substring(2, middleEnd));
    }

    if (digits.length > 6) {
      buffer.write(' ');
      buffer.write(digits.substring(6));
    }

    return buffer.toString();
  }

  static String formatInternationalDigits(String digits) {
    if (digits.isEmpty) {
      return internationalPlaceholder;
    }

    final buffer = StringBuffer(countryCode);
    final firstBlockEnd = digits.isNotEmpty ? 1 : 0;
    if (firstBlockEnd > 0) {
      buffer.write(' ');
      buffer.write(digits.substring(0, firstBlockEnd));
    }

    if (digits.length > 1) {
      final middleEnd = digits.length >= 5 ? 5 : digits.length;
      buffer.write(' ');
      buffer.write(digits.substring(1, middleEnd));
    }

    if (digits.length > 5) {
      buffer.write(' ');
      buffer.write(digits.substring(5));
    }

    return buffer.toString();
  }

  static String? validationErrorForDigits(
    String digits, {
    required bool internationalMode,
  }) {
    if (digits.isEmpty) {
      return null;
    }

    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      return 'Use digits only for Australian phone numbers.';
    }

    if (internationalMode) {
      if (digits.length > internationalLength) {
        return 'Australian +61 numbers use 9 digits after the country code.';
      }
      if (digits.isNotEmpty && !_validPrefixes.contains(digits[0])) {
        return 'After +61, Australian numbers must start with 2, 3, 4, 7, or 8.';
      }
      return null;
    }

    if (digits[0] != '0') {
      return 'Australian local numbers must start with 0.';
    }
    if (digits.length >= 2 && !_validPrefixes.contains(digits[1])) {
      return 'Australian numbers must start with 02, 03, 04, 07, or 08.';
    }
    if (digits.length > localLength) {
      return 'Australian local numbers must be exactly 10 digits.';
    }
    return null;
  }

  static String submitErrorMessage({required bool internationalMode}) {
    if (internationalMode) {
      return 'Enter a valid Australian number as +61 X XXXX XXXX using 9 digits after +61.';
    }
    return 'Enter a valid Australian number as (0X) XXXX XXXX using 10 digits starting with 02, 03, 04, 07, or 08.';
  }

  static bool _isValidLocalDigits(String digits) {
    return RegExp(r'^0[23478]\d{8}$').hasMatch(digits);
  }

  static bool _isValidInternationalDigits(String digits) {
    return RegExp(r'^[23478]\d{8}$').hasMatch(digits);
  }
}
