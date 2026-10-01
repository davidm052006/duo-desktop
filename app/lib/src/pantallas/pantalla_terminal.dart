import 'package:flutter/material.dart';

import 'en_construccion.dart';

/// Terminal — Terminal integrada para ver a los agentes trabajar en vivo.
class PantallaTerminal extends StatelessWidget {
  const PantallaTerminal({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccion(
        titulo: 'Terminal',
        fase: 5,
        descripcion: 'Terminal integrada para ver a los agentes trabajar en vivo.',
      );
}
