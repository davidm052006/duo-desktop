import 'dart:convert';

import 'package:duo_desktop/src/modelos/resumen.dart';
import 'package:duo_desktop/src/modelos/tablero.dart';
import 'package:flutter_test/flutter_test.dart';

Tablero _tablero(List<Map<String, Object?>> tareas, {List<String> ledger = const []}) =>
    Tablero.desdeJson(
      jsonDecode(
        jsonEncode({
          'board': {'tasks': tareas},
          'ledger': {
            'agents': [
              for (final a in ledger)
                {'agent': a, 'points': 0, 'tasks': 0, 'last': null},
            ],
          },
        }),
      ) as Map<String, dynamic>,
    );

Map<String, Object?> _tarea(String id, String dueno, String estado) => {
  'id': id,
  'title': 'tarea $id',
  'owner': dueno,
  'branch': '$dueno/${id.toLowerCase()}',
  'status': estado,
  'opened': '2026-09-30',
};

void main() {
  test('cada columna cuenta su estado real de duo', () {
    final r = ResumenInicio.desde(
      _tablero([
        _tarea('T-001', 'cc', 'abierta'),
        _tarea('T-002', 'cc', 'abierta'),
        _tarea('T-003', 'chat', 'entregada'),
        _tarea('T-004', 'codex', 'esperando'),
        _tarea('T-005', 'chat', 'integrada'),
      ]),
    );

    expect(r.porColumna[ColumnaTablero.enProgreso], 2);
    expect(r.porColumna[ColumnaTablero.enEspera], 1);
    expect(r.porColumna[ColumnaTablero.decision], 1);
    expect(r.porColumna[ColumnaTablero.finalizadas], 1);
    expect(r.totalTareas, 5);
  });

  test('una pregunta sin responder pesa más que una tarea en curso', () {
    final r = ResumenInicio.desde(
      _tablero([
        _tarea('T-001', 'cc', 'abierta'),
        _tarea('T-002', 'cc', 'esperando'),
      ]),
    );

    final cc = r.agentes.single;
    expect(cc.estado, EstadoAgente.esperandoDecision);
    expect(cc.tarea!.id, 'T-002');
    expect(cc.activas, 2);
  });

  test('un agente sin tareas vivas está disponible, no trabajando', () {
    final r = ResumenInicio.desde(
      _tablero(
        [_tarea('T-001', 'chat', 'integrada')],
        ledger: ['chat', 'cc'],
      ),
    );

    expect(r.agentes.map((a) => a.alias), ['chat', 'cc']);
    expect(r.agentes.every((a) => a.estado == EstadoAgente.disponible), isTrue);
    expect(r.activos, 0);
    expect(r.activas, 0);
  });

  test('el orden del ledger manda, y un dueño sin fila en él no se pierde', () {
    final r = ResumenInicio.desde(
      _tablero(
        [_tarea('T-001', 'nuevo', 'abierta')],
        ledger: ['chat', 'codex', 'cc'],
      ),
    );

    expect(r.agentes.map((a) => a.alias), ['chat', 'codex', 'cc', 'nuevo']);
    // Un alias desconocido se muestra tal cual, sin inventarle nombre humano.
    expect(r.agentes.last.nombre, 'nuevo');
  });

  test('la carga reparte las tareas vivas, no las del ledger', () {
    final r = ResumenInicio.desde(
      _tablero([
        _tarea('T-001', 'cc', 'abierta'),
        _tarea('T-002', 'cc', 'abierta'),
        _tarea('T-003', 'cc', 'abierta'),
        _tarea('T-004', 'chat', 'esperando'),
        _tarea('T-005', 'codex', 'entregada'),
        _tarea('T-006', 'codex', 'integrada'),
      ], ledger: ['cc', 'chat', 'codex']),
    );

    expect(r.activas, 5);
    expect(r.agentes.firstWhere((a) => a.alias == 'cc').carga, closeTo(0.6, 1e-9));
    expect(r.agentes.firstWhere((a) => a.alias == 'codex').activas, 1);
  });

  test('el tablero vacío no revienta ni divide por cero', () {
    final r = ResumenInicio.desde(_tablero([]));
    expect(r.agentes, isEmpty);
    expect(r.activas, 0);
    expect(r.pendientesDeDecision, isEmpty);
  });
}
