import 'package:flutter/material.dart';

import 'estado.dart';
import 'pantallas/datos.dart';
import 'pantallas/inicio.dart';
import 'pantallas/mejora.dart';
import 'pantallas/resultados.dart';
import 'pantallas/simulacion.dart';
import 'servicios/sonido.dart';
import 'ui/comunes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await estado.cargar();
  runApp(const FilaLabApp());
}

ThemeData _tema(Brightness b) {
  final cs = ColorScheme.fromSeed(seedColor: verde, brightness: b, secondary: naranja);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF4F1E8) : const Color(0xFF0E1614),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: b == Brightness.light ? papel : const Color(0xFF1A2624),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
    ),
  );
}

class FilaLabApp extends StatelessWidget {
  const FilaLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FilaLab',
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      home: const Inicio(),
    );
  }
}

class Inicio extends StatefulWidget {
  const Inicio({super.key});
  @override
  State<Inicio> createState() => InicioState();
}

class InicioState extends State<Inicio> {
  int pestana = 0;

  void ir(int i) {
    Sonido.tap();
    setState(() => pestana = i);
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      PantallaInicio(ir: ir),
      PantallaDatos(ir: ir),
      PantallaResultados(ir: ir),
      PantallaSimulacion(activa: pestana == 3),
      const PantallaMejora(),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: verde, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          const Text('FilaLab', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          ListenableBuilder(
            listenable: estado,
            builder: (context, _) => IconButton(
              tooltip: 'Sonido',
              icon: Icon(estado.sonido ? Icons.volume_up_outlined : Icons.volume_off_outlined),
              onPressed: () {
                estado.set('sonido', estado.sonido ? 'no' : 'si');
                Sonido.tap();
              },
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: pestana, children: paginas)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pestana,
        onDestinationSelected: ir,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.edit_outlined), selectedIcon: Icon(Icons.edit), label: 'Datos'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Resultados'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: 'Simular'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Mejora'),
        ],
      ),
    );
  }
}
