import 'package:flutter/services.dart';

class BirthDateTextInputFormatter extends TextInputFormatter {
  const BirthDateTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = normalizeBirthDateForInput(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String normalizeBirthDateForInput(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (isoMatch != null) {
    return '${isoMatch.group(3)} / ${isoMatch.group(2)} / ${isoMatch.group(1)}';
  }

  final dmyMatch = RegExp(
    r'^(\d{2})\s*/\s*(\d{2})\s*/\s*(\d{4})$',
  ).firstMatch(trimmed);
  if (dmyMatch != null) {
    return '${dmyMatch.group(1)} / ${dmyMatch.group(2)} / ${dmyMatch.group(3)}';
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length && i < 8; i++) {
    if (i == 2 || i == 4) {
      buffer.write(' / ');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String birthDateInputToIso(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (isoMatch != null) return trimmed;

  final dmyMatch = RegExp(
    r'^(\d{2})\s*/\s*(\d{2})\s*/\s*(\d{4})$',
  ).firstMatch(trimmed);
  if (dmyMatch != null) {
    return '${dmyMatch.group(3)}-${dmyMatch.group(2)}-${dmyMatch.group(1)}';
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return trimmed;
  return '${digits.substring(4, 8)}-${digits.substring(2, 4)}-${digits.substring(0, 2)}';
}
