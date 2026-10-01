import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// Historial — Línea de tiempo de todo lo que han hecho los agentes.
class PantallaHistorial extends StatelessWidget {
  const PantallaHistorial({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'Historial',
        fase: 6,
        descripcion: 'Línea de tiempo de todo lo que han hecho los agentes.',
      );
}
