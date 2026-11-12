import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../estado.dart';
import '../modelos/colas.dart';
import '../ui/formato.dart';

Future<Uint8List> generarInforme() async {
  final r = estado.res!;
  final q = r.cola, e = r.e;
  final fuente = pw.Font.ttf(await rootBundle.load('assets/fuentes/DejaVuSans.ttf'));
  final fuenteB = pw.Font.ttf(await rootBundle.load('assets/fuentes/DejaVuSans-Bold.ttf'));
  final doc = pw.Document(title: 'Informe de teoría de colas', author: 'FilaLab');

  final h1 = pw.TextStyle(font: fuenteB, fontSize: 17);
  final h2 = pw.TextStyle(font: fuenteB, fontSize: 12.5);
  final tx = pw.TextStyle(font: fuente, fontSize: 10);
  final peq = pw.TextStyle(font: fuente, fontSize: 8.5);

  pw.Widget titulo(String t) => pw.Padding(padding: const pw.EdgeInsets.only(top: 12, bottom: 6), child: pw.Text(t, style: h2));
  pw.Widget parrafo(String t) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(t, style: tx));
  pw.Widget tabla(List<String> enc, List<List<String>> filas, {double tam = 9}) => pw.TableHelper.fromTextArray(
        headers: enc,
        data: filas,
        headerStyle: pw.TextStyle(font: fuenteB, fontSize: tam),
        cellStyle: pw.TextStyle(font: fuente, fontSize: tam),
        border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
        cellPadding: const pw.EdgeInsets.all(3),
        cellAlignment: pw.Alignment.centerLeft,
      );

  List<String> filaDatos(String nombre, Estadistica s) => [
        nombre,
        s.n == 0 ? 'Promedio ingresado' : '${s.n}',
        nf(s.media),
        s.n > 1 ? nf(s.desv) : '–',
        s.n > 1 ? nf(s.cv, 3) : '–',
      ];

  List<List<String>> filasEsc(List<Escenario> l) => [
        for (final x in l)
          x.cola.estable
              ? ['${x.s}', pct(x.cola.rho, 1), nf(x.cola.lq, 3), nf(x.cola.wq * 60, 2), nf(x.cola.w * 60, 2), cop(x.costo)]
              : ['${x.s}', pct(x.cola.rho, 1), 'Inestable', '', '', '']
      ];

  final mc = estado.mc;
  int sec = 1;
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(46, 40, 46, 40),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Generado con FilaLab · ${fecha(r.cuando.toIso8601String())}', style: peq),
      pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: peq),
    ]),
    build: (ctx) => [
      pw.Text('INFORME DE TEORÍA DE COLAS', style: h1),
      pw.SizedBox(height: 4),
      pw.Text('Filas en el área de cajas de un supermercado en hora pico', style: tx),
      pw.Text('Reto 3 · Modelamiento y simulación computacional · Universidad Católica Luis Amigó', style: peq),
      pw.Text('Integrantes: ${equipo.join(', ')}', style: peq),
      titulo('${sec++}. Datos de la observación'),
      tabla(['Campo', 'Valor'], [
        ['Lugar', estado.g('lugar').isEmpty ? 'Sin especificar' : estado.g('lugar')],
        ['Fecha', estado.g('fecha').isEmpty ? 'Sin especificar' : fecha(estado.g('fecha'))],
        ['Horario', '${estado.g('horaIni')} a ${estado.g('horaFin')}'],
        ['Cajas instaladas', estado.g('cajasInstaladas')],
        ['Cajas atendiendo', estado.g('cajas')],
        if (estado.g('fuente').isNotEmpty) ['Origen de los datos', estado.g('fuente')],
      ]),
      titulo('${sec++}. Datos de entrada'),
      tabla(['Variable', 'Datos', 'Media (min)', 'Desv. est. (min)', 'CV'],
          [filaDatos('Tiempo entre llegadas', e.llegadas), filaDatos('Tiempo de atención', e.servicio)]),
      pw.SizedBox(height: 4),
      parrafo('Tasa de llegada λ = ${nf(e.lam)} clientes/h. Tasa de servicio μ = ${nf(e.mu)} clientes/h por caja.'),
      titulo('${sec++}. Modelo y supuestos'),
      parrafo(r.modelo == 'mm1' ? 'Modelo seleccionado: M/M/1 (un servidor).' : 'Modelo seleccionado: M/M/s con s = ${q.s} servidores.'),
      for (final s in const [
        'Las llegadas siguen un proceso de Poisson (tiempos entre llegadas exponenciales).',
        'Los tiempos de atención son exponenciales e independientes.',
        'Disciplina FIFO: se atiende en orden de llegada.',
        'Población infinita y capacidad de fila ilimitada.',
        'El sistema está en estado estable (ρ < 1).',
      ])
        pw.Bullet(text: s, style: tx),
      titulo('${sec++}. Ecuaciones y resultados'),
      tabla(['Medida', 'Ecuación', 'Sustitución', 'Resultado'],
          [for (final x in estado.ecuaciones()) [x.titulo, x.formula, x.sustitucion, x.resultado]],
          tam: 7.5),
      if (q.estable) ...[
        pw.SizedBox(height: 6),
        tabla(['n', for (int n = 0; n <= 8; n++) '$n'], [
          ['Pn', for (int n = 0; n <= 8; n++) nf(q.pn(n), 4)]
        ], tam: 7.5),
      ],
      if (mc != null) ...[
        titulo('${sec++}. Simulación Montecarlo'),
        tabla(['Medida', 'Teórico', 'Montecarlo', 'IC 95 %'], [
          ['Wq (min)', nf(q.wq * 60, 3), nf(mc.wq * 60, 3), '± ${nf(mc.wqIc * 60, 3)}'],
          ['W (min)', nf(q.w * 60, 3), nf(mc.w * 60, 3), '± ${nf(mc.wIc * 60, 3)}'],
        ]),
        pw.SizedBox(height: 4),
        parrafo('${mc.replicas} réplicas de ${mc.clientes} clientes, descartando los primeros ${mc.calentamiento} de cada una.'),
      ],
      titulo('${sec++}. Escenarios de mejora'),
      parrafo('Costo de cajero: ${cop(numero(estado.g('costoCajero')))}/h. Costo de espera: ${cop(numero(estado.g('costoEspera')))}/h. '
          'Mejora supuesta en la velocidad de atención: ${nf(estado.mejora * 100, 0)} %.'),
      pw.Text('Escenario A: velocidad actual', style: pw.TextStyle(font: fuenteB, fontSize: 10)),
      pw.SizedBox(height: 3),
      tabla(['Cajas s', 'ρ', 'Lq', 'Wq (min)', 'W (min)', 'Costo total/h'], filasEsc(estado.escenariosA())),
      pw.SizedBox(height: 8),
      pw.Text('Escenario B: con mejora en la velocidad de atención', style: pw.TextStyle(font: fuenteB, fontSize: 10)),
      pw.SizedBox(height: 3),
      tabla(['Cajas s', 'ρ', 'Lq', 'Wq (min)', 'W (min)', 'Costo total/h'], filasEsc(estado.escenariosB())),
      titulo('${sec++}. Recomendación'),
      parrafo(estado.recomendacion()),
    ],
  ));
  return doc.save();
}

String nombreInforme() {
  final f = estado.g('fecha').isEmpty ? DateTime.now().toIso8601String().substring(0, 10) : estado.g('fecha');
  return 'Informe_colas_$f.pdf';
}

Future<void> compartirInforme() async {
  final bytes = await generarInforme();
  await Printing.sharePdf(bytes: bytes, filename: nombreInforme());
}

Future<void> verInforme() async {
  await Printing.layoutPdf(name: nombreInforme(), onLayout: (_) => generarInforme());
}
