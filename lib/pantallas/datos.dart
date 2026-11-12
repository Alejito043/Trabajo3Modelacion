import 'package:flutter/material.dart';

import '../estado.dart';
import '../modelos/colas.dart';
import '../servicios/importar_excel.dart';
import '../servicios/sonido.dart';
import '../ui/comunes.dart';
import '../ui/formato.dart';

/// Campo de texto enlazado a una clave del estado.
class Campo extends StatefulWidget {
  final String clave;
  final String etiqueta;
  final String? pista;
  final TextInputType teclado;
  final int lineas;
  final bool monoespacio;
  const Campo(this.clave, this.etiqueta,
      {super.key, this.pista, this.teclado = TextInputType.text, this.lineas = 1, this.monoespacio = false});

  @override
  State<Campo> createState() => _CampoState();
}

class _CampoState extends State<Campo> {
  late final TextEditingController ctl = TextEditingController(text: estado.g(widget.clave));
  final FocusNode foco = FocusNode();

  void _sincronizar() {
    final v = estado.g(widget.clave);
    if (!foco.hasFocus && ctl.text != v) ctl.text = v;
  }

  @override
  void initState() {
    super.initState();
    estado.addListener(_sincronizar);
  }

  @override
  void didUpdateWidget(covariant Campo old) {
    super.didUpdateWidget(old);
    if (old.clave != widget.clave) ctl.text = estado.g(widget.clave);
  }

  @override
  void dispose() {
    estado.removeListener(_sincronizar);
    ctl.dispose();
    foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctl,
        focusNode: foco,
        keyboardType: widget.lineas > 1 ? TextInputType.multiline : widget.teclado,
        minLines: widget.lineas > 1 ? widget.lineas : 1,
        maxLines: widget.lineas > 1 ? widget.lineas + 4 : 1,
        style: widget.monoespacio ? const TextStyle(fontFamily: 'monospace', fontSize: 14) : null,
        decoration: InputDecoration(labelText: widget.etiqueta, hintText: widget.pista, alignLabelWithHint: widget.lineas > 1),
        onChanged: (t) => estado.set(widget.clave, t),
      ),
    );
  }
}

class Selector extends StatelessWidget {
  final String clave;
  final Map<String, String> opciones;
  const Selector(this.clave, this.opciones, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [for (final e in opciones.entries) ButtonSegment(value: e.key, label: Text(e.value))],
        selected: {estado.g(clave)},
        onSelectionChanged: (s) {
          Sonido.tap();
          estado.set(clave, s.first);
        },
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final Estadistica s;
  const _Stats(this.s);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (s.n == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Sin datos todavía.', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    Widget caja(String v, String e) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(v, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              Text(e, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [caja('${s.n}', 'datos'), caja(nf(s.media, 2), 'media min'), caja(nf(s.desv, 2), 'desv. min'), caja(nf(s.cv, 2), 'CV')]),
        if (s.invalidos > 0)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${s.invalidos} valor(es) no reconocido(s) se ignoraron.', style: TextStyle(fontSize: 12, color: cs.error))),
        if (s.n < 30)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Se recomiendan mínimo 30 datos.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
      ]),
    );
  }
}

class PantallaDatos extends StatefulWidget {
  final void Function(int) ir;
  const PantallaDatos({super.key, required this.ir});
  @override
  State<PantallaDatos> createState() => _PantallaDatosState();
}

class _PantallaDatosState extends State<PantallaDatos> {
  List<String> errores = const [];

  Future<void> _importar() async {
    Sonido.tap();
    try {
      final d = await elegirYLeerPlanilla();
      if (d == null) return;
      if (d.nLlegadas < 2 || d.nServicio < 2) {
        if (mounted) aviso(context, 'No encontré datos en las hojas Llegadas y Servicio.');
        return;
      }
      estado.setVarios({
        ...d.encabezado,
        'llegModo': 'datos',
        'llegRaw': d.llegadas,
        'llegUnidad': 'min',
        'servModo': 'datos',
        'servRaw': d.servicio,
        'servUnidad': 'min',
        'fuente': 'Planilla de Excel importada',
      });
      Sonido.ding();
      if (mounted) aviso(context, 'Planilla importada: ${d.nLlegadas} llegadas y ${d.nServicio} atenciones.');
    } catch (e) {
      Sonido.error();
      if (mounted) aviso(context, 'No se pudo leer la planilla: $e');
    }
  }

