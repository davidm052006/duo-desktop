import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/estado_tablero.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/panel_fallo.dart';
import '../widgets/tarjeta.dart';

/// Visualizaciones — las tres gráficas que `GET /board` puede sostener hoy.
///
/// Todo se pinta a mano con `CustomPainter`: ninguna dependencia nueva. Y todo
/// sale del tablero y del ledger, de nada más. Donde el endpoint no llega
/// (quién revisó de verdad a quién, que vive en los PR de GitHub) la vista lo
/// dice con su fase en vez de rellenarlo con datos de adorno.
class PantallaVisualizaciones extends StatelessWidget {
  const PantallaVisualizaciones({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTablero>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: const Text('Visualizaciones'),
        actions: [
          IconButton(
            tooltip: 'Actualizar tablero',
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
          child: PanelFallo(fallo: estado.fallo!, alReintentar: estado.refresca),
        ),
        Fase.listo => _Contenido(datos: DatosGraficas.desde(estado.tablero!)),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Lo que se deduce del tablero
// ---------------------------------------------------------------------------

/// El reparto de un agente: cuántas tareas suyas siguen vivas y cuántas cerró.
class RepartoAgente {
  const RepartoAgente({
    required this.alias,
    required this.vivas,
    required this.integradas,
  });

  final String alias;
  final int vivas;
  final int integradas;

  int get total => vivas + integradas;
}

/// Un día de la línea de tiempo, con el recuento por agente.
class DiaTareas {
  const DiaTareas({required this.fecha, required this.porAgente});

  final DateTime fecha;
  final Map<String, int> porAgente;

  int get total => porAgente.values.fold(0, (suma, n) => suma + n);
}

/// Una arista del grafo de revisión: quién entregó y a quién le toca revisar.
class Revision {
  const Revision({required this.autor, required this.revisor, required this.tareas});

  final String autor;
  final String revisor;
  final int tareas;
}

/// Los tres conjuntos que alimentan las gráficas, calculados una sola vez.
class DatosGraficas {
  const DatosGraficas({
    required this.reparto,
    required this.dias,
    required this.revisiones,
    required this.diasRecortados,
  });

  final List<RepartoAgente> reparto;
  final List<DiaTareas> dias;
  final List<Revision> revisiones;

  /// Días que quedaron fuera de la ventana de la línea de tiempo.
  final int diasRecortados;

  /// Más días que esto y las etiquetas del eje no caben sin solaparse. Se
  /// enseñan los más recientes y se dice cuántos se dejaron fuera.
  static const maximoDias = 21;

  /// Mientras `duo review` no tenga endpoint, el único revisor que el tablero
  /// permite afirmar es David: una tarea entregada espera su revisión.
  static const revisorHumano = 'David';

  bool get vacio => reparto.every((r) => r.total == 0);

  int get entregadasTotales => revisiones.fold(0, (suma, r) => suma + r.tareas);

  factory DatosGraficas.desde(Tablero tablero) {
    // El orden del ledger manda, igual que en Inicio: así los agentes no
    // bailan de sitio entre refrescos. Un dueño sin fila en el ledger existe
    // igualmente y se añade al final.
    final alias = <String>{
      for (final a in tablero.agentes) a.agente,
      for (final t in tablero.tareas) t.dueno,
    }.toList(growable: false);

    final reparto = [
      for (final a in alias)
        RepartoAgente(
          alias: a,
          vivas: tablero.tareas
              .where((t) => t.dueno == a && t.estado != EstadoTarea.integrada)
              .length,
          integradas: tablero.tareas
              .where((t) => t.dueno == a && t.estado == EstadoTarea.integrada)
              .length,
        ),
    ];

    return DatosGraficas(
      reparto: reparto,
      dias: _porDia(tablero, alias),
      revisiones: [
        for (final a in alias)
          if (_entregadasDe(tablero, a) > 0)
            Revision(
              autor: a,
              revisor: revisorHumano,
              tareas: _entregadasDe(tablero, a),
            ),
      ],
      diasRecortados: math.max(0, _diasConTareas(tablero) - maximoDias),
    );
  }

  /// Una tarea entregada o integrada ya pasó por revisión (o la está esperando):
  /// es lo único que el tablero deja afirmar sobre el reparto de revisiones.
  static int _entregadasDe(Tablero tablero, String alias) => tablero.tareas
      .where(
        (t) =>
            t.dueno == alias &&
            (t.estado == EstadoTarea.entregada || t.estado == EstadoTarea.integrada),
      )
      .length;

  /// Los días del rango, incluidos los que no tuvieron ninguna tarea: un hueco
  /// en el calendario es información, y saltárselo deformaría la pendiente.
  static List<DiaTareas> _porDia(Tablero tablero, List<String> alias) {
    if (tablero.tareas.isEmpty) return const [];

    final cuenta = <DateTime, Map<String, int>>{};
    for (final t in tablero.tareas) {
      final dia = DateTime(t.abierta.year, t.abierta.month, t.abierta.day);
      final porAgente = cuenta.putIfAbsent(dia, () => {});
      porAgente[t.dueno] = (porAgente[t.dueno] ?? 0) + 1;
    }

    final fechas = cuenta.keys.toList()..sort();
    final primera = fechas.first;
    final ultima = fechas.last;

    final todos = <DiaTareas>[];
    for (var d = primera; !d.isAfter(ultima); d = d.add(const Duration(days: 1))) {
      todos.add(
        DiaTareas(
          fecha: d,
          porAgente: {for (final a in alias) a: cuenta[d]?[a] ?? 0},
        ),
      );
    }

    return todos.length <= maximoDias
        ? todos
        : todos.sublist(todos.length - maximoDias);
  }

  static int _diasConTareas(Tablero tablero) {
    if (tablero.tareas.isEmpty) return 0;
    final fechas = {
      for (final t in tablero.tareas)
        DateTime(t.abierta.year, t.abierta.month, t.abierta.day),
    }.toList()..sort();
    return fechas.last.difference(fechas.first).inDays + 1;
  }
}

String fechaIso(DateTime d) {
  String dd(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${dd(d.month)}-${dd(d.day)}';
}

String _diaCorto(DateTime d) {
  String dd(int n) => n.toString().padLeft(2, '0');
  return '${dd(d.day)}/${dd(d.month)}';
}

// ---------------------------------------------------------------------------
// La página
// ---------------------------------------------------------------------------

class _Contenido extends StatelessWidget {
  const _Contenido({required this.datos});

  final DatosGraficas datos;

  /// Por debajo de esto las dos gráficas de arriba se quedan sin ancho para sus
  /// etiquetas y pasan a ir una sobre otra.
  static const _anchoDosColumnas = 1040.0;
  static const _margen = 24.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final anchas = caja.maxWidth - _margen * 2 >= _anchoDosColumnas;

        final barras = _PanelReparto(datos: datos);
        final linea = _PanelLineaTiempo(datos: datos);

        return ListView(
          padding: const EdgeInsets.fromLTRB(_margen, 24, _margen, 36),
          children: [
            const _AvisoFuente(),
            const SizedBox(height: 18),
            if (anchas)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: barras),
                    const SizedBox(width: 18),
                    Expanded(child: linea),
                  ],
                ),
              )
            else ...[
              barras,
              const SizedBox(height: 18),
              linea,
            ],
            const SizedBox(height: 18),
            _PanelRevisiones(datos: datos),
          ],
        );
      },
    );
  }
}

