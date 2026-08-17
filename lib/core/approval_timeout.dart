int? parseApprovalTimeoutInput(String input) {
  var value = input.trim().toLowerCase();
  if (value.isEmpty) return null;

  value = value
      .replaceAll('ثواني', 's')
      .replaceAll('ثانية', 's')
      .replaceAll('ث', 's')
      .replaceAll('دقائق', 'm')
      .replaceAll('دقيقة', 'm')
      .replaceAll('د', 'm')
      .replaceAll('ساعات', 'h')
      .replaceAll('ساعة', 'h')
      .replaceAll('س', 'h')
      .replaceAll(RegExp(r'\s+'), '');

  final match = RegExp(r'^(\d+)(s|m|h)?$').firstMatch(value);
  if (match == null) return null;

  final amount = int.tryParse(match.group(1)!);
  if (amount == null) return null;
  final unit = match.group(2) ?? 's';
  final seconds = switch (unit) {
    'm' => amount * 60,
    'h' => amount * 60 * 60,
    _ => amount,
  };
  if (seconds < 5 || seconds > 86400) return null;
  return seconds;
}

String formatApprovalTimeout(int seconds) {
  if (seconds % 3600 == 0) {
    final hours = seconds ~/ 3600;
    return hours == 1 ? 'ساعة واحدة' : '$hours ساعات';
  }
  if (seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return minutes == 1 ? 'دقيقة واحدة' : '$minutes دقائق';
  }
  return '$seconds ثانية';
}
