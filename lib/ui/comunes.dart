import 'package:flutter/material.dart';

const verde = Color(0xFF0E6B5A);
const naranja = Color(0xFFF0643A);
const papel = Color(0xFFFFFDF6);

class Seccion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final List<Widget> hijos;
  const Seccion({super.key, required this.icono, required this.titulo, required this.hijos});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tarjeta(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Icon(icono, size: 19, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
          ]),
          const SizedBox(height: 12),
          ...hijos,
        ]),
      ),
    );
  }
}

class Encabezado extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  const Encabezado(this.titulo, {super.key, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        if (subtitulo != null) ...[
          const SizedBox(height: 4),
          Text(subtitulo!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

class Derivado extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const Derivado(this.etiqueta, this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Text(etiqueta, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer))),
        Text(valor, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 16, color: cs.onPrimaryContainer)),
      ]),
    );
  }
}

class Vacio extends StatelessWidget {
  final String texto;
  final VoidCallback? accion;
  final String? textoAccion;
  const Vacio(this.texto, {super.key, this.accion, this.textoAccion});

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(texto),
          if (accion != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: accion, child: Text(textoAccion ?? 'Ir')),
          ],
        ]),
      ),
    );
  }
}

const mono = TextStyle(fontFamily: 'monospace');

/// Tarjeta con el estilo de la app (sin depender de CardTheme, que cambia entre versiones de Flutter).
class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsets margen;
  final Color? color;
  const Tarjeta({super.key, required this.child, this.margen = const EdgeInsets.only(bottom: 14), this.color});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margen,
      decoration: BoxDecoration(
        color: color ?? (oscuro ? const Color(0xFF16211F) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: oscuro ? const Color(0xFF26332F) : const Color(0xFFE2DDCF)),
      ),
      child: child,
    );
  }
}

void aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));
}
