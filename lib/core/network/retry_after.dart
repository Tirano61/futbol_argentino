/// Espera que pide el encabezado `Retry-After` (RFC 9110 §10.2.3): una
/// cantidad de segundos o una fecha HTTP. La fecha se mide contra el
/// encabezado `Date` de la misma respuesta ([date]) si se entiende, para no
/// depender del reloj del dispositivo; si no, contra [now].
///
/// `null` si falta o no se entiende (se usa la espera propia). Una fecha ya
/// pasada da `Duration.zero`.
Duration? parseRetryAfter(
  String? value, {
  String? date,
  required DateTime now,
}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(text)) {
    final seconds = int.tryParse(text);
    return seconds == null ? null : Duration(seconds: seconds);
  }
  final until = parseHttpDate(text);
  if (until == null) return null;
  final reference = (date == null ? null : parseHttpDate(date.trim())) ?? now;
  final wait = until.difference(reference);
  return wait.isNegative ? Duration.zero : wait;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

final _imfFixdate = RegExp(
  r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun), (\d{2}) ([A-Za-z]{3}) (\d{4}) '
  r'(\d{2}):(\d{2}):(\d{2}) GMT$',
);

/// Fecha HTTP en el formato que la norma obliga a enviar (IMF-fixdate,
/// `Sun, 06 Nov 1994 08:49:37 GMT`), en UTC; `null` si no lo es. Los
/// formatos obsoletos no se aceptan. Sin `dart:io` (`HttpDate` no existe en
/// Web).
DateTime? parseHttpDate(String text) {
  final match = _imfFixdate.firstMatch(text);
  if (match == null) return null;
  final month = _months.indexOf(match[2]!) + 1;
  if (month == 0) return null;
  final day = int.parse(match[1]!);
  final year = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = int.parse(match[6]!);
  final parsed = DateTime.utc(year, month, day, hour, minute, second);
  // DateTime.utc normaliza fuera de rango (31 Feb → 3 Mar): se rechaza.
  if (parsed.day != day ||
      parsed.month != month ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second) {
    return null;
  }
  return parsed;
}
