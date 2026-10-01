import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// Tareas — Lista completa de tareas con filtro por agente, estado y etiqueta.
class PantallaTareas extends StatelessWidget {
  const PantallaTareas({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'Tareas',
        fase: 2,
        descripcion: 'Lista completa de tareas con filtro por agente, estado y etiqueta.',
      );
}
