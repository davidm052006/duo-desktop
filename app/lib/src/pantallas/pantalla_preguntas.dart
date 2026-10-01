import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// Preguntas — Preguntas pendientes de los agentes y el canal para responderlas.
class PantallaPreguntas extends StatelessWidget {
  const PantallaPreguntas({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'Preguntas',
        fase: 3,
        descripcion: 'Preguntas pendientes de los agentes y el canal para responderlas.',
      );
}
