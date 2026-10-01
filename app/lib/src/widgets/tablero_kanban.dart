import 'package:flutter/material.dart';

import '../modelos/tablero.dart';
import '../tema/paleta.dart';

/// Tablero de solo lectura. Las columnas nunca se encogen por debajo de una
/// tarjeta legible: la ventana estrecha ofrece desplazamiento horizontal.
class TableroKanban extends StatefulWidget {
  const TableroKanban({super.key, required this.tareas});

  final List<Tarea> tareas;

  @override
  State<TableroKanban> createState() => _TableroKanbanState();
}

class _TableroKanbanState extends State<TableroKanban> {
  @override
  Widget build(BuildContext context) {
    if (widget.tareas.isEmpty) {
      return Center(
        child: Text(
          'No hay tareas abiertas.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, limites) {
        const hueco = 12.0;
        const anchoMinimo = 1024.0;
        final ancho = limites.maxWidth < anchoMinimo
            ? anchoMinimo
            : limites.maxWidth;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: ancho,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _columnas.length; i++) ...[
                    Expanded(
                      child: _Columna(
                        definicion: _columnas[i],
                        tareas: widget.tareas
                            .where(_columnas[i].incluye)
                            .toList(),
                        alAbrir: _abreInspector,
                      ),
                    ),
                    if (i < _columnas.length - 1) const SizedBox(width: hueco),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _abreInspector(Tarea tarea) => showDialog<void>(
    context: context,
    builder: (_) => _InspectorTarea(tarea: tarea),
  );
}

class _DefinicionColumna {
  const _DefinicionColumna(this.titulo, this.estado, this.color);

  final String titulo;
  final EstadoTarea estado;
  final Color Function(PaletaDatos) color;

  bool incluye(Tarea tarea) =>
      tarea.estado == estado ||
      (estado == EstadoTarea.abierta &&
          tarea.estado == EstadoTarea.desconocido);
}

final _columnas = [
  _DefinicionColumna('EN ESPERA', EstadoTarea.entregada, (p) => p.tintaTenue),
  _DefinicionColumna('EN PROGRESO', EstadoTarea.abierta, (p) => p.acentoAlt),
  _DefinicionColumna(
    'NECESITA DECISIÓN',
    EstadoTarea.esperando,
    (p) => p.acento,
  ),
  _DefinicionColumna('FINALIZADAS', EstadoTarea.integrada, (p) => p.bien),
];

class _Columna extends StatelessWidget {
  const _Columna({
    required this.definicion,
    required this.tareas,
    required this.alAbrir,
  });

  final _DefinicionColumna definicion;
  final List<Tarea> tareas;
  final ValueChanged<Tarea> alAbrir;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final color = definicion.color(paleta);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: paleta.panel,
        border: Border.all(color: paleta.rejilla),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 9),
            child: Row(
              children: [
                Container(width: 8, height: 8, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    definicion.titulo,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                _Contador(cantidad: tareas.length),
              ],
            ),
          ),
          Divider(height: 1, color: paleta.rejilla),
          Expanded(
            child: tareas.isEmpty
                ? Center(
                    child: Text(
                      'Sin tareas',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: tareas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _TarjetaTarea(tarea: tareas[i], alAbrir: alAbrir),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.cantidad});
  final int cantidad;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    color: context.paleta.rejilla,
    child: Text('$cantidad', style: Theme.of(context).textTheme.labelSmall),
  );
}

class _TarjetaTarea extends StatelessWidget {
  const _TarjetaTarea({required this.tarea, required this.alAbrir});
  final Tarea tarea;
  final ValueChanged<Tarea> alAbrir;

  @override
  Widget build(BuildContext context) {
    final color = context.paleta.serieDe(tarea.dueno);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => alAbrir(tarea),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    tarea.id,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                  ),
                  const Spacer(),
                  Text(
                    tarea.dueno,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                tarea.titulo,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 9),
              Text(
                tarea.rama,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                tarea.estadoCrudo,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorTarea extends StatelessWidget {
  const _InspectorTarea({required this.tarea});
  final Tarea tarea;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final colorAgente = paleta.serieDe(tarea.dueno);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: paleta.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: paleta.acentoAlt),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'INSPECTOR DE TAREA',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: paleta.acentoAlt),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar inspector',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Divider(color: paleta.rejilla),
            const SizedBox(height: 14),
            Text(
              tarea.id,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colorAgente),
            ),
            const SizedBox(height: 7),
            Text(
              tarea.titulo,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            _Dato('ESTADO ACTUAL', tarea.estadoCrudo, paleta.acento),
            _Dato('AGENTE ASIGNADO', tarea.dueno, colorAgente),
            _Dato('RAMA GIT', tarea.rama, paleta.acentoAlt),
            _Dato('ABIERTA', _fecha(tarea.abierta), paleta.tintaTenue),
            const SizedBox(height: 8),
            Text(
              'ACCIONES DE FASE (SOLO LECTURA)',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            const _AccionFutura('REASIGNAR AGENTE', 'Fase 2'),
            const SizedBox(height: 8),
            const _AccionFutura('CERRAR O EDITAR TAREA', 'Fase 2'),
          ],
        ),
      ),
    );
  }

  static String _fecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, this.color);
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    ),
  );
}

class _AccionFutura extends StatelessWidget {
  const _AccionFutura(this.etiqueta, this.fase);
  final String etiqueta;
  final String fase;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: null,
    child: Row(
      children: [
        Expanded(child: Text(etiqueta)),
        Text(fase),
      ],
    ),
  );
}
