import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/panel_fallo.dart';
import '../widgets/tabla_tareas.dart';
import '../widgets/tarjeta.dart';

/// Tareas: la lista completa del tablero, con filtro por agente y por estado.
///
/// Es la vista larga de lo que Inicio resume en una tarjeta. Todo sale de
/// `GET /board`; no hay etiquetas ni prioridades porque `.team/BOARD.md` no las
/// tiene, y un filtro que no filtra nada real sería peor que no tenerlo.
class PantallaTareas extends StatefulWidget {
  const PantallaTareas({super.key});

  @override
  State<PantallaTareas> createState() => _PantallaTareasState();
}

class _PantallaTareasState extends State<PantallaTareas> {
  /// `null` es «todos». Se guardan los valores literales del tablero (el alias
  /// del dueño y el estado crudo), no índices: si el tablero cambia entre dos
  /// refrescos, el filtro sigue apuntando a lo que el usuario eligió.
  String? _agente;
  String? _estado;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTablero>();

    return switch (estado.fase) {
      Fase.inicial || Fase.cargando => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      Fase.fallo => Padding(
        padding: const EdgeInsets.all(24),
        child: PanelFallo(fallo: estado.fallo!, alReintentar: estado.refresca),
      ),
      Fase.listo => _Contenido(
        tablero: estado.tablero!,
        estado: estado,
        agente: _agente,
        estadoTarea: _estado,
        alFiltrarAgente: (a) => setState(() => _agente = a),
        alFiltrarEstado: (e) => setState(() => _estado = e),
        alLimpiar: () => setState(() {
          _agente = null;
          _estado = null;
        }),
      ),
    };
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.tablero,
    required this.estado,
    required this.agente,
    required this.estadoTarea,
    required this.alFiltrarAgente,
    required this.alFiltrarEstado,
    required this.alLimpiar,
  });

  final Tablero tablero;
  final EstadoTablero estado;
  final String? agente;
  final String? estadoTarea;
  final ValueChanged<String?> alFiltrarAgente;
  final ValueChanged<String?> alFiltrarEstado;
  final VoidCallback alLimpiar;

  /// El mismo margen que el centro de control: las dos vistas se ven hermanas.
  static const _margen = 28.0;

  bool get _filtrado => agente != null || estadoTarea != null;

  /// Los alias en el orden del ledger, con los dueños que todavía no tienen
  /// fila en él al final. Igual que hace Inicio: el orden no baila.
  List<String> get _agentes => <String>{
    for (final a in tablero.agentes) a.agente,
    for (final t in tablero.tareas) t.dueno,
  }.toList(growable: false);

  /// Los estados que de verdad hay en la pizarra, en el orden en que aparecen.
  /// No se listan los cuatro de `EstadoTarea`: si nadie ha integrado nada
  /// todavía, un chip «integrada» a cero sólo invita a pulsarlo en balde.
  List<String> get _estados =>
      <String>{for (final t in tablero.tareas) t.estadoCrudo}.toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    // Cada eje se cuenta con el *otro* filtro ya aplicado: así la cifra del
    // chip es lo que saldrá al pulsarlo, y ninguno lleva a una tabla vacía.
    final porAgente = tablero.tareas.where(_pasaEstado).toList(growable: false);
    final porEstado = tablero.tareas.where(_pasaAgente).toList(growable: false);
    final visibles = tablero.tareas
        .where((t) => _pasaAgente(t) && _pasaEstado(t))
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(_margen, 24, _margen, 36),
      children: [
        _Cabecera(tablero: tablero, estado: estado, visibles: visibles.length),
        const SizedBox(height: 22),
        Tarjeta(
          titulo: 'Filtros',
          icono: Icons.filter_list,
          sufijo: _filtrado
              ? TextButton.icon(
                  onPressed: alLimpiar,
                  icon: const Icon(Icons.close, size: 15),
                  label: const Text('Quitar filtros'),
                )
              : Text('sin filtrar', style: textos.labelSmall),
          pie: Row(
            children: [
              Expanded(
                child: Text(
                  'Por agente y por estado, que es lo que el tablero sabe. '
                  'Etiquetas y prioridades no existen en .team/BOARD.md.',
                  style: textos.bodySmall?.copyWith(color: context.paleta.tintaTenue),
                ),
              ),
            ],
          ),
          hijo: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilaFiltro(
                etiqueta: 'AGENTE',
                opciones: [
                  _Opcion(valor: null, texto: 'Todos', cuenta: porAgente.length),
                  for (final a in _agentes)
                    _Opcion(
                      valor: a,
                      texto: a,
                      cuenta: porAgente.where((t) => t.dueno == a).length,
                      color: context.paleta.serieDe(a),
                      mono: true,
                    ),
                ],
                elegido: agente,
                alElegir: alFiltrarAgente,
              ),
              const SizedBox(height: 14),
              _FilaFiltro(
                etiqueta: 'ESTADO',
                opciones: [
                  _Opcion(valor: null, texto: 'Todos', cuenta: porEstado.length),
                  for (final e in _estados)
                    _Opcion(
                      valor: e,
                      texto: e,
                      cuenta: porEstado.where((t) => t.estadoCrudo == e).length,
                      mono: true,
                    ),
                ],
                elegido: estadoTarea,
                alElegir: alFiltrarEstado,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Tarjeta(
          titulo: 'Tareas del tablero',
          icono: Icons.check_circle_outline,
          sufijo: Text(
            _filtrado
                ? '${visibles.length} de ${tablero.tareas.length}'
                : '${tablero.tareas.length} total',
            style: textos.titleMedium,
          ),
          pie: _Procedencia(visibles: visibles),
          hijo: visibles.isEmpty && _filtrado
              ? _SinResultados(alLimpiar: alLimpiar)
              // La tabla es la misma de Tablero: una sola forma de pintar una
              // fila de tarea en toda la app.
              : TablaTareas(tareas: visibles),
        ),
      ],
    );
  }

  bool _pasaAgente(Tarea t) => agente == null || t.dueno == agente;
  bool _pasaEstado(Tarea t) => estadoTarea == null || t.estadoCrudo == estadoTarea;
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.tablero,
    required this.estado,
    required this.visibles,
  });

  final Tablero tablero;
  final EstadoTablero estado;
  final int visibles;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Tareas', style: textos.headlineSmall?.copyWith(fontSize: 26)),
                  const SizedBox(width: 12),
                  Insignia('$visibles en vista', tono: paleta.acentoAlt),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.description_outlined, size: 14, color: paleta.tintaTenue),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Mono(
                      tablero.proyecto?.pizarra.isNotEmpty == true
                          ? '${tablero.proyecto!.pizarra}/.team/BOARD.md'
                          : '.team/BOARD.md',
                      color: paleta.tintaSecundaria,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    estado.obsoleto
                        ? 'datos de la última lectura buena'
                        : 'en el orden de la pizarra',
                    style: textos.bodySmall?.copyWith(
                      color: estado.obsoleto ? paleta.aviso : paleta.tintaTenue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: estado.refresca,
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('Sincronizar'),
        ),
        const SizedBox(width: 10),

      ],
    );
  }
}

