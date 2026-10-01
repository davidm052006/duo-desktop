import 'package:flutter/material.dart';

/// Los colores que la app usa para *datos*, separados de los de la interfaz.
///
/// Son tres cosas distintas y no se mezclan:
///
/// - **Serie** — identidad de cada agente. Orden fijo, nunca ciclado.
/// - **Estado** — en qué punto está una tarea. Reservados: nunca se reutilizan
///   como "un agente más", y siempre van con icono y etiqueta, jamás color solo.
/// - **Tinta** — texto. El texto nunca se pinta del color de su serie.
///
/// Los tres primeros slots categóricos (azul, naranja, aqua) son los únicos que
/// superan los umbrales de separación para daltonismo con todos los pares en
/// juego, que es justo lo que necesitamos: tres agentes. Un cuarto agente no
/// hereda un color nuevo sin volver a validar la paleta.
@immutable
class PaletaDatos extends ThemeExtension<PaletaDatos> {
  const PaletaDatos({
    required this.superficie,
    required this.tintaPrincipal,
    required this.tintaSecundaria,
    required this.tintaTenue,
    required this.rejilla,
    required this.panel,
    required this.acento,
    required this.acentoAlt,
    required this.series,
    required this.bien,
    required this.aviso,
    required this.grave,
    required this.critico,
  });

  final Color superficie;
  final Color tintaPrincipal;
  final Color tintaSecundaria;
  final Color tintaTenue;
  final Color rejilla;

  /// Superficie elevada y acentos que fija el diseño del tablero.
  final Color panel;
  final Color acento;
  final Color acentoAlt;

  /// Slots categóricos en orden fijo: la posición es lo que da la seguridad,
  /// no es decorativo.
  final List<Color> series;

  final Color bien;
  final Color aviso;
  final Color grave;
  final Color critico;

  static const _agentesConocidos = ['chat', 'codex', 'cc'];

  /// El color sigue al agente, no a su puesto en la tabla. Si el tablero cambia
  /// de orden o se filtra, `chat` sigue siendo azul.
  Color serieDe(String agente) {
    final i = _agentesConocidos.indexOf(agente);
    // Un agente desconocido no inventa un color: se queda en tinta neutra.
    return i >= 0 && i < series.length ? series[i] : tintaSecundaria;
  }

  static const claro = PaletaDatos(
    superficie: Color(0xFFFCFCFB),
    tintaPrincipal: Color(0xFF0B0B0B),
    tintaSecundaria: Color(0xFF52514E),
    tintaTenue: Color(0xFF6F6E6A),
    rejilla: Color(0xFFE6E5E1),
    panel: Color(0xFFF4F3F0),
    acento: Color(0xFFC2185B),
    acentoAlt: Color(0xFF0E7490),
    series: [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A)],
    bien: Color(0xFF0CA30C),
    aviso: Color(0xFFFAB219),
    grave: Color(0xFFEC835A),
    critico: Color(0xFFD03B3B),
  );

  /// El modo oscuro no es el claro invertido: son los mismos tonos re-escalonados
  /// para que mantengan contraste sobre la superficie oscura.
  static const oscuro = PaletaDatos(
    superficie: Color(0xFF1A1A19),
    tintaPrincipal: Color(0xFFFFFFFF),
    tintaSecundaria: Color(0xFFC3C2B7),
    tintaTenue: Color(0xFF8E8D84),
    rejilla: Color(0xFF383835),
    panel: Color(0xFF232322),
    acento: Color(0xFFFF8FC4),
    acentoAlt: Color(0xFF5CD7F2),
    series: [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70)],
    bien: Color(0xFF0CA30C),
    aviso: Color(0xFFFAB219),
    grave: Color(0xFFEC835A),
    critico: Color(0xFFD03B3B),
  );

  @override
  PaletaDatos copyWith({
    Color? superficie,
    Color? tintaPrincipal,
    Color? tintaSecundaria,
    Color? tintaTenue,
    Color? rejilla,
    Color? panel,
    Color? acento,
    Color? acentoAlt,
    List<Color>? series,
    Color? bien,
    Color? aviso,
    Color? grave,
    Color? critico,
  }) => PaletaDatos(
    superficie: superficie ?? this.superficie,
    tintaPrincipal: tintaPrincipal ?? this.tintaPrincipal,
    tintaSecundaria: tintaSecundaria ?? this.tintaSecundaria,
    tintaTenue: tintaTenue ?? this.tintaTenue,
    rejilla: rejilla ?? this.rejilla,
    panel: panel ?? this.panel,
    acento: acento ?? this.acento,
    acentoAlt: acentoAlt ?? this.acentoAlt,
    series: series ?? this.series,
    bien: bien ?? this.bien,
    aviso: aviso ?? this.aviso,
    grave: grave ?? this.grave,
    critico: critico ?? this.critico,
  );

  @override
  PaletaDatos lerp(ThemeExtension<PaletaDatos>? otra, double t) {
    if (otra is! PaletaDatos) return this;
    return PaletaDatos(
      superficie: Color.lerp(superficie, otra.superficie, t)!,
      tintaPrincipal: Color.lerp(tintaPrincipal, otra.tintaPrincipal, t)!,
      tintaSecundaria: Color.lerp(tintaSecundaria, otra.tintaSecundaria, t)!,
      tintaTenue: Color.lerp(tintaTenue, otra.tintaTenue, t)!,
      rejilla: Color.lerp(rejilla, otra.rejilla, t)!,
      panel: Color.lerp(panel, otra.panel, t)!,
      acento: Color.lerp(acento, otra.acento, t)!,
      acentoAlt: Color.lerp(acentoAlt, otra.acentoAlt, t)!,
      series: [
        for (var i = 0; i < series.length; i++)
          Color.lerp(series[i], otra.series[i], t)!,
      ],
      bien: Color.lerp(bien, otra.bien, t)!,
      aviso: Color.lerp(aviso, otra.aviso, t)!,
      grave: Color.lerp(grave, otra.grave, t)!,
      critico: Color.lerp(critico, otra.critico, t)!,
    );
  }
}

extension PaletaDeContexto on BuildContext {
  PaletaDatos get paleta => Theme.of(this).extension<PaletaDatos>()!;
}
