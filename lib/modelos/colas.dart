import 'dart:math' as math;

/// Factorial como double (sirve hasta s = 30 sin problema).
double factorial(int n) {
  double f = 1;
  for (int i = 2; i <= n; i++) {
    f *= i;
  }
  return f;
}

/// Modelo M/M/s. Con s = 1 es exactamente el modelo M/M/1.
/// lam y mu en clientes por hora. Tiempos (wq, w) en horas.
class Cola {
  final double lam;
  final double mu;
  final int s;
  late final double r;
  late final double rho;
  late final bool estable;
  double p0 = double.nan;
  double pw = double.nan;
  double lq = double.nan;
  double wq = double.nan;
  double l = double.nan;
  double w = double.nan;
  double suma = double.nan;
  double termino = double.nan;

  Cola(this.lam, this.mu, this.s) {
    r = lam / mu;
    rho = lam / (s * mu);
    estable = rho > 0 && rho < 1;
    if (!estable) return;
    double sm = 0;
    for (int n = 0; n < s; n++) {
      sm += math.pow(r, n) / factorial(n);
    }
    final double t = math.pow(r, s) / (factorial(s) * (1 - rho));
    suma = sm;
    termino = t;
    p0 = 1 / (sm + t);
    pw = p0 * t;
    lq = p0 * math.pow(r, s) * rho / (factorial(s) * math.pow(1 - rho, 2));
    wq = lq / lam;
    l = lq + r;
    w = wq + 1 / mu;
  }

  /// Probabilidad de n clientes en el sistema.
  double pn(int n) {
    if (!estable) return double.nan;
    if (n < s) return p0 * math.pow(r, n) / factorial(n);
    return p0 * math.pow(r, n) / (factorial(s) * math.pow(s, n - s));
  }
}

class Estadistica {
  final int n;
  final double media;
  final double desv;
  final int invalidos;
  const Estadistica(this.n, this.media, this.desv, this.invalidos);
  double get cv => (n > 1 && media > 0) ? desv / media : double.nan;
  static const vacia = Estadistica(0, double.nan, double.nan, 0);
}

Estadistica estadistica(List<double> v, int invalidos) {
  final n = v.length;
  if (n == 0) return Estadistica(0, double.nan, double.nan, invalidos);
  final m = v.reduce((a, b) => a + b) / n;
  double sd = double.nan;
  if (n > 1) {
    double acc = 0;
    for (final x in v) {
      acc += (x - m) * (x - m);
    }
    sd = math.sqrt(acc / (n - 1));
  }
  return Estadistica(n, m, sd, invalidos);
}

/// Convierte "1,5" o "1.5" en número.
double numero(String? t) {
  if (t == null) return double.nan;
  final s = t.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (s.isEmpty) return double.nan;
  return double.tryParse(s) ?? double.nan;
}

