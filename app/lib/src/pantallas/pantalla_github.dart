import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// GitHub — Ramas, commits y pull requests sin salir de la app.
class PantallaGitHub extends StatelessWidget {
  const PantallaGitHub({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'GitHub',
        fase: 4,
        descripcion: 'Ramas, commits y pull requests sin salir de la app.',
      );
}