class _AvisoFuente extends StatelessWidget {
  const _AvisoFuente();

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paleta.acentoAlt.withValues(alpha: .08),
        border: Border.all(color: paleta.rejilla),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: paleta.acentoAlt),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las tres gráficas se dibujan con el tablero y el ledger de /board: '
              'recuento de tareas y fecha de apertura. No hay estimación de '
              'esfuerzo, ni de tokens, ni eventos en vivo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gráfica de barras: cuántas tareas tiene cada agente y en qué proporción
/// siguen vivas.
class _PanelReparto extends StatelessWidget {
  const _PanelReparto({required this.datos});

  final DatosGraficas datos;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final reparto = datos.reparto;

    return Tarjeta(
      titulo: 'Reparto por agente',
      icono: Icons.bar_chart,
      sufijo: Text('${reparto.length} agente(s)', style: textos.labelSmall),
      pie: Row(
        children: [
          Expanded(
            child: Text(
              'Tareas del tablero, no esfuerzo estimado',
              style: textos.labelSmall,
            ),
          ),
          Text(
            'ledger: ${datos.reparto.fold(0, (s, r) => s + r.total)} tarea(s)',
            style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
          ),
        ],
      ),
      hijo: datos.vacio
          ? Text('El tablero está vacío: nada que repartir.', style: textos.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Leyenda(
                  entradas: [
                    for (final r in reparto)
                      (texto: r.alias, color: paleta.serieDe(r.alias), hueca: false),
                    (texto: 'integradas', color: paleta.tintaTenue, hueca: true),
                  ],
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: _descripcion(),
                  child: SizedBox(
                    height: 216,
                    child: CustomPaint(
                      painter: PintorBarras(
                        reparto: reparto,
                        colores: {
                          for (final r in reparto) r.alias: paleta.serieDe(r.alias),
                        },
                        rejilla: paleta.rejilla,
                        tinta: paleta.tintaSecundaria,
                        tintaTenue: paleta.tintaTenue,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // La gráfica no es el dato: las cifras van también en texto, que
                // es lo que lee un lector de pantalla y lo que se puede copiar.
                for (final r in reparto)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, color: paleta.serieDe(r.alias)),
                        const SizedBox(width: 9),
                        Expanded(child: Mono(r.alias, color: paleta.tintaSecundaria)),
                        Text(
                          '${r.total} total · ${r.vivas} viva(s) · ${r.integradas} integrada(s)',
                          style: textos.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _descripcion() => [
    'Gráfica de barras del reparto por agente.',
    for (final r in datos.reparto)
      '${r.alias}: ${r.total} tareas, ${r.vivas} vivas y ${r.integradas} integradas.',
  ].join(' ');
}

/// Línea de tiempo: tareas abiertas cada día, una línea por agente.
class _PanelLineaTiempo extends StatelessWidget {
  const _PanelLineaTiempo({required this.datos});

  final DatosGraficas datos;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final dias = datos.dias;

    return Tarjeta(
      titulo: 'Tareas por día',
      icono: Icons.show_chart,
      sufijo: Text(
        dias.isEmpty ? 'sin fechas' : '${dias.length} día(s)',
        style: textos.labelSmall,
      ),
      pie: Row(
        children: [
          Expanded(
            child: Text('Por fecha de apertura (campo opened)', style: textos.labelSmall),
          ),
          // Cuándo se entregó o se integró cada tarea no está en /board.
          const MarcaFase(2),
        ],
      ),
      hijo: dias.isEmpty
          ? Text('Ninguna tarea tiene fecha que situar.', style: textos.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  datos.diasRecortados == 0
                      ? 'Del ${fechaIso(dias.first.fecha)} al ${fechaIso(dias.last.fecha)}.'
                      : 'Últimos ${dias.length} días '
                            '(${datos.diasRecortados} día(s) anteriores fuera de la ventana).',
                  style: textos.bodySmall,
                ),
                const SizedBox(height: 14),
                _Leyenda(
                  entradas: [
                    for (final r in datos.reparto)
                      (texto: r.alias, color: paleta.serieDe(r.alias), hueca: false),
                  ],
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: _descripcion(),
                  child: SizedBox(
                    height: 216,
                    child: CustomPaint(
                      painter: PintorLinea(
                        dias: dias,
                        agentes: [for (final r in datos.reparto) r.alias],
                        colores: {
                          for (final r in datos.reparto)
                            r.alias: paleta.serieDe(r.alias),
                        },
                        rejilla: paleta.rejilla,
                        tinta: paleta.tintaSecundaria,
                        tintaTenue: paleta.tintaTenue,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pico: ${_pico().total} tarea(s) el ${fechaIso(_pico().fecha)}.',
                  style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
                ),
              ],
            ),
    );
  }

  DiaTareas _pico() =>
      datos.dias.reduce((a, b) => b.total > a.total ? b : a);

  String _descripcion() => [
    'Línea de tiempo de tareas abiertas por día.',
    for (final d in datos.dias)
      if (d.total > 0) '${fechaIso(d.fecha)}: ${d.total}.',
  ].join(' ');
}

/// El grafo de revisión. Con `/board` solo se puede afirmar una arista: el
/// agente que entrega y David, que es quien revisa hoy.
class _PanelRevisiones extends StatelessWidget {
  const _PanelRevisiones({required this.datos});

  final DatosGraficas datos;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final revisiones = datos.revisiones;

    return Tarjeta(
      titulo: 'Quién revisó a quién',
      icono: Icons.account_tree_outlined,
      sufijo: Text('${datos.entregadasTotales} entrega(s)', style: textos.labelSmall),
      pie: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: paleta.tintaTenue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'El tablero guarda el autor de la tarea y su estado, no el revisor. '
              'La atribución agente→agente de "nadie revisa su propio trabajo" '
              'sale de los PR de GitHub.',
              style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
            ),
          ),
          const MarcaFase(4),
        ],
      ),
      hijo: revisiones.isEmpty
          ? Text(
              'Todavía no hay ninguna tarea entregada ni integrada: nada que '
              'haya pasado por revisión.',
              style: textos.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cada arista es una entrega que pasó por revisión o la está '
                  'esperando. El grosor es el número de tareas.',
                  style: textos.bodySmall,
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: _descripcion(),
                  child: SizedBox(
                    height: math.max(170, 64.0 * revisiones.length),
                    child: CustomPaint(
                      painter: PintorGrafo(
                        revisiones: revisiones,
                        colores: {
                          for (final r in revisiones)
                            r.autor: paleta.serieDe(r.autor),
                        },
                        rejilla: paleta.rejilla,
                        panel: paleta.panel,
                        tinta: paleta.tintaSecundaria,
                        tintaTenue: paleta.tintaTenue,
                        acento: paleta.acento,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final r in revisiones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, color: paleta.serieDe(r.autor)),
                        const SizedBox(width: 9),
                        Mono(r.autor, color: paleta.tintaSecundaria, peso: FontWeight.w600),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 13, color: paleta.tintaTenue),
                        const SizedBox(width: 8),
                        Expanded(child: Mono(r.revisor, color: paleta.tintaSecundaria)),
                        Text('${r.tareas} tarea(s)', style: textos.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _descripcion() => [
    'Grafo de revisión.',
    for (final r in datos.revisiones)
      '${r.autor} entregó ${r.tareas} tarea(s) a ${r.revisor}.',
  ].join(' ');
}

/// La leyenda de las gráficas. `hueca` es el relleno traslúcido de las barras.
class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.entradas});

  final List<({String texto, Color color, bool hueca})> entradas;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final e in entradas)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: e.hueca ? e.color.withValues(alpha: 0.3) : e.color,
                  border: e.hueca ? Border.all(color: e.color) : null,
                ),
              ),
              const SizedBox(width: 7),
              Text(e.texto, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Los pintores
// ---------------------------------------------------------------------------

/// Lo común a los tres pintores: ejes, rejilla y etiquetas.
abstract class _PintorEjes extends CustomPainter {
  const _PintorEjes({
    required this.rejilla,
    required this.tinta,
    required this.tintaTenue,
  });

  final Color rejilla;
  final Color tinta;
  final Color tintaTenue;

  /// Sitio para las etiquetas: el eje Y a la izquierda, las fechas o los alias
  /// debajo.
  static const margenIzquierdo = 30.0;
  static const margenInferior = 24.0;
  static const margenSuperior = 10.0;
  static const margenDerecho = 8.0;

  Rect areaDe(Size size) => Rect.fromLTRB(
    margenIzquierdo,
    margenSuperior,
    math.max(margenIzquierdo + 1, size.width - margenDerecho),
    math.max(margenSuperior + 1, size.height - margenInferior),
  );

  /// Un eje de cuentas enteras: 4 tramos como mucho, y nunca un 0,5 de tarea.
  int techoDe(int maximo) {
    if (maximo <= 4) return math.max(1, maximo);
    final paso = (maximo / 4).ceil();
    return paso * 4;
  }

  List<int> marcasDe(int techo) {
    final paso = math.max(1, techo ~/ 4);
    return [for (var v = 0; v <= techo; v += paso) v];
  }

  void pintaRejilla(Canvas canvas, Rect area, int techo) {
    final linea = Paint()
      ..color = rejilla
      ..strokeWidth = 1;

    for (final marca in marcasDe(techo)) {
      final y = area.bottom - area.height * (marca / techo);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), linea);
      etiqueta(canvas, '$marca', Offset(area.left - 6, y), tintaTenue,
          alineaDerecha: true, centraVertical: true);
    }

    // El eje Y, un poco más marcado que la rejilla.
    canvas.drawLine(
      Offset(area.left, area.top),
      Offset(area.left, area.bottom),
      Paint()
        ..color = tinta.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );
  }

