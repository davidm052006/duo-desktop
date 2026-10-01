import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/estado/estado_tablero.dart';
import 'src/pantallas/pantalla_tablero.dart';
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
        // El tablero de referencia está diseñado para el tema oscuro.
        themeMode: ThemeMode.dark,
        home: const PantallaTablero(),
      ),
    );
  }
}
