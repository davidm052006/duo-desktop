import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/auth/config_supabase.dart';
import 'src/auth/puerta_auth.dart';
import 'src/estado/estado_tablero.dart';
import 'src/pantallas/fondo_video_config.dart';
import 'src/tema/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isLinux) {
    PathProviderLinux.registerWith();
    SharedPreferencesLinux.registerWith();
  }

  if (!ConfigSupabase.configurado) {
    throw StateError(
      'Faltan SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY. Usa --dart-define.',
    );
  }

  await Supabase.initialize(
    url: ConfigSupabase.url,
    publishableKey: ConfigSupabase.publishableKey,
  );

  await FondoVideoConfig.inicializarPersistencia();
  await FondoVideoConfig.cargarPreferenciasVisuales();
  runApp(const AppDuo());
}

class AppDuo extends StatelessWidget {
  const AppDuo({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EstadoTablero()..arranca(),
      child: ValueListenableBuilder<double>(
        valueListenable: FondoVideoConfig.opacidadPaneles,
        builder: (context, opacidadPaneles, _) => MaterialApp(
          title: 'duo',
          debugShowCheckedModeBanner: false,
          theme: TemaDuo.claro(opacidadPaneles: opacidadPaneles),
          darkTheme: TemaDuo.oscuro(opacidadPaneles: opacidadPaneles),
          themeMode: ThemeMode.dark,
          home: const PuertaAuth(),
        ),
      ),
    );
  }
}
