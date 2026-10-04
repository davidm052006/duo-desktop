import 'package:flutter/material.dart';

import 'paleta.dart';

/// El tema de la interfaz. La Fase 7 ("lo bonito") es donde esto crece; aquí
/// solo se fija lo justo para que la app no parezca una plantilla.
abstract final class TemaDuo {
  static ThemeData claro({double opacidadPaneles = 1.0}) => _construye(
        Brightness.light,
        PaletaDatos.claro.copyWith(
          panel: PaletaDatos.claro.panel.withValues(alpha: opacidadPaneles),
        ),
      );

  static ThemeData oscuro({double opacidadPaneles = 1.0}) => _construye(
        Brightness.dark,
        PaletaDatos.oscuro.copyWith(
          panel: PaletaDatos.oscuro.panel.withValues(alpha: opacidadPaneles),
        ),
      );

  static ThemeData _construye(Brightness brillo, PaletaDatos paleta) {
    final esquema = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9D5CFF),
      brightness: brillo,
      surface: paleta.superficie,
      primary: paleta.acento,
      secondary: paleta.acentoAlt,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: Colors.transparent,
      extensions: [paleta],
      textTheme: _texto(paleta),
      dividerTheme: DividerThemeData(color: paleta.rejilla, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: paleta.panel,
        surfaceTintColor: Colors.transparent,
        foregroundColor: paleta.tintaPrincipal,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paleta.superficie.withValues(alpha: .42),
        labelStyle: TextStyle(color: paleta.tintaSecundaria),
        hintStyle: TextStyle(color: paleta.tintaTenue),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: paleta.rejilla),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: paleta.acentoAlt, width: 1.4),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: paleta.acento,
          foregroundColor: const Color(0xFF100716),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: paleta.acentoAlt,
          side: BorderSide(color: paleta.acentoAlt.withValues(alpha: .45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// Los identificadores (`T-005`, nombres de rama) van en monoespaciada: se
  /// comparan de un vistazo y nunca se confunde `l` con `1`.
  static const familiaMono = 'monospace';

  static TextTheme _texto(PaletaDatos paleta) => TextTheme(
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: paleta.tintaPrincipal,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: paleta.tintaPrincipal,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: paleta.tintaPrincipal, height: 1.4),
    bodySmall: TextStyle(fontSize: 12.5, color: paleta.tintaSecundaria, height: 1.4),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: paleta.tintaTenue,
    ),
  );
}
