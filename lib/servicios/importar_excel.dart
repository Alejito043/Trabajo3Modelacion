import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';

/// Resultado de leer la planilla de campo (Reto3_Planilla_*.xlsx).
class DatosPlanilla {
  final String llegadas; // horas hh:mm:ss o minutos, una por línea
  final String servicio; // duraciones en minutos, una por línea
  final Map<String, String> encabezado;
  final int nLlegadas;
  final int nServicio;
  DatosPlanilla(this.llegadas, this.servicio, this.encabezado, this.nLlegadas, this.nServicio);
}

/// Abre el selector de archivos y lee la planilla. Devuelve null si se cancela.
Future<DatosPlanilla?> elegirYLeerPlanilla() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    withData: true,
  );
  if (res == null || res.files.isEmpty) return null;
  final Uint8List? bytes = res.files.single.bytes;
  if (bytes == null) throw Exception('No se pudo leer el archivo.');
  return leerPlanilla(bytes);
}

String _dos(int n) => n.toString().padLeft(2, '0');

String _hms(double seg) {
  final s = seg.round() % 86400;
  return '${_dos(s ~/ 3600)}:${_dos((s % 3600) ~/ 60)}:${_dos(s % 60)}';
}

String _min(double m) => m.toStringAsFixed(4).replaceAll('.', ',');

/// Valor de celda como segundos del día (horas de Excel), o null.
double? _segundos(dynamic valor) {
  if (valor == null) return null;
  try {
    final tipo = valor.runtimeType.toString();
    if (tipo.contains('DateTime')) {
      return (valor.hour as int) * 3600.0 + (valor.minute as int) * 60 + (valor.second as int);
    }
    if (tipo.contains('Time')) {
      final ms = (valor.millisecond as int?) ?? 0;
      return (valor.hour as int) * 3600.0 + (valor.minute as int) * 60 + (valor.second as int) + ms / 1000;
    }
    if (tipo.contains('Double') || tipo.contains('Int')) {
      final d = (valor.value as num).toDouble();
      if (d >= 0 && d < 1) return d * 86400;
      return null;
    }
    final t = valor.toString().trim();
    final m = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})').firstMatch(t);
    if (m != null) {
      return int.parse(m.group(1)!) * 3600.0 + int.parse(m.group(2)!) * 60 + int.parse(m.group(3)!);
    }
  } catch (_) {}
  return null;
}

/// Valor de celda como número (para columnas Min y Seg), o null.
double? _numero(dynamic valor) {
  if (valor == null) return null;
  try {
    final tipo = valor.runtimeType.toString();
    if (tipo.contains('Double') || tipo.contains('Int')) return (valor.value as num).toDouble();
    if (tipo.contains('Formula')) return null;
    return double.tryParse(valor.toString().trim().replaceAll(',', '.'));
  } catch (_) {
    return null;
  }
}

String _texto(dynamic valor) {
  if (valor == null) return '';
  try {
    final tipo = valor.runtimeType.toString();
    if (tipo.contains('Formula')) return '';
    if (tipo.contains('Double') || tipo.contains('Int')) {
      final d = (valor.value as num).toDouble();
      if (d > 20000 && d < 80000) {
        final f = DateTime(1899, 12, 30).add(Duration(days: d.floor()));
        return '${f.year}-${_dos(f.month)}-${_dos(f.day)}';
      }
      return d == d.roundToDouble() ? d.round().toString() : d.toString();
    }
    if (tipo.contains('DateTime') || tipo.contains('Date')) {
      return '${valor.year}-${_dos(valor.month as int)}-${_dos(valor.day as int)}';
    }
    return valor.toString().trim();
  } catch (_) {
    return '';
  }
}

dynamic _celda(List fila, int col) {
  if (col >= fila.length) return null;
  final c = fila[col];
  if (c == null) return null;
  return (c as dynamic).value;
}

