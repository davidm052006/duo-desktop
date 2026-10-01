import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// Personalización — Tema, colores, tipografía y fondo de la aplicación.
class PantallaPersonalizacion extends StatelessWidget {
  const PantallaPersonalizacion({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'Personalización',
        fase: 7,
        descripcion: 'Tema, colores, tipografía y fondo de la aplicación.',
      );
}
