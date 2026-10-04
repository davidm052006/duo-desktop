import 'package:flutter/material.dart';

import '../tema/paleta.dart';

/// El panel con el que está hecho el centro de control: un rectángulo con
/// borde, un encabezado y lo que sea dentro.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.titulo,
    required this.icono,
    required this.hijo,
    this.sufijo,
    this.pie,
    this.relleno = const EdgeInsets.all(18),
  });

  final String titulo;
  final IconData icono;
  final Widget hijo;

  /// A la derecha del título: una cifra, una insignia, un recuento.
  final Widget? sufijo;

  /// La línea de abajo del panel, separada por una regla.
  final Widget? pie;
  final EdgeInsets relleno;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    return Container(
      decoration: BoxDecoration(
        color: paleta.panel,
        border: Border.all(
          color: paleta.acentoAlt.withValues(alpha: .16),
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: paleta.acento.withValues(alpha: .045),
            blurRadius: 24,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: paleta.acentoAlt.withValues(alpha: .035),
            blurRadius: 18,
          ),
        ],
      ),
      padding: relleno,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: paleta.acentoAlt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?sufijo,
            ],
          ),
          const SizedBox(height: 16),
          hijo,
          if (pie != null) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: paleta.rejilla),
            const SizedBox(height: 12),
            pie!,
          ],
        ],
      ),
    );
  }
}

/// Una pastilla de texto. `tono` es solo el refuerzo: el texto va siempre, así
/// que nada depende de distinguir el color.
class Insignia extends StatelessWidget {
  const Insignia(this.texto, {super.key, this.tono, this.mono = false});

  final String texto;
  final Color? tono;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final color = tono ?? paleta.tintaTenue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontFamily: mono ? 'monospace' : null,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Lo que todavía no existe se enseña con su fase escrita al lado, en vez de
/// esconderlo: así se ve a dónde va la app (`docs/diseno/README.md`).
class MarcaFase extends StatelessWidget {
  const MarcaFase(this.fase, {super.key});

  final int fase;

  @override
  Widget build(BuildContext context) =>
      Insignia('Fase $fase', tono: context.paleta.tintaTenue);
}

/// Texto en monoespaciada: rutas, ramas, identificadores.
class Mono extends StatelessWidget {
  const Mono(this.texto, {super.key, this.color, this.peso});

  final String texto;
  final Color? color;
  final FontWeight? peso;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: color,
      fontWeight: peso,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