DatosPlanilla leerPlanilla(Uint8List bytes) {
  final libro = xl.Excel.decodeBytes(bytes);
  final dynamic hojaL = libro.tables['Llegadas'];
  final dynamic hojaS = libro.tables['Servicio'];
  if (hojaL == null || hojaS == null) {
    throw Exception('El archivo no tiene las hojas "Llegadas" y "Servicio" de la planilla.');
  }
  final List filasL = hojaL.rows as List;
  final List filasS = hojaS.rows as List;

  // ¿Formato con columnas Min/Seg (planilla D1) o solo horas (planilla original)?
  final encL = filasL.length > 3 ? _texto(_celda(filasL[3] as List, 2)).toUpperCase() : '';
  final conMinSegL = encL.contains('MIN');
  final encS = filasS.length > 3 ? _texto(_celda(filasS[3] as List, 4)).toUpperCase() : '';
  final conMinSegS = encS.contains('MIN');

  // Llegadas desde la fila 5 (índice 4).
  final horas = <String>[];
  final entre = <String>[];
  for (int i = 4; i < filasL.length; i++) {
    final fila = filasL[i] as List;
    final h = _segundos(_celda(fila, 1));
    if (h != null) horas.add(_hms(h));
    if (conMinSegL) {
      final mi = _numero(_celda(fila, 2)), se = _numero(_celda(fila, 3));
      if (mi != null || se != null) entre.add(_min((mi ?? 0) + (se ?? 0) / 60));
    }
  }
  final llegadas = entre.length > horas.length ? entre : horas;

  // Servicio: hora inicio (C) y fin (D), o Min (E) y Seg (F).
  final dur = <String>[];
  for (int i = 4; i < filasS.length; i++) {
    final fila = filasS[i] as List;
    if (conMinSegS) {
      final mi = _numero(_celda(fila, 4)), se = _numero(_celda(fila, 5));
      if (mi != null || se != null) {
        dur.add(_min((mi ?? 0) + (se ?? 0) / 60));
        continue;
      }
    }
    final ini = _segundos(_celda(fila, 2)), fin = _segundos(_celda(fila, 3));
    if (ini != null && fin != null) {
      var d = fin - ini;
      if (d < 0) d += 86400;
      if (d > 0) dur.add(_min(d / 60));
    }
  }

  // Encabezado desde la hoja Resumen.
  final enc = <String, String>{};
  final dynamic hojaR = libro.tables['Resumen'];
  if (hojaR != null) {
    final List filasR = hojaR.rows as List;
    String b(int fila) => filasR.length > fila - 1 ? _texto(_celda(filasR[fila - 1] as List, 1)) : '';
    String a(int fila) => filasR.length > fila - 1 ? _texto(_celda(filasR[fila - 1] as List, 0)) : '';
    if (b(4).isNotEmpty) enc['lugar'] = b(4);
    if (b(5).isNotEmpty) enc['fecha'] = b(5);
    final hi = _segundos(filasR.length > 5 ? _celda(filasR[5] as List, 1) : null);
    final hf = _segundos(filasR.length > 6 ? _celda(filasR[6] as List, 1) : null);
    if (hi != null) enc['horaIni'] = _hms(hi).substring(0, 5);
    if (hf != null) enc['horaFin'] = _hms(hf).substring(0, 5);
    String entero(int fila) {
      final n = filasR.length > fila - 1 ? _numero(_celda(filasR[fila - 1] as List, 1)) : null;
      return n == null ? '' : n.round().toString();
    }
    if (a(9).toLowerCase().contains('atendiendo')) {
      if (entero(8).isNotEmpty) enc['cajasInstaladas'] = entero(8);
      if (entero(9).isNotEmpty) enc['cajas'] = entero(9);
    } else if (entero(8).isNotEmpty) {
      enc['cajas'] = entero(8);
    }
  }
  return DatosPlanilla(llegadas.join('\n'), dur.join('\n'), enc, llegadas.length, dur.length);
}
