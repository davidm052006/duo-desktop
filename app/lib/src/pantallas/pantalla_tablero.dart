import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/carga_agentes.dart';
import '../widgets/panel_fallo.dart';
import '../widgets/tablero_kanban.dart';

/// El tablero. Fase 2: Kanban de solo lectura sobre el endpoint existente.
class PantallaTablero extends StatelessWidget {
  const PantallaTablero({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTablero>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: _Titulo(proyecto: estado.tablero?.proyecto),
        actions: [
          if (estado.obsoleto) _AvisoObsoleto(mensaje: estado.fallo!.mensaje),
          _Reloj(momento: estado.ultimaLectura),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: estado.refresca,
            icon: const Icon(Icons.refresh, size: 19),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: switch (estado.fase) {
        Fase.inicial || Fase.cargando => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        Fase.fallo => Padding(
          padding: const EdgeInsets.all(24),
          child: PanelFallo(
            fallo: estado.fallo!,
            alReintentar: estado.refresca,
          ),
        ),
        Fase.listo => _Contenido(tablero: estado.tablero!),
      },
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.proyecto});

  final Proyecto? proyecto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Tablero', style: textos.headlineSmall),
        if (proyecto != null) ...[
          const SizedBox(width: 10),
          Text(
            proyecto!.nombre,
            style: textos.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ],
    );
  }
}

/// Hay datos en pantalla, pero el último refresco falló: decirlo es mejor que
/// mostrar datos viejos como si fueran frescos.
class _AvisoObsoleto extends StatelessWidget {
  const _AvisoObsoleto({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Tooltip(
      message: mensaje,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: paleta.aviso),
            const SizedBox(width: 6),
            Text('sin conexión', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Reloj extends StatelessWidget {
  const _Reloj({required this.momento});

  final DateTime? momento;

  @override
  Widget build(BuildContext context) {
    if (momento == null) return const SizedBox.shrink();
    final h = momento!;
    final texto =
        '${h.hour.toString().padLeft(2, '0')}:'
        '${h.minute.toString().padLeft(2, '0')}:'
        '${h.second.toString().padLeft(2, '0')}';
    return Text(
      texto,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        color: context.paleta.tintaTenue,
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.tablero});

  final Tablero tablero;

  static const _anchoPanelLateral = 320.0;
  static const _separacion = 18.0;
  // A partir de 760 px el Kanban ya puede desplazarse horizontalmente y el
  // resumen conserva su sitio visible. En su ancho de 320 px, CargaAgentes
  // usa su composición compacta.
  static const _umbralDosColumnas = 760.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final anchoDisponible = limites.maxWidth;
        final dosColumnas = anchoDisponible >= _umbralDosColumnas;

        if (dosColumnas) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AvisoFaseUno(),
                const SizedBox(height: 14),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: TableroKanban(tareas: tablero.tareas),
                      ),
                      const SizedBox(width: _separacion),
                      SizedBox(
                        width: _anchoPanelLateral,
                        child: _PanelResumen(tablero: tablero),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _AvisoFaseUno(),
            const SizedBox(height: 14),
            SizedBox(
              height: 560,
              child: TableroKanban(tareas: tablero.tareas),
            ),
            const SizedBox(height: 20),
            _PanelResumen(tablero: tablero),
          ],
        );
      },
    );
  }
}

class _PanelResumen extends StatelessWidget {
  const _PanelResumen({required this.tablero});

  final Tablero tablero;

  @override
  Widget build(BuildContext context) {
    final contenido = <Widget>[
      _Seccion(
        titulo: 'Carga acumulada',
        hijo: CargaAgentes(
          agentes: tablero.agentes,
          maximo: tablero.puntosMaximos,
        ),
      ),
      if (tablero.proyecto != null) ...[
        const SizedBox(height: 22),
        _Procedencia(proyecto: tablero.proyecto!),
      ],
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.paleta.panel,
        border: Border.all(color: context.paleta.rejilla),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: contenido,
        ),
      ),
    );
  }
}

class _AvisoFaseUno extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
    child: Text(
      'Modo inspección: los datos se leen de .team/BOARD.md. Arrastrar tarjetas y ejecutar acciones llegará en Fase 2.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.hijo});

  final String titulo;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              titulo.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Divider(height: 1, color: paleta.rejilla),
        const SizedBox(height: 14),
        hijo,
      ],
    );
  }
}

/// De dónde salen los datos. Con varios proyectos y varios worktrees, saber qué
/// pizarra se está mirando ahorra más de un despiste.
class _Procedencia extends StatelessWidget {
  const _Procedencia({required this.proyecto});

  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: context.paleta.tintaTenue,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PIZARRA', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        if (proyecto.repo.isNotEmpty)
          Text('repo    ${proyecto.repo}', style: estilo),
        if (proyecto.pizarra.isNotEmpty)
          Text('.team   ${proyecto.pizarra}/.team', style: estilo),
      ],
    );
  }
}
