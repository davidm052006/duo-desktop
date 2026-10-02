import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'src/estado/estado_tablero.dart';
import 'src/pantallas/fondo_video_config.dart';
import 'src/pantallas/marco_app.dart';
import 'src/tema/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await FondoVideoConfig.cargarPreferenciasVisuales();
  runApp(const AppDuo());
}

class AppDuo extends StatelessWidget {
  const AppDuo({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // `arranca` hace la primera lectura y deja el sondeo en marcha.
      create: (_) => EstadoTablero()..arranca(),
      child: ValueListenableBuilder<double>(
        valueListenable: FondoVideoConfig.opacidadPaneles,
        builder: (context, opacidadPaneles, _) => MaterialApp(
        title: 'duo',
        debugShowCheckedModeBanner: false,
        theme: TemaDuo.claro(opacidadPaneles: opacidadPaneles),
        darkTheme: TemaDuo.oscuro(opacidadPaneles: opacidadPaneles),
        // El modo oscuro no es un reflejo del claro: tiene sus propios pasos de
        // color, validados contra la superficie oscura.
        //
        // Los diseños de `docs/diseno/` fijan el tema oscuro, así que la app
        // arranca en oscuro pase lo que pase en el escritorio. Elegir tema es
        // cosa de Personalización (Fase 7); el tema claro se queda listo.
        themeMode: ThemeMode.dark,
        home: const MarcoApp(),
      ),
      ),
    );
  }
}
