import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// Agentes — Estado de cada agente, su tarea actual y su carga acumulada.
class PantallaAgentes extends StatelessWidget {
  const PantallaAgentes({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'Agentes',
        fase: 2,
        descripcion: 'Estado de cada agente, su tarea actual y su carga acumulada.',
      );
}
