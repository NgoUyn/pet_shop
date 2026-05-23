import 'package:flutter/services.dart';

String formatVndAmount(num value) {
  final digits = value.round().toString();
  return _formatDigits(digits);
}

int? parseVndAmount(String? text) {
  final normalized = (text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    return null;
  }
  return int.tryParse(normalized);
}

class VndCurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final formatted = _formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatDigits(String digits) {
  if (digits.isEmpty) {
    return '';
  }

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}