int? parseApprovalTimeoutInput(String input) {
  var value = _normalizeDigits(input.trim().toLowerCase());
  if (value.isEmpty) return null;
  value = value.replaceAll(RegExp(r'\s+'), '');

  final match = RegExp(r'^(\d+)(.*)$').firstMatch(value);
  if (match == null) return null;

  final amount = int.tryParse(match.group(1)!);
  if (amount == null) return null;
  final unit = match.group(2) ?? '';
  final multiplier = switch (unit) {
    '' || 's' || 'sec' || 'secs' || 'second' || 'seconds' ||
    'ث' || 'ثانية' || 'ثواني' => 1,
    'm' || 'min' || 'mins' || 'minute' || 'minutes' ||
    'د' || 'دقيقة' || 'دقائق' => 60,
    'h' || 'hr' || 'hrs' || 'hour' || 'hours' ||
    'س' || 'ساعة' || 'ساعات' => 3600,
    _ => 0,
  };
  if (multiplier == 0) return null;

  final seconds = amount * multiplier;
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

String _normalizeDigits(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var output = input;
  for (var i = 0; i < 10; i++) {
    output = output
        .replaceAll(arabic[i], '$i')
        .replaceAll(persian[i], '$i');
  }
  return output;
}
