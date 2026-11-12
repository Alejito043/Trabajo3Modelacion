import 'package:filalab/modelos/colas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M/M/s del ejercicio del banco (λ=80, μ=50, s=2)', () {
    final c = Cola(80, 50, 2);
    expect(c.rho, closeTo(0.8, 1e-9));
    expect(c.p0, closeTo(0.11111, 1e-4));
    expect(c.lq, closeTo(2.84444, 1e-4));
    expect(c.wq * 60, closeTo(2.1333, 1e-3));
  });

  test('M/M/1 coincide con sus fórmulas', () {
    final c = Cola(30, 40, 1);
    expect(c.p0, closeTo(0.25, 1e-9));
    expect(c.lq, closeTo(0.75 * 0.75 / 0.25, 1e-9));
    expect(c.w, closeTo(1 / (40 - 30), 1e-9));
  });

  test('Lectura de horas de llegada', () {
    final e = leerLlegadas('15:15:00\n15:16:15\n15:18:00');
    expect(e.n, 2);
    expect(e.media, closeTo(1.5, 1e-9));
  });

  test('Lectura de duraciones en segundos', () {
    final e = leerServicio('30\n90', enSegundos: true);
    expect(e.media, closeTo(1.0, 1e-9));
  });
}
