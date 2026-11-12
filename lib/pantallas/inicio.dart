import 'package:flutter/material.dart';

import '../estado.dart';
import '../ui/comunes.dart';

class PantallaInicio extends StatelessWidget {
  final void Function(int) ir;
  const PantallaInicio({super.key, required this.ir});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(color: verde, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 120, child: _FilaAnimada()),
            const SizedBox(height: 8),
            const Text('Colas en cajas de supermercado',
                style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              'Ingresa los datos de campo, elige M/M/1 o M/M/s y obtén los resultados con sus ecuaciones, escenarios de mejora y un informe en PDF.',
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: naranja, minimumSize: const Size(0, 48)),
                onPressed: () => ir(1),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Empezar'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size(0, 48)),
                onPressed: () {
                  estado.cargarD1();
                  aviso(context, 'Datos de la planilla D1 cargados. Revisa y toca Calcular.');
                  ir(1);
                },
                child: const Text('Cargar datos D1'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Cómo funciona', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Tarjeta(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: const [
              _Paso(1, 'Datos de campo', 'Promedios, lista de tiempos o la planilla de Excel.'),
              _Paso(2, 'Modelo', 'M/M/1 (una caja) o M/M/s (varias cajas, una fila).'),
              _Paso(3, 'Resultados', 'ρ, P0, Lq, Wq, L y W con cada ecuación paso a paso.'),
              _Paso(4, 'Simulación y mejora', 'Animación de la fila, Montecarlo y escenarios con costos.'),
              _Paso(5, 'Informe PDF', 'Todo el análisis listo para guardar o compartir.'),
            ]),
          ),
        ),
        Tarjeta(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reto 3 · Modelamiento estocástico', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Modelamiento y simulación computacional · Universidad Católica Luis Amigó',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final n in equipo) Chip(label: Text(n, style: const TextStyle(fontSize: 12)))]),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  final int n;
  final String t, d;
  const _Paso(this.n, this.t, this.d);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 14,
            backgroundColor: naranja.withOpacity(0.15),
            child: Text('$n', style: const TextStyle(color: naranja, fontWeight: FontWeight.w800, fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$t. ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: d, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
        ),
      ]),
    );
  }
}

/// Clientes que avanzan hacia una caja en el banner de inicio.
class _FilaAnimada extends StatefulWidget {
  const _FilaAnimada();
  @override
  State<_FilaAnimada> createState() => _FilaAnimadaState();
}

class _FilaAnimadaState extends State<_FilaAnimada> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: c, builder: (context, _) => CustomPaint(painter: _BannerPainter(c.value), size: Size.infinite));
  }
}

class _BannerPainter extends CustomPainter {
  final double t;
  _BannerPainter(this.t);
  static const colores = [Color(0xFFF0643A), Color(0xFFFFD27A), Color(0xFF9EE6D2), Colors.white, Color(0xB3FFFFFF)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final suelo = Paint()..color = Colors.white.withOpacity(0.18);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h - 14, w, 10), const Radius.circular(5)), suelo);
    // Caja registradora
    final caja = RRect.fromRectAndRadius(Rect.fromLTWH(w - 110, h - 62, 100, 46), const Radius.circular(10));
    canvas.drawRRect(caja, Paint()..color = Colors.white.withOpacity(0.95));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w - 98, h - 52, 34, 20), const Radius.circular(4)), Paint()..color = verde);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w - 56, h - 50, 36, 5), const Radius.circular(3)), Paint()..color = naranja);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w - 56, h - 40, 24, 5), const Radius.circular(3)), Paint()..color = const Color(0xFFCFE7E0));
    // Ticket que sale
    final alto = 26 * (0.5 + 0.5 * (t < 0.5 ? t * 2 : 2 - t * 2));
    canvas.drawRect(Rect.fromLTWH(w - 48, h - 62 - alto, 22, alto), Paint()..color = papel);
    // Clientes en fila, avanzando
    const paso = 34.0;
    for (int i = 0; i < 6; i++) {
      final x = (w - 140) - i * paso + t * paso;
      if (x < -20) continue;
      final p = Paint()..color = colores[i % colores.length].withOpacity(i == 5 ? t : 1);
      canvas.drawCircle(Offset(x, h - 40), 11, p);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 8, h - 30, 16, 12), const Radius.circular(4)), p);
    }
    final tp = TextPainter(
      text: TextSpan(text: 'λ · μ · ρ · P0 · Lq · Wq · L · W', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
    tp.paint(canvas, const Offset(0, 4));
  }

  @override
  bool shouldRepaint(covariant _BannerPainter old) => old.t != t;
}
