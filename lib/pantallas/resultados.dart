import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../estado.dart';
import '../modelos/colas.dart';
import '../servicios/informe_pdf.dart';
import '../servicios/sonido.dart';
import '../ui/comunes.dart';
import '../ui/formato.dart';

class PantallaResultados extends StatelessWidget {
  final void Function(int) ir;
  const PantallaResultados({super.key, required this.ir});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final r = estado.res;
        if (r == null) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Encabezado('Resultados'),
            Vacio('Aún no hay resultados. Ingresa los datos y toca Calcular.', accion: () => ir(1), textoAccion: 'Ir a datos'),
          ]);
        }
        final q = r.cola;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const Encabezado('Resultados'),
            _Ticket(r: r),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: naranja, minimumSize: const Size.fromHeight(50)),
                  onPressed: q.estable ? () => _pdf(context, compartir: true) : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Guardar PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: q.estable ? () => _pdf(context, compartir: false) : null,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver informe'),
                ),
              ),
            ]),
            const SizedBox(height: 22),
            const Text('Ecuaciones empleadas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Tarjeta(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final e in estado.ecuaciones()) _EcuacionTile(e),
                ]),
              ),
            ),
            if (q.estable) ...[
              const SizedBox(height: 8),
              const Text('Probabilidad de n clientes en el sistema', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Tarjeta(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(height: 190, child: CustomPaint(painter: _PnPainter(q, Theme.of(context).colorScheme), size: Size.infinite)),
                    const SizedBox(height: 8),
                    Text(
                      'Verde: hay cajas libres (n < s). Naranja: todas ocupadas y se forma fila. '
                      'Probabilidad de encontrar todas las cajas ocupadas: ${pct(1 - [for (int n = 0; n < q.s; n++) q.pn(n)].fold(0.0, (a, b) => a + b))}.',
                      style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pdf(BuildContext context, {required bool compartir}) async {
    Sonido.tap();
    try {
      if (compartir) {
        await compartirInforme();
      } else {
        await verInforme();
      }
      Sonido.ding();
    } catch (e) {
      Sonido.error();
      if (context.mounted) aviso(context, 'No se pudo generar el PDF: $e');
    }
  }
}

class _Ticket extends StatelessWidget {
  final Resultado r;
  const _Ticket({required this.r});

  @override
  Widget build(BuildContext context) {
    final q = r.cola;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final fondo = oscuro ? const Color(0xFF1A2624) : papel;
    final tenue = Theme.of(context).colorScheme.onSurfaceVariant;
    const m = TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1);
    Widget linea(String k, String n, String v, {bool grande = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            if (k.isNotEmpty) Text('$k ', style: const TextStyle(fontWeight: FontWeight.w800)),
            Expanded(child: Text(n, style: TextStyle(color: tenue))),
            Text(v, style: TextStyle(fontFamily: 'monospace', fontSize: grande ? 18 : 15, fontWeight: FontWeight.w600)),
          ]),
        );
    Widget guiones() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LayoutBuilder(
            builder: (c, k) => Row(
              children: List.generate((k.maxWidth / 9).floor(), (_) => Container(width: 5, height: 1.5, margin: const EdgeInsets.only(right: 4), color: tenue.withOpacity(0.5))),
            ),
          ),
        );
    return ClipPath(
      clipper: _ClipTicket(),
      child: Container(
        color: fondo,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
        child: Column(children: [
          Text('FILALAB · TICKET DE RESULTADOS', style: m.copyWith(color: tenue)),
          const SizedBox(height: 4),
          Text('Modelo ${r.modelo == 'mm1' ? 'M/M/1' : 'M/M/s'}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          Text([estado.g('lugar'), fecha(estado.g('fecha'))].where((x) => x.isNotEmpty).join(' · '), style: m.copyWith(color: tenue)),
          guiones(),
          Row(children: [
            SizedBox(width: 120, height: 70, child: CustomPaint(painter: _Medidor(q.rho))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('a. Factor de uso ρ', style: TextStyle(fontSize: 13, color: tenue)),
                Text(pct(q.rho), style: const TextStyle(fontFamily: 'monospace', fontSize: 27, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: (q.estable ? verde : naranja).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(q.estable ? '● Sistema estable' : '● Inestable: ρ ≥ 1',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: q.estable ? verde : naranja)),
                ),
              ]),
            ),
          ]),
          guiones(),
          if (q.estable) ...[
            linea('b.', 'Sistema vacío P0', nf(q.p0)),
            if (r.modelo == 'mms') linea('', 'Prob. de esperar Pw', pct(q.pw)),
            linea('c.', 'En fila Lq', '${nf(q.lq)} cl.', grande: true),
            linea('d.', 'Espera en fila Wq', '${nf(q.wq * 60, 2)} min', grande: true),
            linea('e.', 'En el sistema L', '${nf(q.l)} cl.'),
            linea('f.', 'Tiempo en el sistema W', '${nf(q.w * 60, 2)} min'),
          ] else
            Text(
                'Con λ = ${nf(q.lam, 2)} y ${q.s} servidor(es) de μ = ${nf(q.mu, 2)}, llegan más clientes de los que se pueden atender. '
                'Hay que abrir más cajas o atender más rápido.'),
          guiones(),
          Text('λ ${nf(q.lam, 2)} · μ ${nf(q.mu, 2)} · s ${q.s}', style: m.copyWith(color: tenue)),
        ]),
      ),
    );
  }
}

