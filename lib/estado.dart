import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'datos_d1.dart';
import 'modelos/colas.dart';
import 'ui/formato.dart';

const equipo = [
  'Kevin Alejandro Ramírez Guarín',
  'Darnell José Greene Santana',
  'José Alejandro Tabares Pulgarín',
  'Alfonso Pérez Valdez',
];

/// Entradas ya interpretadas.
class Entradas {
  final Estadistica llegadas;
  final Estadistica servicio;
  final double lam; // total, clientes/h
  final double mu; // por caja, clientes/h
  final int s; // servidores del modelo
  final double lamModelo; // lambda que usa el modelo
  final int cajas;
  final List<String> errores;
  Entradas(this.llegadas, this.servicio, this.lam, this.mu, this.s, this.lamModelo, this.cajas, this.errores);
}

class Resultado {
  final Entradas e;
  final Cola cola;
  final String modelo; // 'mm1' | 'mms'
  final DateTime cuando;
  Resultado(this.e, this.cola, this.modelo, this.cuando);
}

class Ecuacion {
  final String titulo, formula, sustitucion, resultado;
  const Ecuacion(this.titulo, this.formula, this.sustitucion, this.resultado);
}

class Estado extends ChangeNotifier {
  // Campos editables (texto tal como lo escribe el usuario).
  final Map<String, String> v = {
    'lugar': '',
    'fecha': '',
    'horaIni': '',
    'horaFin': '',
    'cajas': '1',
    'cajasInstaladas': '3',
    'llegModo': 'datos',
    'llegProm': '',
    'llegRaw': '',
    'llegUnidad': 'min',
    'servModo': 'datos',
    'servProm': '',
    'servRaw': '',
    'servUnidad': 'min',
    'modelo': 'mm1',
    'servidores': '1',
    'porCaja': 'no',
    'costoCajero': '',
    'costoEspera': '',
    'mejora': '20',
    'meta': '1',
    'sonido': 'si',
    'fuente': '',
  };
  Resultado? res;
  ResultadoMC? mc;
  SharedPreferences? _prefs;

