import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// Visualizaciones — Gráficas del reparto de trabajo y de quién revisó a quién.
class PantallaVisualizaciones extends StatelessWidget {
  const PantallaVisualizaciones({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'Visualizaciones',
        fase: 6,
        descripcion: 'Gráficas del reparto de trabajo y de quién revisó a quién.',
      );
}
