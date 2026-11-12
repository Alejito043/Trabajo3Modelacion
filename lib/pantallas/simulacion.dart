import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../estado.dart';
import '../modelos/colas.dart';
import '../servicios/sonido.dart';
import '../ui/comunes.dart';
import '../ui/formato.dart';

class _Cliente {
  double x, y, tx = 0, ty = 0, alfa = 1;
  final Color color;
  final double llegada;
  bool saliendo = false, oculto = false;
  _Cliente(this.x, this.y, this.color, this.llegada);
}

class _Servidor {
  _Cliente? c;
  double fin = double.infinity;
}

/// Simulación de eventos discretos M/M/s animada (tiempo en minutos).
class _Sim {
  final double lam, mu; // por minuto
  final int s;
  final math.Random rnd = math.Random();
  double t = 0, sigLlegada = 0, sumaEspera = 0;
  int atendidos = 0, llegados = 0;
  final List<_Cliente> clientes = [];
  final List<_Cliente> fila = [];
  late final List<_Servidor> servidores;
  Size tam = const Size(320, 320);
  static const colores = [
    Color(0xFFF0643A), Color(0xFFFFC24B), Color(0xFF3CC4A2), Color(0xFF6C8CFF),
    Color(0xFFE86FA8), Color(0xFF8BD17C), Color(0xFFFF9F6E), Color(0xFF58B8E8),
  ];

  _Sim(this.lam, this.mu, this.s) {
    servidores = List.generate(s, (_) => _Servidor());
    sigLlegada = expo(rnd, lam);
  }

  double xCaja(int i) => 12 + (tam.width - 24) * (i + 0.5) / s;
  int get porFila => math.max(4, ((tam.width - 40) / 26).floor());
  Offset puesto(int i) {
    final fila = i ~/ porFila, k = i % porFila;
    final x = fila.isEven ? tam.width - 30 - k * 26 : 30 + k * 26.0;
    return Offset(x.toDouble(), 150 + fila * 30.0);
  }

  void _atender(int i, _Cliente c) {
    final sv = servidores[i];
    sv.c = c;
    sv.fin = t + expo(rnd, mu);
    sumaEspera += t - c.llegada;
    c.tx = xCaja(i);
    c.ty = 86;
  }

  void avanzar(double dtMin, bool sonido) {
    final fin = t + dtMin;
    while (true) {
      int si = -1;
      double se = double.infinity;
      for (int i = 0; i < servidores.length; i++) {
        if (servidores[i].fin < se) {
          se = servidores[i].fin;
          si = i;
        }
      }
      final tn = math.min(sigLlegada, se);
      if (tn > fin) break;
      t = tn;
      if (sigLlegada <= se) {
        final c = _Cliente(-20, tam.height - 24, colores[llegados % colores.length], t);
        llegados++;
        clientes.add(c);
        final libre = servidores.indexWhere((x) => x.c == null);
        if (libre >= 0) {
          _atender(libre, c);
        } else {
          fila.add(c);
        }
        sigLlegada = t + expo(rnd, lam);
        if (sonido) Sonido.pop();
      } else {
        final sv = servidores[si];
        sv.c!
          ..saliendo = true
          ..tx = tam.width + 30
          ..ty = 40;
        sv.c = null;
        sv.fin = double.infinity;
        atendidos++;
        if (fila.isNotEmpty) _atender(si, fila.removeAt(0));
      }
    }
    t = fin;
    final visibles = porFila * 4;
    for (int i = 0; i < fila.length; i++) {
      final p = puesto(math.min(i, visibles - 1));
      fila[i]
        ..tx = p.dx
        ..ty = p.dy
        ..oculto = i >= visibles;
    }
  }

  void mover(double dtReal) {
    final k = math.min(1.0, dtReal * 7);
    for (final c in clientes) {
      c.x += (c.tx - c.x) * k;
      c.y += (c.ty - c.y) * k;
      if (c.saliendo) c.alfa -= dtReal * 1.6;
    }
    clientes.removeWhere((c) => c.alfa <= 0);
  }

  double get wqPromedio {
    final empezados = atendidos + servidores.where((x) => x.c != null).length;
    return empezados == 0 ? double.nan : sumaEspera / empezados;
  }
}