  void etiqueta(
    Canvas canvas,
    String texto,
    Offset en,
    Color color, {
    bool alineaDerecha = false,
    bool centraHorizontal = false,
    bool centraVertical = false,
    double tamano = 10.5,
    FontWeight peso = FontWeight.w500,
  }) {
    final pintor = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(color: color, fontSize: tamano, fontWeight: peso),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    var dx = en.dx;
    if (alineaDerecha) dx -= pintor.width;
    if (centraHorizontal) dx -= pintor.width / 2;
    var dy = en.dy;
    if (centraVertical) dy -= pintor.height / 2;

    pintor.paint(canvas, Offset(dx, dy));
  }
}

/// Barras verticales por agente: la parte sólida son las tareas vivas, la
/// traslúcida de encima las ya integradas.
class PintorBarras extends _PintorEjes {
  const PintorBarras({
    required this.reparto,
    required this.colores,
    required super.rejilla,
    required super.tinta,
    required super.tintaTenue,
  });

  final List<RepartoAgente> reparto;
  final Map<String, Color> colores;

  static const anchoMaximoBarra = 54.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (reparto.isEmpty) return;

    final area = areaDe(size);
    final techo = techoDe(reparto.fold(0, (m, r) => math.max(m, r.total)));
    pintaRejilla(canvas, area, techo);

