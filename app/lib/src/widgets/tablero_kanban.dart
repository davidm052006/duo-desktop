import 'package:flutter/material.dart';

import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import 'tarjeta.dart';

/// Vista Kanban de solo lectura sobre GET /board.
///
/// Al seleccionar una tarjeta, el inspector se mantiene dentro de la misma
/// pantalla en un panel lateral. El tablero conserva anchura legible y usa
/// desplazamiento horizontal cuando no cabe.
class TableroKanban extends StatefulWidget {
  const TableroKanban({super.key, required this.tareas});

  final List<Tarea> tareas;

  @override
  State<TableroKanban> createState() => _TableroKanbanState();
}

class _TableroKanbanState extends State<TableroKanban> {
  Tarea? _seleccionada;
  final _desplazamientoHorizontal = ScrollController();

  @override
  void dispose() {
    _desplazamientoHorizontal.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TableroKanban oldWidget) {
    super.didUpdateWidget(oldWidget);
    final seleccionada = _seleccionada;
    if (seleccionada == null) return;

    final indice = widget.tareas.indexWhere((t) => t.id == seleccionada.id);
    _seleccionada = indice < 0 ? null : widget.tareas[indice];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tareas.isEmpty) return const _SinTareasKanban();

    return LayoutBuilder(
      builder: (context, limites) {
        final columnas = [
          for (final definicion in _columnas)
            _ColumnaKanban(
              definicion: definicion,
              tareas: widget.tareas
                  .where((t) => definicion.incluye(t))
                  .toList(growable: false),
              seleccionada: _seleccionada,
              alSeleccionar: (tarea) => setState(() => _seleccionada = tarea),
            ),
        ];

        // Las cuatro columnas necesitan una anchura mínima legible. El
        // controlador explícito evita que el Scrollbar se enlace al scroll
        // vertical primario en lugar de al desplazamiento del tablero.
        final anchoTablero = limites.maxWidth > 1192 ? limites.maxWidth : 1192.0;

        final tablero = Scrollbar(
          controller: _desplazamientoHorizontal,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _desplazamientoHorizontal,
            scrollDirection: Axis.horizontal,
            primary: false,
            child: SizedBox(
              width: anchoTablero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columnas.length; i++) ...[
                    Expanded(child: columnas[i]),
                    if (i != columnas.length - 1) const SizedBox(width: 16),
                  ],
                ],
              ),
            ),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            tablero,
            if (_seleccionada != null)
              _DialogoInspector(
                tarea: _seleccionada!,
                alCerrar: () => setState(() => _seleccionada = null),
              ),
          ],
        );
      },
    );
  }
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
  _DefinicionColumna('EN PROGRESO', EstadoTarea.abierta, (p) => p.series.first),
  _DefinicionColumna(
    'NECESITA DECISIÓN',
    EstadoTarea.esperando,
    (p) => p.aviso,
  ),
  _DefinicionColumna('FINALIZADAS', EstadoTarea.integrada, (p) => p.bien),
];

class _ColumnaKanban extends StatelessWidget {
  const _ColumnaKanban({
    required this.definicion,
    required this.tareas,
    required this.seleccionada,
    required this.alSeleccionar,
  });

  final _DefinicionColumna definicion;
  final List<Tarea> tareas;
  final Tarea? seleccionada;
  final ValueChanged<Tarea> alSeleccionar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final color = definicion.color(paleta);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: .38),
        border: Border.all(color: paleta.rejilla),
        borderRadius: BorderRadius.circular(8),
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
                    itemBuilder: (_, indice) => _TarjetaTarea(
                      tarea: tareas[indice],
                      seleccionada: tareas[indice].id == seleccionada?.id,
                      alPulsar: () => alSeleccionar(tareas[indice]),
                    ),
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
        decoration: BoxDecoration(
          color: context.paleta.rejilla,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$cantidad',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
}

class _TarjetaTarea extends StatelessWidget {
  const _TarjetaTarea({
    required this.tarea,
    required this.seleccionada,
    required this.alPulsar,
  });

  final Tarea tarea;
  final bool seleccionada;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final colorAgente = paleta.serieDe(tarea.dueno);
    return Material(
      color: seleccionada
          ? colorAgente.withValues(alpha: .15)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colorAgente, width: 3),
              top: BorderSide(
                color: seleccionada ? colorAgente : paleta.rejilla,
              ),
              right: BorderSide(
                color: seleccionada ? colorAgente : paleta.rejilla,
              ),
              bottom: BorderSide(
                color: seleccionada ? colorAgente : paleta.rejilla,
              ),
            ),
            // Sin borderRadius aquí: Flutter no lo admite con un borde de
            // colores distintos por lado (la franja del agente a la
            // izquierda). El Material que envuelve la tarjeta ya la redondea.
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    tarea.id,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colorAgente),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tarea.rama,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tarea.estadoCrudo,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inspector modal de la referencia "tablero kanban 2". Mantiene el tablero
/// visible detrás para conservar el contexto de la tarjeta seleccionada.
class _DialogoInspector extends StatelessWidget {
  const _DialogoInspector({required this.tarea, required this.alCerrar});

