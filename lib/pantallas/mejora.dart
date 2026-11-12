import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../estado.dart';
import '../modelos/colas.dart';
import '../ui/comunes.dart';
import '../ui/formato.dart';
import 'datos.dart' show Campo;

class PantallaMejora extends StatelessWidget {
  const PantallaMejora({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final r = estado.res;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const Encabezado('Plan de mejora',
                subtitulo: 'Escenarios M/M/s abriendo las cajas instaladas, con la velocidad actual y con una mejora en la atención.'),
            Tarjeta(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Row(children: [
                    Expanded(child: Campo('costoCajero', 'Costo cajero (COP/h)', teclado: TextInputType.number, monoespacio: true)),
                    SizedBox(width: 10),
                    Expanded(child: Campo('costoEspera', 'Costo espera (COP/h)', teclado: TextInputType.number, monoespacio: true)),
                  ]),
                  const Row(children: [
                    Expanded(child: Campo('mejora', 'Mejora velocidad (%)', teclado: TextInputType.number, monoespacio: true)),
                    SizedBox(width: 10),
                    Expanded(
                        child: Campo('meta', 'Espera máx. (min)',
                            teclado: TextInputType.numberWithOptions(decimal: true), monoespacio: true)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('La mejora representa medidas como un empacador, pago con QR o más datáfonos.',
                        style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ),
                ]),
              ),
            ),
            if (r == null)
              const Vacio('Primero calcula el modelo en la pantalla de datos.')
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: naranja.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
                child: Text(estado.recomendacion(), style: const TextStyle(fontSize: 15, height: 1.4)),
              ),
              const SizedBox(height: 18),
              const Text('Tiempo en fila por número de cajas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Tarjeta(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      height: 200,
                      child: CustomPaint(
                          painter: _BarrasPainter(estado.escenariosA(), estado.escenariosB(), numero(estado.g('meta')), cs),
                          size: Size.infinite),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 16, children: [
                      _Leyenda(verde, 'Velocidad actual', cs),
                      _Leyenda(naranja, 'Con mejora', cs),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Escenario A: velocidad actual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _TablaEsc(estado.escenariosA(), r.e.cajas),
              const SizedBox(height: 8),
              const Text('Escenario B: con mejora', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _TablaEsc(estado.escenariosB(), r.e.cajas),
            ],
          ],
        );
      },
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color c;
  final String t;
  final ColorScheme cs;
  const _Leyenda(this.c, this.t, this.cs);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      ]);
}

class _TablaEsc extends StatelessWidget {
  final List<Escenario> l;
  final int hoy;
  const _TablaEsc(this.l, this.hoy);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final validos = l.where((x) => x.costo.isFinite).toList()..sort((a, b) => a.costo.compareTo(b.costo));
    final mejor = validos.isEmpty ? null : validos.first.s;
    Widget celda(String t, {bool izq = false, bool neg = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(t,
              textAlign: izq ? TextAlign.left : TextAlign.right,
              style: TextStyle(fontFamily: izq ? null : 'monospace', fontSize: 12.5, fontWeight: neg ? FontWeight.w800 : FontWeight.w500, color: color)),
        );
    return Tarjeta(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.3)},
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 1.5))),
              children: [
                for (final (i, t) in ['Cajas', 'ρ', 'Lq', 'Wq min', 'W min', 'Costo/h'].indexed)
                  celda(t, izq: i == 0, neg: true, color: cs.onSurfaceVariant),
              ],
            ),
            for (final x in l)
              TableRow(
                decoration: BoxDecoration(
                  color: x.s == mejor ? cs.primaryContainer : null,
                  border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6))),
                ),
                children: x.cola.estable
                    ? [
                        celda('${x.s}${x.s == hoy ? ' (hoy)' : ''}', izq: true, neg: x.s == mejor),
                        celda(pct(x.cola.rho, 1)),
                        celda(nf(x.cola.lq, 2)),
                        celda(nf(x.cola.wq * 60, 2)),
                        celda(nf(x.cola.w * 60, 2)),
                        celda(cop(x.costo)),
                      ]
                    : [
                        celda('${x.s}${x.s == hoy ? ' (hoy)' : ''}', izq: true),
                        celda(pct(x.cola.rho, 1)),
                        celda('Inestable', color: naranja),
                        celda(''),
                        celda(''),
                        celda(''),
                      ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BarrasPainter extends CustomPainter {
  final List<Escenario> a, b;
  final double meta;
  final ColorScheme cs;
  _BarrasPainter(this.a, this.b, this.meta, this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    const x0 = 34.0;
    final y0 = size.height - 30, h = size.height - 44, w = size.width - x0 - 4;
    final estables = [...a, ...b].where((x) => x.cola.estable).map((x) => x.cola.wq * 60).toList();
    double tope = estables.isEmpty ? 1 : estables.reduce(math.max);
    if (meta.isFinite && meta > 0) tope = math.min(tope, math.max(meta * 4, 0.5));
    if (tope <= 0) tope = 1;
    void texto(String t, Offset o, {TextAlign al = TextAlign.center, double tam = 10, Color? color}) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: TextStyle(fontSize: tam, color: color ?? cs.onSurfaceVariant)), textDirection: TextDirection.ltr)
        ..layout();
      final dx = al == TextAlign.center ? o.dx - tp.width / 2 : (al == TextAlign.right ? o.dx - tp.width : o.dx);
      tp.paint(canvas, Offset(dx, o.dy));
    }

    canvas.drawLine(Offset(x0, y0), Offset(x0 + w, y0), Paint()..color = cs.outlineVariant);
    for (int i = 0; i <= 4; i++) {
      final y = y0 - h * i / 4;
      texto(nf(tope * i / 4, 1), Offset(x0 - 4, y - 6), al: TextAlign.right);
      if (i > 0) canvas.drawLine(Offset(x0, y), Offset(x0 + w, y), Paint()..color = cs.outlineVariant.withOpacity(0.4));
    }
    final gw = w / a.length;
    for (int i = 0; i < a.length; i++) {
      for (final (k, e) in [a[i], b[i]].indexed) {
        final bx = x0 + i * gw + 6 + k * ((gw - 12) / 2);
        final bwid = (gw - 12) / 2 - 2;
        if (!e.cola.estable) {
          texto('∞', Offset(bx + bwid / 2, y0 - 16), color: naranja);
          continue;
        }
        final v = math.min(e.cola.wq * 60, tope);
        final bh = h * v / tope;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, y0 - bh, bwid, bh), const Radius.circular(3)),
            Paint()..color = k == 0 ? verde : naranja);
      }
      texto('${a[i].s}', Offset(x0 + i * gw + gw / 2, y0 + 3));
    }
    if (meta.isFinite && meta <= tope) {
      final y = y0 - h * meta / tope;
      final p = Paint()
        ..color = cs.onSurface
        ..strokeWidth = 1.2;
      for (double x = x0; x < x0 + w; x += 9) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, x0 + w), y), p);
      }
      texto('meta ${nf(meta, 1)} min', Offset(x0 + w, y - 14), al: TextAlign.right, color: cs.onSurface);
    }
    texto('cajas atendiendo s · Wq en minutos', Offset(x0 + w / 2, y0 + 16), tam: 11);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