    final paso = area.width / reparto.length;
    final ancho = math.min(anchoMaximoBarra, paso * 0.55);

    for (var i = 0; i < reparto.length; i++) {
      final r = reparto[i];
      final centro = area.left + paso * (i + 0.5);
      final color = colores[r.alias] ?? tinta;

      final alto = area.height * (r.total / techo);
      final altoVivas = r.total == 0 ? 0.0 : alto * (r.vivas / r.total);

      final base = Rect.fromLTWH(
        centro - ancho / 2,
        area.bottom - altoVivas,
        ancho,
        altoVivas,
      );
      if (altoVivas > 0) {
        canvas.drawRect(base, Paint()..color = color);
      }

      final altoIntegradas = alto - altoVivas;
      if (altoIntegradas > 0) {
        final arriba = Rect.fromLTWH(
          centro - ancho / 2,
          area.bottom - alto,
          ancho,
          altoIntegradas,
        );
        canvas.drawRect(arriba, Paint()..color = color.withValues(alpha: 0.3));
        canvas.drawRect(
          arriba,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      // La cifra encima de la barra: el valor exacto no se lee de la altura.
      if (r.total > 0) {
        etiqueta(
          canvas,
          '${r.total}',
          Offset(centro, area.bottom - alto - 15),
          tinta,
          centraHorizontal: true,
          peso: FontWeight.w600,
        );
      }

      etiqueta(
        canvas,
        r.alias,
        Offset(centro, area.bottom + 7),
        tintaTenue,
        centraHorizontal: true,
      );
    }
  }

  @override
  bool shouldRepaint(PintorBarras viejo) =>
      viejo.rejilla != rejilla ||
      viejo.tinta != tinta ||
      viejo._firma != _firma;

  String get _firma =>
      reparto.map((r) => '${r.alias}:${r.vivas}/${r.integradas}').join(',');
}

/// Una polilínea por agente sobre los días del rango.
class PintorLinea extends _PintorEjes {
  const PintorLinea({
    required this.dias,
    required this.agentes,
    required this.colores,
    required super.rejilla,
    required super.tinta,
    required super.tintaTenue,
  });

