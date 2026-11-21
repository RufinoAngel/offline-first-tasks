/// Todas las marcas de tiempo se guardan en UTC, ISO-8601 y con precisión de
/// milisegundos. Así el formato es SIEMPRE de longitud fija y el orden
/// lexicográfico en SQLite coincide con el orden cronológico.
DateTime nowUtc() => normalizeUtc(DateTime.now());

DateTime normalizeUtc(DateTime d) =>
    DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch, isUtc: true);
