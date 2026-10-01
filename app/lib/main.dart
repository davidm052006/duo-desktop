import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/estado/estado_tablero.dart';
import 'src/pantallas/marco_app.dart';
import 'src/tema/tema.dart';

void main() {
  runApp(const AppDuo());
}

class AppDuo extends StatelessWidget {
  const AppDuo({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // `arranca` hace la primera lectura y deja el sondeo en marcha.
      create: (_) => EstadoTablero()..arranca(),
      child: MaterialApp(
        title: 'duo',
        debugShowCheckedModeBanner: false,
        theme: TemaDuo.claro(),
        darkTheme: TemaDuo.oscuro(),
        // El modo oscuro no es un reflejo del claro: tiene sus propios pasos de
        // color, validados contra la superficie oscura.
        //
        // Los diseños de `docs/diseno/` fijan el tema oscuro, así que la app
        // arranca en oscuro pase lo que pase en el escritorio. Elegir tema es
        // cosa de Personalización (Fase 7); el tema claro se queda listo.
        themeMode: ThemeMode.dark,
        home: const MarcoApp(),
      ),
    );
  }
}