  final List<DiaTareas> dias;
  final List<String> agentes;
  final Map<String, Color> colores;

  @override
  void paint(Canvas canvas, Size size) {
    if (dias.isEmpty) return;

    final area = areaDe(size);
    final techo = techoDe(dias.fold(0, (m, d) => math.max(m, d.total)));
    pintaRejilla(canvas, area, techo);

    double x(int i) => dias.length == 1
        ? area.center.dx
        : area.left + area.width * (i / (dias.length - 1));
    double y(int valor) => area.bottom - area.height * (valor / techo);

    for (final alias in agentes) {
      final color = colores[alias] ?? tinta;
      final puntos = [
        for (var i = 0; i < dias.length; i++)
          Offset(x(i), y(dias[i].porAgente[alias] ?? 0)),
      ];

      if (puntos.length > 1) {
        final camino = Path()..moveTo(puntos.first.dx, puntos.first.dy);
        for (final p in puntos.skip(1)) {
          camino.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          camino,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round,
        );
      }

      // Solo se marcan los días en los que ese agente abrió algo: un punto en
      // el cero por cada día llenaría el eje de ruido.
      for (var i = 0; i < dias.length; i++) {
        if ((dias[i].porAgente[alias] ?? 0) > 0) {
          canvas.drawCircle(puntos[i], 3.2, Paint()..color = color);
        }
      }
    }

    // Las fechas: las justas para que no se pisen.
    final cada = math.max(1, (dias.length / 6).ceil());
    for (var i = 0; i < dias.length; i++) {
      if (i % cada != 0 && i != dias.length - 1) continue;
      etiqueta(
        canvas,
        _diaCorto(dias[i].fecha),
        Offset(x(i), area.bottom + 7),
        tintaTenue,
        centraHorizontal: true,
      );
    }
  }