  void _calcular() {
    FocusScope.of(context).unfocus();
    final err = estado.calcular();
    setState(() => errores = err);
    if (err.isNotEmpty) {
      Sonido.error();
      return;
    }
    Sonido.ding();
    widget.ir(2);
    if (!estado.res!.cola.estable) aviso(context, 'ρ ≥ 1: el sistema es inestable, la fila crece sin límite.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final e = estado.entradas();
        final cs = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const Encabezado('Datos de campo', subtitulo: 'Todo se guarda en el celular automáticamente.'),
            Tarjeta(
              color: cs.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Importar planilla de Excel', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Lee las hojas Llegadas, Servicio y Resumen de la planilla de campo (.xlsx).'),
                onTap: _importar,
              ),
            ),
            if (estado.g('fuente').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Origen: ${estado.g('fuente')}', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
              ),
            Seccion(icono: Icons.place_outlined, titulo: 'Observación', hijos: [
              const Campo('lugar', 'Lugar (supermercado y sede)', pista: 'Ej. D1 Colombia'),
              const Row(children: [
                Expanded(child: Campo('fecha', 'Fecha (aaaa-mm-dd)', pista: '2026-11-12')),
                SizedBox(width: 10),
                Expanded(child: Campo('cajasInstaladas', 'Cajas instaladas', teclado: TextInputType.number, monoespacio: true)),
              ]),
              const Row(children: [
                Expanded(child: Campo('horaIni', 'Hora inicio', pista: '15:15')),
                SizedBox(width: 10),
                Expanded(child: Campo('horaFin', 'Hora fin', pista: '16:00')),
              ]),
              const Campo('cajas', 'Cajas atendiendo', teclado: TextInputType.number, monoespacio: true),
            ]),
            Seccion(icono: Icons.directions_walk, titulo: 'Llegadas de clientes', hijos: [
              const Selector('llegModo', {'prom': 'Promedio', 'datos': 'Datos de campo'}),
              if (estado.g('llegModo') == 'prom')
                const Campo('llegProm', 'Tiempo promedio entre llegadas (min)', teclado: TextInputType.numberWithOptions(decimal: true), monoespacio: true)
              else ...[
                const Selector('llegUnidad', {'min': 'En minutos', 'seg': 'En segundos'}),
                const Campo('llegRaw', 'Horas de llegada o tiempos entre llegadas',
                    pista: '15:16:15\n15:18:00\n...\no tiempos: 1,25  1,75 ...', lineas: 5, monoespacio: true),
                _Stats(e.llegadas),
              ],
              Derivado('Tasa de llegada λ', e.lam.isFinite ? '${nf(e.lam, 2)} cl/h' : '–'),
            ]),
            Seccion(icono: Icons.point_of_sale_outlined, titulo: 'Tiempo de atención', hijos: [
              const Selector('servModo', {'prom': 'Promedio', 'datos': 'Datos de campo'}),
              if (estado.g('servModo') == 'prom')
                const Campo('servProm', 'Tiempo promedio de atención (min)', teclado: TextInputType.numberWithOptions(decimal: true), monoespacio: true)
              else ...[
                const Selector('servUnidad', {'min': 'En minutos', 'seg': 'En segundos'}),
                const Campo('servRaw', 'Duraciones de atención', pista: '0,42\n0,52\n1:05 (min:seg)\n...', lineas: 5, monoespacio: true),
                _Stats(e.servicio),
              ],
              Derivado('Tasa de servicio μ (por caja)', e.mu.isFinite ? '${nf(e.mu, 2)} cl/h' : '–'),
            ]),
            Seccion(icono: Icons.view_list_outlined, titulo: 'Modelo de colas', hijos: [
              Row(children: [
                Expanded(child: _Modelo('mm1', 'M/M/1', 'Un servidor. Una caja atendiendo.')),
                const SizedBox(width: 10),
                Expanded(child: _Modelo('mms', 'M/M/s', 'Varias cajas atendiendo una sola fila.')),
              ]),
              const SizedBox(height: 12),
              if (estado.g('modelo') == 'mms')
                const Campo('servidores', 'Número de servidores s', teclado: TextInputType.number, monoespacio: true)
              else
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repartir las llegadas entre las cajas atendiendo (λ / cajas)', style: TextStyle(fontSize: 14)),
                  value: estado.g('porCaja') == 'si',
                  onChanged: (b) => estado.set('porCaja', b ? 'si' : 'no'),
                ),
              if (errores.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(errores.join('\n'), style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w600)),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _calcular,
                icon: const Icon(Icons.check),
                label: const Text('Calcular', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _Modelo extends StatelessWidget {
  final String clave, titulo, desc;
  const _Modelo(this.clave, this.titulo, this.desc);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = estado.g('modelo') == clave;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Sonido.tap();
        final cambios = <String, String>{'modelo': clave};
        if (clave == 'mms' && (int.tryParse(estado.g('servidores')) ?? 0) < 2) {
          cambios['servidores'] = estado.g('cajasInstaladas').isEmpty ? '2' : estado.g('cajasInstaladas');
        }
        estado.setVarios(cambios);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? cs.primaryContainer : null,
          border: Border.all(color: on ? cs.primary : cs.outlineVariant, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