class PantallaSimulacion extends StatefulWidget {
  final bool activa;
  const PantallaSimulacion({super.key, required this.activa});
  @override
  State<PantallaSimulacion> createState() => _PantallaSimulacionState();
}

class _PantallaSimulacionState extends State<PantallaSimulacion> with SingleTickerProviderStateMixin {
  late final Ticker ticker = createTicker(_tick);
  _Sim? sim;
  Resultado? base;
  bool corriendo = false;
  double velocidad = 1; // minutos simulados por segundo
  Duration ultimo = Duration.zero;

  @override
  void didUpdateWidget(covariant PantallaSimulacion old) {
    super.didUpdateWidget(old);
    if (!widget.activa && corriendo) _pausar();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void _reiniciar() {
    final r = estado.res;
    base = r;
    sim = r == null ? null : _Sim(r.cola.lam / 60, r.cola.mu / 60, r.cola.s);
    _pausar();
    setState(() {});
  }

  void _tick(Duration d) {
    final dt = math.min(0.1, (d - ultimo).inMicroseconds / 1e6);
    ultimo = d;
    final s = sim;
    if (s == null) return;
    s.avanzar(dt * velocidad, velocidad <= 3 && estado.sonido);
    s.mover(dt);
    setState(() {});
  }

  void _iniciar() {
    if (estado.res == null) {
      aviso(context, 'Primero calcula el modelo.');
      return;
    }
    if (sim == null || base != estado.res) _reiniciar();
    ultimo = Duration.zero;
    ticker.start();
    setState(() => corriendo = true);
  }

  void _pausar() {
    if (ticker.isActive) ticker.stop();
    corriendo = false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final r = estado.res;
        if (r != null && base != r && !corriendo) {
          base = r;
          sim = _Sim(r.cola.lam / 60, r.cola.mu / 60, r.cola.s);
        }
        final cs = Theme.of(context).colorScheme;
        final s = sim;
        final mc = estado.mc;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const Encabezado('Simulación', subtitulo: 'La fila en movimiento con llegadas y atenciones aleatorias, usando los mismos λ, μ y s del modelo.'),
            Tarjeta(
              child: Column(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(
                    height: 320,
                    child: LayoutBuilder(builder: (context, k) {
                      s?.tam = Size(k.maxWidth, 320);
                      return CustomPaint(painter: _SimPainter(s, cs, Theme.of(context).brightness == Brightness.dark), size: Size.infinite);
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    FilledButton.icon(
                      onPressed: () {
                        Sonido.tap();
                        corriendo ? setState(_pausar) : _iniciar();
                      },
                      icon: Icon(corriendo ? Icons.pause : Icons.play_arrow),
                      label: Text(corriendo ? 'Pausa' : 'Iniciar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _reiniciar, child: const Text('Reiniciar')),
                    const Spacer(),
                    DropdownButton<double>(
                      value: velocidad,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0.5, child: Text('0,5 min/s')),
                        DropdownMenuItem(value: 1, child: Text('1 min/s')),
                        DropdownMenuItem(value: 3, child: Text('3 min/s')),
                        DropdownMenuItem(value: 10, child: Text('10 min/s')),
                      ],
                      onChanged: (v) => setState(() => velocidad = v ?? 1),
                    ),
                  ]),
                ),
              ]),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
              children: [
                _Kpi('Reloj simulado', s == null ? '–' : '${nf(s.t, 1)} min'),
                _Kpi('Clientes atendidos', s == null ? '–' : '${s.atendidos}'),
                _Kpi('Wq simulado', s == null || s.wqPromedio.isNaN ? '–' : '${nf(s.wqPromedio, 2)} min'),
                _Kpi('Wq del modelo', r == null ? '–' : (r.cola.estable ? '${nf(r.cola.wq * 60, 2)} min' : 'Inestable')),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Montecarlo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Tarjeta(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Repite la simulación 20 veces con 2.000 clientes cada una y compara el promedio con el resultado teórico.',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () {
                      if (r == null) {
                        aviso(context, 'Primero calcula el modelo.');
                        return;
                      }
                      if (!r.cola.estable) {
                        aviso(context, 'Con ρ ≥ 1 la fila crece sin límite; la simulación no converge.');
                        return;
                      }
                      estado.correrMontecarlo();
                      Sonido.ding();
                    },
                    child: const Text('Correr simulación Montecarlo'),
                  ),
                  if (mc != null && r != null) ...[
                    const SizedBox(height: 12),
                    Table(
                      columnWidths: const {0: FlexColumnWidth(1.4)},
                      children: [
                        _filaT(['Medida', 'Teórico', 'Montecarlo', 'IC 95 %'], cs, encabezado: true),
                        _filaT(['Wq (min)', nf(r.cola.wq * 60, 2), nf(mc.wq * 60, 2), '± ${nf(mc.wqIc * 60, 2)}'], cs),
                        _filaT(['W (min)', nf(r.cola.w * 60, 2), nf(mc.w * 60, 2), '± ${nf(mc.wIc * 60, 2)}'], cs),
                        _filaT(['Lq = λ·Wq', nf(r.cola.lq, 3), nf(r.cola.lam * mc.wq, 3), ''], cs),
                        _filaT(['L = λ·W', nf(r.cola.l, 3), nf(r.cola.lam * mc.w, 3), ''], cs),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '${mc.replicas} réplicas de ${nf(mc.clientes.toDouble(), 0)} clientes, descartando los primeros ${mc.calentamiento} de cada una. '
                        'Las diferencias con el valor teórico se deben al azar.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

TableRow _filaT(List<String> celdas, ColorScheme cs, {bool encabezado = false}) => TableRow(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
      children: [
        for (int i = 0; i < celdas.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(celdas[i],
                textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                    fontFamily: encabezado ? null : 'monospace',
                    fontSize: encabezado ? 12 : 13,
                    fontWeight: encabezado ? FontWeight.w800 : FontWeight.w500,
                    color: encabezado ? cs.onSurfaceVariant : null)),
          ),
      ],
    );

class _Kpi extends StatelessWidget {
  final String e, v;
  const _Kpi(this.e, this.v);
  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      margen: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(e, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          FittedBox(child: Text(v, style: const TextStyle(fontFamily: 'monospace', fontSize: 19, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

class _SimPainter extends CustomPainter {
  final _Sim? s;
  final ColorScheme cs;
  final bool oscuro;
  _SimPainter(this.s, this.cs, this.oscuro);

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = oscuro ? const Color(0xFF1A2624) : papel;
    canvas.drawRect(Offset.zero & size, Paint()..color = fondo);
    void texto(String t, Offset o, {Color? color, TextAlign al = TextAlign.center, double tam = 11}) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: TextStyle(fontSize: tam, color: color ?? cs.onSurfaceVariant)), textDirection: TextDirection.ltr)
        ..layout();
      final dx = al == TextAlign.center ? o.dx - tp.width / 2 : (al == TextAlign.right ? o.dx - tp.width : o.dx);
      tp.paint(canvas, Offset(dx, o.dy));
    }

    final sim = s;
    if (sim == null) {
      texto('Calcula el modelo para ver la simulación', Offset(size.width / 2, size.height / 2 - 8), tam: 14);
      return;
    }
    canvas.drawRect(Rect.fromLTWH(0, size.height - 12, size.width, 12), Paint()..color = cs.outlineVariant.withOpacity(0.5));
    final ancho = math.min(64.0, (size.width - 24) / sim.s - 8);
    for (int i = 0; i < sim.s; i++) {
      final cx = sim.xCaja(i);
      final ocupada = sim.servidores[i].c != null;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - ancho / 2, 18, ancho, 40), const Radius.circular(8)),
          Paint()..color = ocupada ? verde : cs.outlineVariant);
      texto(sim.s > 6 ? '${i + 1}' : 'Caja ${i + 1}', Offset(cx, 31), color: ocupada ? Colors.white : cs.onSurfaceVariant);
      canvas.drawRect(Rect.fromLTWH(cx - ancho / 2 + 4, 60, ancho - 8, 4), Paint()..color = cs.outlineVariant);
    }
    texto('Fila: ${sim.fila.length}', const Offset(12, 120), al: TextAlign.left);
    final visibles = sim.porFila * 4;
    if (sim.fila.length > visibles) {
      texto('+${sim.fila.length - visibles} más', Offset(size.width - 12, 120), al: TextAlign.right);
    }
    for (final c in sim.clientes) {
      if (c.oculto) continue;
      final p = Paint()..color = c.color.withOpacity(c.alfa.clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(Offset(c.x, c.y - 6), 8, p);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.x - 8, c.y + 3, 16, 9), const Radius.circular(3)), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