/// Borde inferior en zigzag, como un tiquete de caja.
class _ClipTicket extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const d = 8.0;
    final p = Path()
      ..moveTo(0, 6)
      ..quadraticBezierTo(0, 0, 6, 0)
      ..lineTo(size.width - 6, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 6)
      ..lineTo(size.width, size.height - d);
    double x = size.width;
    bool abajo = true;
    while (x > 0) {
      x -= d;
      p.lineTo(math.max(x, 0), abajo ? size.height : size.height - d);
      abajo = !abajo;
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Medidor extends CustomPainter {
  final double rho;
  _Medidor(this.rho);

  @override
  void paint(Canvas canvas, Size size) {
    final v = rho.isFinite ? rho.clamp(0.0, 1.0) : 0.0;
    final centro = Offset(size.width / 2, size.height - 6);
    final radio = math.min(size.width / 2, size.height) - 8;
    final rect = Rect.fromCircle(center: centro, radius: radio);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x33888888);
    canvas.drawArc(rect, math.pi, math.pi, false, base);
    if (v > 0) {
      final col = rho >= 1 ? naranja : (rho > 0.85 ? naranja : verde);
      canvas.drawArc(rect, math.pi, math.pi * v, false, base..color = col);
    }
  }

  @override
  bool shouldRepaint(covariant _Medidor old) => old.rho != rho;
}

class _EcuacionTile extends StatelessWidget {
  final Ecuacion e;
  const _EcuacionTile(this.e);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(e.formula, style: TextStyle(fontFamily: 'monospace', fontSize: 14.5, color: cs.primary)),
        if (e.sustitucion.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(e.sustitucion, style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: cs.onSurfaceVariant)),
          ),
        const SizedBox(height: 2),
        Text(e.resultado, style: const TextStyle(fontFamily: 'monospace', fontSize: 14.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _PnPainter extends CustomPainter {
  final Cola q;
  final ColorScheme cs;
  _PnPainter(this.q, this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    const nBarras = 14;
    final vals = [for (int n = 0; n < nBarras; n++) q.pn(n)];
    final mx = vals.reduce(math.max);
    const x0 = 34.0;
    final y0 = size.height - 30, h = size.height - 44, w = size.width - x0 - 4;
    final bw = w / nBarras;
    final linea = Paint()
      ..color = cs.outlineVariant
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x0, y0), Offset(x0 + w, y0), linea);
    void texto(String t, Offset o, {TextAlign al = TextAlign.center, double tam = 10}) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: TextStyle(fontSize: tam, color: cs.onSurfaceVariant)), textDirection: TextDirection.ltr)
        ..layout();
      final dx = al == TextAlign.center ? o.dx - tp.width / 2 : (al == TextAlign.right ? o.dx - tp.width : o.dx);
      tp.paint(canvas, Offset(dx, o.dy));
    }

    for (int i = 0; i <= 4; i++) {
      final y = y0 - h * i / 4;
      texto(nf(mx * i / 4, 2), Offset(x0 - 4, y - 6), al: TextAlign.right);
      if (i > 0) canvas.drawLine(Offset(x0, y), Offset(x0 + w, y), Paint()..color = cs.outlineVariant.withOpacity(0.4));
    }
    for (int n = 0; n < nBarras; n++) {
      final bh = mx > 0 ? h * vals[n] / mx : 0.0;
      final x = x0 + n * bw + 3;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y0 - bh, bw - 6, bh), const Radius.circular(3)),
          Paint()..color = n < q.s ? verde : naranja);
      texto('$n', Offset(x + (bw - 6) / 2, y0 + 3));
    }
    texto('n clientes en el sistema', Offset(x0 + w / 2, y0 + 16), tam: 11);
  }

  @override
  bool shouldRepaint(covariant _PnPainter old) => old.q != q;
}
