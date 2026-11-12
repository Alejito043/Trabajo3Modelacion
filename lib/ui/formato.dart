/// Formatos numéricos estilo Colombia: coma decimal y punto de miles.
String _miles(String entero) {
  final neg = entero.startsWith('-');
  final d = neg ? entero.substring(1) : entero;
  final b = StringBuffer();
  for (int i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write('.');
    b.write(d[i]);
  }
  return (neg ? '-' : '') + b.toString();
}

String nf(double x, [int dec = 4]) {
  if (x.isNaN || x.isInfinite) return '–';
  final s = x.toStringAsFixed(dec);
  final partes = s.split('.');
  return partes.length == 1 ? _miles(partes[0]) : '${_miles(partes[0])},${partes[1]}';
}

String pct(double x, [int dec = 2]) => (x.isNaN || x.isInfinite) ? '–' : '${nf(x * 100, dec)} %';

String cop(double x) => (x.isNaN || x.isInfinite) ? '–' : '\$ ${nf(x.roundToDouble(), 0)}';

String fecha(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  return m == null ? iso : '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}
