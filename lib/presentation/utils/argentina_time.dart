/// America/Argentina/Buenos_Aires: UTC−3 fijo (Argentina no aplica horario
/// de verano desde 2009).
const _argentinaOffset = Duration(hours: -3);

/// Fecha (`dd/MM/yyyy`) y hora (`HH:mm`) en Argentina, o `null` si no hay
/// un instante UTC válido.
({String date, String time})? formatArgentinaDateTime(DateTime? utc) {
  if (utc == null) return null;
  final ar = utc.toUtc().add(_argentinaOffset);
  String two(int n) => n.toString().padLeft(2, '0');
  return (
    date:
        '${two(ar.day)}/${two(ar.month)}/${ar.year.toString().padLeft(4, '0')}',
    time: '${two(ar.hour)}:${two(ar.minute)}',
  );
}