  @override
  bool shouldRepaint(PintorLinea viejo) =>
      viejo.rejilla != rejilla || viejo.tinta != tinta || viejo._firma != _firma;

  String get _firma => dias
      .map((d) => '${fechaIso(d.fecha)}=${agentes.map((a) => d.porAgente[a] ?? 0).join('/')}')
      .join(',');
}

/// El grafo: los autores a la izquierda, el revisor a la derecha, y una arista
/// por cada uno con el grosor del número de tareas entregadas.
class PintorGrafo extends _PintorEjes {
  const PintorGrafo({
    required this.revisiones,
    required this.colores,
    required this.panel,
    required this.acento,
    required super.rejilla,
    required super.tinta,
    required super.tintaTenue,
  });

  final List<Revision> revisiones;
  final Map<String, Color> colores;
  final Color panel;
  final Color acento;

  static const radio = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (revisiones.isEmpty) return;

    final izquierda = radio + 34;
    final derecha = math.max(izquierda + 80, size.width - radio - 56);
    final paso = size.height / revisiones.length;
    final destino = Offset(derecha, size.height / 2);
    final maximo = revisiones.fold(0, (m, r) => math.max(m, r.tareas));

    for (var i = 0; i < revisiones.length; i++) {
      final r = revisiones[i];
      final origen = Offset(izquierda, paso * (i + 0.5));
      final color = colores[r.autor] ?? tinta;

      // Una curva en vez de una recta: con varias aristas llegando al mismo
      // nodo, las rectas se superponen y no se sabe cuál es cuál.
      final medio = Offset((origen.dx + destino.dx) / 2, (origen.dy + destino.dy) / 2);
      final control = Offset(medio.dx, origen.dy);
      final desdeBorde = _borde(origen, control, radio);
      final hastaBorde = _borde(destino, control, radio + 4);

      final camino = Path()
        ..moveTo(desdeBorde.dx, desdeBorde.dy)
        ..quadraticBezierTo(control.dx, control.dy, hastaBorde.dx, hastaBorde.dy);

      canvas.drawPath(
        camino,
        Paint()
          ..color = color.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + 2.5 * (r.tareas / math.max(1, maximo)),
      );
      _punta(canvas, hastaBorde, control, color);

      etiqueta(
        canvas,
        '${r.tareas}',
        Offset(medio.dx, (origen.dy + control.dy) / 2 - 14),
        tinta,
        centraHorizontal: true,
        peso: FontWeight.w600,
      );

      _nodo(canvas, origen, r.autor, color);
    }