  Future<void> cargar() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString('filalab');
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        m.forEach((k, val) {
          if (v.containsKey(k) && val is String) v[k] = val;
        });
      }
    } catch (_) {}
    notifyListeners();
  }

  void _guardar() {
    try {
      _prefs?.setString('filalab', jsonEncode(v));
    } catch (_) {}
  }

  String g(String k) => v[k] ?? '';
  bool get sonido => g('sonido') == 'si';

  void set(String k, String valor, {bool avisar = true}) {
    v[k] = valor;
    _guardar();
    if (avisar) notifyListeners();
  }

  void setVarios(Map<String, String> m) {
    v.addAll(m);
    _guardar();
    notifyListeners();
  }

  void cargarD1() {
    setVarios({
      'lugar': d1Lugar,
      'fecha': d1Fecha,
      'horaIni': d1HoraIni,
      'horaFin': d1HoraFin,
      'cajas': '1',
      'cajasInstaladas': '3',
      'llegModo': 'datos',
      'llegRaw': d1Llegadas,
      'llegUnidad': 'min',
      'servModo': 'datos',
      'servRaw': d1Servicio,
      'servUnidad': 'min',
      'modelo': 'mm1',
      'servidores': '1',
      'porCaja': 'no',
      'fuente': 'Planilla D1 12/11/2026: clientes 1 a 5 medidos en campo, 6 a 30 simulados (Montecarlo)',
    });
  }

  Entradas entradas() {
    final err = <String>[];
    Estadistica ll, sv;
    if (g('llegModo') == 'prom') {
      final m = numero(g('llegProm'));
      ll = Estadistica(0, m, double.nan, 0);
      if (!(m > 0)) err.add('Escribe el tiempo promedio entre llegadas.');
    } else {
      ll = leerLlegadas(g('llegRaw'), enSegundos: g('llegUnidad') == 'seg');
      if (ll.n < 2) err.add('Pega al menos 2 datos de llegada.');
    }
    if (g('servModo') == 'prom') {
      final m = numero(g('servProm'));
      sv = Estadistica(0, m, double.nan, 0);
      if (!(m > 0)) err.add('Escribe el tiempo promedio de atención.');
    } else {
      sv = leerServicio(g('servRaw'), enSegundos: g('servUnidad') == 'seg');
      if (sv.n < 2) err.add('Pega al menos 2 tiempos de atención.');
    }
    final lam = ll.media > 0 ? 60 / ll.media : double.nan;
    final mu = sv.media > 0 ? 60 / sv.media : double.nan;
    final cajas = int.tryParse(g('cajas').trim()) ?? 0;
    int s = 1;
    double lamM = lam;
    if (g('modelo') == 'mms') {
      s = int.tryParse(g('servidores').trim()) ?? 0;
      if (s < 1 || s > 30) err.add('Indica el número de servidores s (1 a 30).');
    } else if (g('porCaja') == 'si') {
      if (cajas >= 1) {
        lamM = lam / cajas;
      } else {
        err.add('Para repartir las llegadas indica las cajas atendiendo.');
      }
    }
    return Entradas(ll, sv, lam, mu, s, lamM, cajas, err);
  }

  /// Devuelve la lista de errores (vacía si calculó bien).
  List<String> calcular() {
    final e = entradas();
    if (e.errores.isNotEmpty) return e.errores;
    res = Resultado(e, Cola(e.lamModelo, e.mu, e.s), g('modelo'), DateTime.now());
    mc = null;
    notifyListeners();
    return const [];
  }

  void correrMontecarlo() {
    final r = res;
    if (r == null || !r.cola.estable) return;
    mc = montecarlo(r.cola.lam, r.cola.mu, r.cola.s);
    notifyListeners();
  }

  int get maxCajasEscenario {
    final n = int.tryParse(g('cajasInstaladas').trim()) ?? 3;
    return n.clamp(2, 8);
  }

  List<Escenario> escenariosA() {
    final r = res!;
    return escenarios(r.e.lam, r.e.mu, maxCajasEscenario, numero(g('costoCajero')), numero(g('costoEspera')));
  }

  double get mejora => (numero(g('mejora')).isFinite ? numero(g('mejora')) : 0) / 100;

  List<Escenario> escenariosB() {
    final r = res!;
    return escenarios(r.e.lam, r.e.mu * (1 + mejora), maxCajasEscenario, numero(g('costoCajero')), numero(g('costoEspera')));
  }

  String recomendacion() {
    final a = escenariosA(), b = escenariosB();
    final hoy = res!.e.cajas > 0 ? res!.e.cajas : res!.cola.s;
    final meta = numero(g('meta'));
    final partes = <String>[];
    final actual = a.where((x) => x.s == hoy).toList();
    if (actual.isNotEmpty) {
      final c = actual.first.cola;
      partes.add(c.estable
          ? 'Hoy, con $hoy caja(s) atendiendo, la espera promedio en fila es de ${nf(c.wq * 60, 2)} min y la ocupación es de ${pct(c.rho, 1)}.'
          : 'Hoy, con $hoy caja(s) atendiendo, el sistema es inestable: la fila crece sin control.');
    }
    if (meta.isFinite) {
      Escenario? cumpleA, cumpleB;
      for (final x in a) {
        if (x.cola.estable && x.cola.wq * 60 <= meta) {
          cumpleA = x;
          break;
        }
      }
      for (final x in b) {
        if (x.cola.estable && x.cola.wq * 60 <= meta) {
          cumpleB = x;
          break;
        }
      }
      if (cumpleA != null) {
        partes.add('Para esperar ${nf(meta, 1)} min o menos basta con ${cumpleA.s} caja(s) a la velocidad actual'
            '${cumpleB != null ? ' o ${cumpleB.s} si la atención mejora un ${nf(mejora * 100, 0)} %' : ''}.');
      } else {
        partes.add('Con las cajas instaladas no se logra una espera de ${nf(meta, 1)} min.');
      }
    }
    Escenario? mejor(List<Escenario> l) {
      final ok = l.where((x) => x.costo.isFinite).toList();
      if (ok.isEmpty) return null;
      ok.sort((x, y) => x.costo.compareTo(y.costo));
      return ok.first;
    }

    final ma = mejor(a), mb = mejor(b);
    if (ma != null) {
      partes.add('El menor costo total se logra con ${ma.s} caja(s) (${cop(ma.costo)}/h)'
          '${mb != null ? ' y, con la mejora, con ${mb.s} (${cop(mb.costo)}/h)' : ''}.');
    } else {
      partes.add('Escribe los costos para identificar la opción más rentable.');
    }
    return partes.join(' ');
  }

  List<Ecuacion> ecuaciones() {
    final r = res!;
    final q = r.cola, e = r.e;
    final l = nf(q.lam), m = nf(q.mu), s = q.s;
    final out = <Ecuacion>[];
    final reparte = r.modelo == 'mm1' && g('porCaja') == 'si' && e.cajas > 1;
    out.add(Ecuacion('Tasa de llegada λ', 'λ = 60 / tiempo promedio entre llegadas',
        '= 60 / ${nf(e.llegadas.media)}${reparte ? ' = ${nf(e.lam)}; λ/cajas = ${nf(e.lam)} / ${e.cajas}' : ''}', 'λ = $l clientes/h'));
    out.add(Ecuacion('Tasa de servicio μ', 'μ = 60 / tiempo promedio de atención', '= 60 / ${nf(e.servicio.media)}', 'μ = $m clientes/h'));
    if (r.modelo == 'mm1') {
      out.add(Ecuacion('a. Factor de uso', 'ρ = λ / μ', '= $l / $m', 'ρ = ${nf(q.rho)}'));
      if (!q.estable) return out;
      out.add(Ecuacion('b. Probabilidad de sistema vacío', 'P0 = 1 − ρ', '= 1 − ${nf(q.rho)}', 'P0 = ${nf(q.p0)}'));
      out.add(Ecuacion('c. Clientes promedio en la fila', 'Lq = ρ² / (1 − ρ)', '= ${nf(q.rho)}² / (1 − ${nf(q.rho)})', 'Lq = ${nf(q.lq)} clientes'));
      out.add(Ecuacion('d. Tiempo promedio en la fila', 'Wq = Lq / λ', '= ${nf(q.lq)} / $l h', 'Wq = ${nf(q.wq)} h = ${nf(q.wq * 60, 2)} min'));
      out.add(Ecuacion('e. Clientes promedio en el sistema', 'L = ρ / (1 − ρ)', '= ${nf(q.rho)} / (1 − ${nf(q.rho)})', 'L = ${nf(q.l)} clientes'));
      out.add(Ecuacion('f. Tiempo promedio en el sistema', 'W = 1 / (μ − λ)', '= 1 / ($m − $l) h', 'W = ${nf(q.w)} h = ${nf(q.w * 60, 2)} min'));
      out.add(Ecuacion('Probabilidad de n clientes', 'Pn = (1 − ρ) · ρⁿ', '', 'P1 = ${nf(q.pn(1))}, P2 = ${nf(q.pn(2))}'));
    } else {
      out.add(Ecuacion('Intensidad de tráfico', 'r = λ / μ', '= $l / $m', 'r = ${nf(q.r)}'));
      out.add(Ecuacion('a. Factor de uso', 'ρ = λ / (s · μ)', '= $l / ($s · $m)', 'ρ = ${nf(q.rho)}'));
      if (!q.estable) return out;
      out.add(Ecuacion('b. Probabilidad de sistema vacío', 'P0 = [ Σ(n=0..s−1) rⁿ/n! + rˢ / (s!(1 − ρ)) ]⁻¹',
          'Σ = ${nf(q.suma)} ; rˢ/(s!(1−ρ)) = ${nf(q.termino)} ; P0 = 1 / (${nf(q.suma)} + ${nf(q.termino)})', 'P0 = ${nf(q.p0)}'));
      out.add(Ecuacion('Probabilidad de que un cliente espere', 'Pw = P0 · rˢ / (s!(1 − ρ))', '= ${nf(q.p0)} · ${nf(q.termino)}',
          'Pw = ${nf(q.pw)} (${pct(q.pw)})'));
      out.add(Ecuacion('c. Clientes promedio en la fila', 'Lq = P0 · rˢ · ρ / (s! (1 − ρ)²)',
          '= ${nf(q.p0)} · ${nf(q.r)}^$s · ${nf(q.rho)} / ($s! · (1 − ${nf(q.rho)})²)', 'Lq = ${nf(q.lq)} clientes'));
      out.add(Ecuacion('d. Tiempo promedio en la fila', 'Wq = Lq / λ', '= ${nf(q.lq)} / $l h', 'Wq = ${nf(q.wq)} h = ${nf(q.wq * 60, 2)} min'));
      out.add(Ecuacion('e. Clientes promedio en el sistema', 'L = Lq + λ / μ', '= ${nf(q.lq)} + ${nf(q.r)}', 'L = ${nf(q.l)} clientes'));
      out.add(Ecuacion('f. Tiempo promedio en el sistema', 'W = Wq + 1 / μ', '= ${nf(q.wq)} + 1 / $m h', 'W = ${nf(q.w)} h = ${nf(q.w * 60, 2)} min'));
      out.add(Ecuacion('Probabilidad de n clientes', 'Pn = P0 rⁿ/n! si n < s ; Pn = P0 rⁿ/(s! sⁿ⁻ˢ) si n ≥ s', '',
          'P1 = ${nf(q.pn(1))}, P$s = ${nf(q.pn(s))}'));
    }
    out.add(Ecuacion('Comprobación (ley de Little)', 'L = λ · W', '= $l · ${nf(q.w)}', '= ${nf(q.lam * q.w)} clientes'));
    return out;
  }
}

final estado = Estado();
