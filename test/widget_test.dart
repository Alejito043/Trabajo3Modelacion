import 'package:filalab/ui/formato.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Formato colombiano de números', () {
    expect(nf(1234.5, 2), '1.234,50');
    expect(pct(0.8, 1), '80,0 %');
  });
}