  final Tarea tarea;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: alCerrar,
                child: ColoredBox(color: Colors.black.withValues(alpha: .68)),
              ),
            ),
            Center(
              child: LayoutBuilder(
                builder: (context, limites) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 850,
                    maxHeight: (limites.maxHeight - 48).clamp(300, 760),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _InspectorTarea(tarea: tarea, alCerrar: alCerrar),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _InspectorTarea extends StatelessWidget {
  const _InspectorTarea({
    required this.tarea,
    required this.alCerrar,
  });

  final Tarea tarea;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final colorAgente = paleta.serieDe(tarea.dueno);

    return Container(
      decoration: BoxDecoration(
        color: paleta.panel,
        border: Border.all(color: paleta.acentoAlt.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
            child: Row(
              children: [
                Icon(
                  Icons.manage_search_outlined,
                  size: 17,
                  color: paleta.acentoAlt,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'INSPECTOR DE TAREA',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar inspector',
                  onPressed: alCerrar,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: paleta.rejilla),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              children: [
                Row(
                  children: [
                    Insignia(tarea.id, tono: colorAgente, mono: true),
                    const SizedBox(width: 8),
                    Insignia(tarea.estadoCrudo, tono: _tonoEstado(paleta)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tarea.titulo,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 22),
                _Dato(
                  etiqueta: 'AGENTE ASIGNADO',
                  valor: tarea.dueno,
                  icono: Icons.smart_toy_outlined,
                  tono: colorAgente,
                ),
                _Dato(
                  etiqueta: 'RAMA GIT',
                  valor: tarea.rama,
                  icono: Icons.account_tree_outlined,
                  mono: true,
                ),
                _Dato(
                  etiqueta: 'ABIERTA',
                  valor: _fecha(tarea.abierta),
                  icono: Icons.calendar_today_outlined,
                  mono: true,
                ),
                const SizedBox(height: 6),
                _SeccionInspector(
                  titulo: 'ARCHIVOS TOCADOS',
                  icono: Icons.difference_outlined,
                  hijo: tarea.archivos.isEmpty
                      ? const _NoDisponible(
                          'GET /board todavía no informa archivos tocados.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final archivo in tarea.archivos)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Mono(
                                  archivo,
                                  color: paleta.tintaSecundaria,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                _SeccionInspector(
                  titulo: 'DIAGNÓSTICO DEL AGENTE',
                  icono: Icons.psychology_outlined,
                  hijo: tarea.diagnostico == null ||
                          tarea.diagnostico!.trim().isEmpty
                      ? const _NoDisponible(
                          'GET /board todavía no informa diagnóstico para esta tarea.',
                        )
                      : Text(
                          tarea.diagnostico!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tonoEstado(PaletaDatos paleta) => switch (tarea.estado) {
        EstadoTarea.abierta => paleta.acentoAlt,
        EstadoTarea.esperando => paleta.aviso,
        EstadoTarea.entregada => paleta.tintaSecundaria,
        EstadoTarea.integrada => paleta.bien,
        EstadoTarea.desconocido => paleta.tintaTenue,
      };

  static String _fecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.tono,
    this.mono = false,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;
  final Color? tono;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: tono ?? paleta.acentoAlt),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: paleta.tintaSecundaria,
                        fontFamily: mono ? 'monospace' : null,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionInspector extends StatelessWidget {
  const _SeccionInspector({
    required this.titulo,
    required this.icono,
    required this.hijo,
  });

  final String titulo;
  final IconData icono;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: paleta.superficie.withValues(alpha: .55),
        border: Border.all(color: paleta.rejilla),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, size: 15, color: paleta.acentoAlt),
              const SizedBox(width: 8),
              Text(titulo, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          hijo,
        ],
      ),
    );
  }
}

class _NoDisponible extends StatelessWidget {
  const _NoDisponible(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.paleta.tintaTenue,
              fontStyle: FontStyle.italic,
            ),
      );
}

class _SinTareasKanban extends StatelessWidget {
  const _SinTareasKanban();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'No hay tareas abiertas.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
}