List<String> _tokens(String texto) =>
    texto.split(RegExp(r'[\n;\t ]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

final _reloj = RegExp(r'^(\d{1,2}):(\d{2}):(\d{2})([.,]\d+)?$');
final _minSeg = RegExp(r'^(\d+):(\d{2})([.,]\d+)?$');

/// Hora del día hh:mm:ss en segundos.
double segundosReloj(String t) {
  final m = _reloj.firstMatch(t);
  if (m == null) return double.nan;
  final frac = m.group(4) != null ? double.parse('0.${m.group(4)!.substring(1)}') : 0.0;
  return int.parse(m.group(1)!) * 3600 + int.parse(m.group(2)!) * 60 + int.parse(m.group(3)!) + frac;
}

/// Duración en minutos: "2,5" (en la unidad dada), "2:30" (min:seg) o "0:02:30".
double duracionMin(String t, {bool enSegundos = false}) {
  final m = _minSeg.firstMatch(t);
  if (m != null) {
    final frac = m.group(3) != null ? double.parse('0.${m.group(3)!.substring(1)}') : 0.0;
    return int.parse(m.group(1)!) + (int.parse(m.group(2)!) + frac) / 60;
  }
  final r = _reloj.firstMatch(t);
  if (r != null) return segundosReloj(t) / 60;
  final x = numero(t);
  return enSegundos ? x / 60 : x;
}

/// Llegadas: horas de llegada (hh:mm:ss) o tiempos entre llegadas.
Estadistica leerLlegadas(String texto, {bool enSegundos = false}) {
  final tk = _tokens(texto);
  if (tk.isEmpty) return Estadistica.vacia;
  final relojes = tk.where((t) => _reloj.hasMatch(t)).length;
  final v = <double>[];
  int malos = 0;
  if (relojes >= tk.length / 2) {
    double? previo;
    for (final t in tk) {
      final s = segundosReloj(t);
      if (s.isNaN) {
        malos++;
        continue;
      }
      if (previo != null) {
        var d = s - previo;
        if (d < 0) d += 86400;
        if (d > 0 && d < 7200) {
          v.add(d / 60);
        } else {
          malos++;
        }
      }
      previo = s;
    }
  } else {
    for (final t in tk) {
      final x = duracionMin(t, enSegundos: enSegundos);
      if (x.isFinite && x > 0) {
        v.add(x);
      } else {
        malos++;
      }
    }
  }
  return estadistica(v, malos);
}

Estadistica leerServicio(String texto, {bool enSegundos = false}) {
  final v = <double>[];
  int malos = 0;
  for (final t in _tokens(texto)) {
    final x = duracionMin(t, enSegundos: enSegundos);
    if (x.isFinite && x > 0) {
      v.add(x);
    } else {
      malos++;
    }
  }
  return estadistica(v, malos);
}

/// Escenario de mejora para s cajas.
class Escenario {
  final int s;
  final Cola cola;
  final double costo;
  Escenario(this.s, this.cola, this.costo);
}

List<Escenario> escenarios(double lam, double mu, int maxS, double costoCajero, double costoEspera) {
  return [
    for (int s = 1; s <= maxS; s++)
      () {
        final c = Cola(lam, mu, s);
        final costo = (c.estable && costoCajero.isFinite && costoEspera.isFinite) ? s * costoCajero + c.l * costoEspera : double.nan;
        return Escenario(s, c, costo);
      }()
  ];
}

/// Resultado de la simulación Montecarlo (tiempos en horas).
class ResultadoMC {
  final int replicas;
  final int clientes;
  final int calentamiento;
  final double wq;
  final double wqIc;
  final double w;
  final double wIc;
  ResultadoMC(this.replicas, this.clientes, this.calentamiento, this.wq, this.wqIc, this.w, this.wIc);
}

double expo(math.Random rnd, double tasa) => -math.log(1 - rnd.nextDouble()) / tasa;

ResultadoMC montecarlo(double lam, double mu, int s, {int replicas = 20, int clientes = 2000, int calentamiento = 500}) {
  final rnd = math.Random();
  final wqs = <double>[];
  final ws = <double>[];
  for (int r = 0; r < replicas; r++) {
    final libre = List<double>.filled(s, 0);
    double t = 0, sumWq = 0, sumW = 0;
    for (int i = 0; i < calentamiento + clientes; i++) {
      t += expo(rnd, lam);
      int k = 0;
      for (int j = 1; j < s; j++) {
        if (libre[j] < libre[k]) k = j;
      }
      final inicio = math.max(t, libre[k]);
      final serv = expo(rnd, mu);
      libre[k] = inicio + serv;
      if (i >= calentamiento) {
        sumWq += inicio - t;
        sumW += inicio + serv - t;
      }
    }
    wqs.add(sumWq / clientes);
    ws.add(sumW / clientes);
  }
  final a = estadistica(wqs, 0), b = estadistica(ws, 0);
  const tStudent = 2.093; // 19 grados de libertad, 95 %
  return ResultadoMC(replicas, clientes, calentamiento, a.media, tStudent * a.desv / math.sqrt(replicas), b.media,
      tStudent * b.desv / math.sqrt(replicas));
}
