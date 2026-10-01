import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// Configuración — Proyecto activo, rutas de duo y ajustes del servicio local.
class PantallaConfiguracion extends StatelessWidget {
  const PantallaConfiguracion({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'Configuración',
        fase: 7,
        descripcion: 'Proyecto activo, rutas de duo y ajustes del servicio local.',
      );
}