/// Una opción de filtro: el valor que aplica, cómo se lee y cuántas trae.
class _Opcion {
  const _Opcion({
    required this.valor,
    required this.texto,
    required this.cuenta,
    this.color,
    this.mono = false,
  });

  /// `null` es la opción «Todos» del eje.
  final String? valor;
  final String texto;
  final int cuenta;
  final Color? color;
  final bool mono;
}

class _FilaFiltro extends StatelessWidget {
  const _FilaFiltro({
    required this.etiqueta,
    required this.opciones,
    required this.elegido,
    required this.alElegir,
  });

  final String etiqueta;
  final List<_Opcion> opciones;
  final String? elegido;
  final ValueChanged<String?> alElegir;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: SizedBox(
            width: 72,
            child: Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in opciones)
                _ChipFiltro(
                  opcion: o,
                  activo: o.valor == elegido,
                  // Volver a pulsar el chip activo lo quita: no hace falta ir a
                  // buscar «Todos» al principio de la fila.
                  alPulsar: () => alElegir(o.valor == elegido ? null : o.valor),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// El chip del filtro. Seleccionado se nota por borde y fondo, no sólo por
/// color: `Semantics.selected` lo dice además para el lector de pantalla.
class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.opcion,
    required this.activo,
    required this.alPulsar,
  });

  final _Opcion opcion;
  final bool activo;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final tinta = activo ? paleta.acento : paleta.tintaSecundaria;

    return Semantics(
      selected: activo,
      button: true,
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: activo ? paleta.acento.withValues(alpha: 0.10) : null,
            border: Border.all(color: activo ? paleta.acento : paleta.rejilla),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (opcion.color != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: opcion.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                opcion.texto,
                style: textos.bodySmall?.copyWith(
                  color: tinta,
                  fontFamily: opcion.mono ? 'monospace' : null,
                  fontWeight: activo ? FontWeight.w600 : null,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${opcion.cuenta}',
                style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El filtro ha dejado la tabla vacía. Se dice que es el filtro, no el tablero:
/// `TablaTareas` diría «no hay tareas abiertas», que aquí sería mentira.
class _SinResultados extends StatelessWidget {
  const _SinResultados({required this.alLimpiar});

  final VoidCallback alLimpiar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off_outlined, size: 28, color: context.paleta.tintaTenue),
          const SizedBox(height: 10),
          Text('Ninguna tarea cumple el filtro.', style: textos.bodyMedium),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: alLimpiar, child: const Text('Quitar filtros')),
        ],
      ),
    );
  }
}

/// El pie de la tabla: de cuándo son estas tareas y por qué están en este
/// orden. La fecha de apertura es el único campo que la tabla no enseña fila a
/// fila, y aquí al menos acota el periodo de lo que se está mirando.
class _Procedencia extends StatelessWidget {
  const _Procedencia({required this.visibles});

  final List<Tarea> visibles;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    final fechas = [for (final t in visibles) t.abierta]..sort();

    return Row(
      children: [
        Expanded(
          child: Text(
            'Orden tal cual en .team/BOARD.md: la app no reordena.',
            style: textos.labelSmall,
          ),
        ),
        if (fechas.isNotEmpty)
          Mono(
            fechas.first == fechas.last
                ? 'abiertas el ${_fecha(fechas.first)}'
                : 'abiertas entre ${_fecha(fechas.first)} y ${_fecha(fechas.last)}',
            color: paleta.tintaTenue,
          ),
      ],
    );
  }

  static String _fecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
