import 'package:duo_desktop/src/modelos/tablero.dart';
import 'package:duo_desktop/src/tema/paleta.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una respuesta real de `GET /board`, copiada del servicio en marcha.
const _respuesta = {
  'project': {
    'name': 'duo-desktop',
    'repo': '/home/david/dev/activo/duo-desktop',
    'board': '/home/david/dev/wt/board-duo-desktop',
  },
  'board': {
    'tasks': [
      {
        'id': 'T-005',
        'title': 'informe de avance',
        'owner': 'cc',
        'branch': 'cc/t-005-informe',
        'status': 'abierta',
        'opened': '2026-09-30',
      },
      {
        'id': 'T-002',
        'title': 'contrato de la API',
        'owner': 'chat',
        'branch': 'chat/t-002-contrato',
        'status': 'entregada',
        'opened': '2026-09-30',
      },
    ],
  },
  'ledger': {
    'agents': [
      {'agent': 'chat', 'points': 2, 'tasks': 2, 'last': '2026-09-30'},
      {'agent': 'codex', 'points': 1, 'tasks': 1, 'last': '2026-09-30'},
      {'agent': 'cc', 'points': 0, 'tasks': 0, 'last': null},
    ],
  },
};

void main() {
  group('Tablero.desdeJson', () {
    test('lee tareas, agentes y proyecto', () {
      final tablero = Tablero.desdeJson(Map.of(_respuesta));

      expect(tablero.proyecto!.nombre, 'duo-desktop');
      expect(tablero.tareas, hasLength(2));
      expect(tablero.agentes, hasLength(3));
    });

    test('conserva el orden de BOARD.md', () {
      final tablero = Tablero.desdeJson(Map.of(_respuesta));
      expect(tablero.tareas.map((t) => t.id), ['T-005', 'T-002']);
      expect(tablero.agentes.map((a) => a.agente), ['chat', 'codex', 'cc']);
    });

    test('un agente sin actividad llega como null, nunca como "-"', () {
      final tablero = Tablero.desdeJson(Map.of(_respuesta));
      expect(tablero.agentes.last.ultima, isNull);
      expect(tablero.agentes.first.ultima, DateTime(2026, 9, 30));
    });

    test('project es opcional: el contrato v1 no lo incluía', () {
      final sinProyecto = Map.of(_respuesta)..remove('project');
      expect(Tablero.desdeJson(sinProyecto).proyecto, isNull);
    });

    test('puntosMaximos escala las barras', () {
      expect(Tablero.desdeJson(Map.of(_respuesta)).puntosMaximos, 2);
    });
  });

  group('EstadoTarea', () {
    test('reconoce los cuatro estados del protocolo', () {
      expect(EstadoTarea.desdeTexto('abierta'), EstadoTarea.abierta);
      expect(EstadoTarea.desdeTexto('esperando'), EstadoTarea.esperando);
      expect(EstadoTarea.desdeTexto('entregada'), EstadoTarea.entregada);
      expect(EstadoTarea.desdeTexto('integrada'), EstadoTarea.integrada);
    });

    test('un estado nuevo en BOARD.md no rompe la app', () {
      expect(EstadoTarea.desdeTexto('en-curso'), EstadoTarea.desconocido);
    });

    test('conserva el texto original para mostrarlo', () {
      final tarea = Tarea.desdeJson({
        'id': 'T-009',
        'title': 'x',
        'owner': 'cc',
        'branch': 'cc/x',
        'status': 'en-curso',
        'opened': '2026-09-30',
      });
      expect(tarea.estado, EstadoTarea.desconocido);
      expect(tarea.estadoCrudo, 'en-curso');
    });
  });

  group('PaletaDatos', () {
    test('el color sigue al agente, no a su posición en el tablero', () {
      expect(PaletaDatos.claro.serieDe('chat'), PaletaDatos.claro.series[0]);
      expect(PaletaDatos.claro.serieDe('codex'), PaletaDatos.claro.series[1]);
      expect(PaletaDatos.claro.serieDe('cc'), PaletaDatos.claro.series[2]);
    });

    test('un cuarto agente no hereda un color sin validar la paleta', () {
      expect(PaletaDatos.claro.serieDe('gemini'), PaletaDatos.claro.tintaSecundaria);
    });
  });
}