    _nodo(canvas, destino, DatosGraficas.revisorHumano, acento, grande: true);
    etiqueta(
      canvas,
      'revisa',
      Offset(destino.dx, destino.dy + radio + 12),
      tintaTenue,
      centraHorizontal: true,
    );
  }

  /// El punto del borde del círculo en dirección a `hacia`: así la arista no se
  /// mete por debajo del nodo.
  Offset _borde(Offset centro, Offset hacia, double r) {
    final d = hacia - centro;
    final largo = d.distance;
    return largo == 0 ? centro : centro + Offset(d.dx / largo * r, d.dy / largo * r);
  }

  void _punta(Canvas canvas, Offset en, Offset desde, Color color) {
    final d = en - desde;
    final largo = d.distance;
    if (largo == 0) return;
    final u = Offset(d.dx / largo, d.dy / largo);
    final n = Offset(-u.dy, u.dx);
    const l = 8.0;
    const w = 4.0;

    canvas.drawPath(
      Path()
        ..moveTo(en.dx, en.dy)
        ..lineTo(en.dx - u.dx * l + n.dx * w, en.dy - u.dy * l + n.dy * w)
        ..lineTo(en.dx - u.dx * l - n.dx * w, en.dy - u.dy * l - n.dy * w)
        ..close(),
      Paint()..color = color,
    );
  }

  void _nodo(Canvas canvas, Offset centro, String texto, Color color,
      {bool grande = false}) {
    final r = grande ? radio + 4 : radio;
    canvas.drawCircle(centro, r, Paint()..color = panel);
    canvas.drawCircle(
      centro,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = grande ? 2 : 1.5,
    );
    etiqueta(
      canvas,
      texto,
      centro,
      color,
      centraHorizontal: true,
      centraVertical: true,
      tamano: 11,
      peso: FontWeight.w600,
    );
  }

  @override
  bool shouldRepaint(PintorGrafo viejo) =>
      viejo.panel != panel || viejo.acento != acento || viejo._firma != _firma;

  String get _firma =>
      revisiones.map((r) => '${r.autor}>${r.revisor}:${r.tareas}').join(',');
}
