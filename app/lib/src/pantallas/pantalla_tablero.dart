import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/cliente_cloud.dart';
import '../estado/estado_proyecto_activo.dart';
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
    final activo = context.watch<EstadoProyectoActivo>().proyecto;
    if (activo != null) {
      return _PantallaTableroCloud(proyecto: activo);
    }

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


class _PantallaTableroCloud extends StatefulWidget {
  const _PantallaTableroCloud({required this.proyecto});

  final ProyectoCloud proyecto;

  @override
  State<_PantallaTableroCloud> createState() => _PantallaTableroCloudState();
}

class _PantallaTableroCloudState extends State<_PantallaTableroCloud> {
  late final ClienteCloud _cloud;
  late Future<List<TareaCloud>> _tareas;

  @override
  void initState() {
    super.initState();
    _cloud = ClienteCloud();
    _recargar();
  }

  @override
  void didUpdateWidget(covariant _PantallaTableroCloud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proyecto.id != widget.proyecto.id) {
      _recargar();
    }
  }

  @override
  void dispose() {
    _cloud.cierra();
    super.dispose();
  }

  void _recargar() {
    _tareas = _cloud.tareas(widget.proyecto.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            Text('Tablero', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(width: 10),
            Text(
              widget.proyecto.nombre,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: Text(
                widget.proyecto.repositorio,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: context.paleta.tintaTenue,
                    ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar tareas del proyecto',
            onPressed: () => setState(_recargar),
            icon: const Icon(Icons.refresh, size: 19),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<TareaCloud>>(
        future: _tareas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No se pudo cargar el tablero Cloud: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final tareas = snapshot.data ?? const <TareaCloud>[];
          return _KanbanCloud(
            proyecto: widget.proyecto,
            tareas: tareas,
          );
        },
      ),
    );
  }
}

class _KanbanCloud extends StatelessWidget {
  const _KanbanCloud({required this.proyecto, required this.tareas});

  final ProyectoCloud proyecto;
  final List<TareaCloud> tareas;

  static const _estados = <(String, String)>[
    ('pending', 'Pendientes'),
    ('in_progress', 'En progreso'),
    ('waiting', 'Esperando'),
    ('in_review', 'En revisión'),
    ('finalized', 'Finalizadas'),
  ];

  @override
  Widget build(BuildContext context) {
    if (tareas.isEmpty) {
      return Center(
        child: Text(
          'No hay tareas en ${proyecto.nombre}.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _estados.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            _ColumnaCloud(
              titulo: _estados[i].$2,
              estado: _estados[i].$1,
              tareas: tareas.where((t) => t.estado == _estados[i].$1).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColumnaCloud extends StatelessWidget {
  const _ColumnaCloud({
    required this.titulo,
    required this.estado,
    required this.tareas,
  });

  final String titulo;
  final String estado;
  final List<TareaCloud> tareas;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return SizedBox(
      width: 285,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paleta.panel,
          border: Border.all(color: paleta.rejilla),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    '${tareas.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tareas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Text(
                    'Sin tareas',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: paleta.tintaTenue,
                        ),
                  ),
                )
              else
                for (final tarea in tareas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: paleta.rejilla),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tarea.externalId,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: paleta.acentoAlt,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              tarea.titulo,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 9),
                            Text(
                              tarea.assignedEmail ?? tarea.ownerAgent,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: paleta.tintaSecundaria,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tarea.workProvider,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: paleta.tintaTenue,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
