/// Unified price formatting helper.
/// Formats a double value to Vietnamese đồng format, e.g. 9.000.000đ
String formatPrice(double value) {
  final formatted = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < formatted.length; i++) {
    final fromEnd = formatted.length - i;
    buffer.write(formatted[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return '${buffer}đ';
}

/// Formats age in months to a human-readable Vietnamese string.
String formatAge(int? age) {
  if (age == null) return '';
  if (age < 12) return '$age tháng';
  final years = age ~/ 12;
  final months = age % 12;
  if (months == 0) return '$years năm';
  return '$years.${(months * 10 ~/ 12)} năm';
}

/// Returns true when gender string indicates male.
bool isMale(String gender) {
  final g = gender.toLowerCase().trim();
  return g == 'đực' || g == 'male' || g == 'm' || g == 'nam';
}

/// Returns a human-readable gender label.
String genderLabel(String? gender) {
  final normalized = (gender ?? '').trim();
  if (normalized.isEmpty) return 'Chưa rõ giới tính';
  final lower = normalized.toLowerCase();
  if (lower.contains('female') || lower.contains('cái')) return 'Cái';
  if (lower.contains('male') || lower.contains('đực')) return 'Đực';
  return normalized;
}
