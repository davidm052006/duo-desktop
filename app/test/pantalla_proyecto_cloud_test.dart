import 'package:duo_desktop/src/datos/cliente_cloud.dart';
import 'package:duo_desktop/src/pantallas/pantalla_proyecto_cloud.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _proyectoBase = ProyectoCloud(
  id: 'project-1',
  nombre: 'Proyecto prueba',
  slug: 'prueba',
  repositorio: 'duo/prueba',
  ramaObjetivo: 'release',
  rol: 'owner',
);

class _CloudFalso extends ClienteCloud {
  _CloudFalso(this._tareas);

  final List<TareaCloud> _tareas;

  @override
  Future<List<MiembroCloud>> miembros(String projectId) async => const [
        MiembroCloud(
          id: 'member-1',
          email: 'owner@example.test',
          nombre: 'Owner',
          rol: 'owner',
        ),
      ];

  @override
  Future<List<TareaCloud>> tareas(String projectId) async => _tareas;
}

ProyectoCloud _proyecto(String rol) => ProyectoCloud(
      id: _proyectoBase.id,
      nombre: _proyectoBase.nombre,
      slug: _proyectoBase.slug,
      repositorio: _proyectoBase.repositorio,
      ramaObjetivo: _proyectoBase.ramaObjetivo,
      rol: rol,
    );

TareaCloud _tarea({String estado = 'pending', PullRequestCloud? pr}) =>
    TareaCloud(
      id: 'task-1',
      externalId: 'T-101',
      titulo: 'Tarea compartida',
      ownerAgent: 'codex',
      estado: estado,
      rama: 'codex/t-101',
      assignedUserId: 'member-1',
      assignedEmail: 'owner@example.test',
      workProvider: 'codex',
      pullRequest: pr,
    );

Widget _app(String rol, List<TareaCloud> tareas) => MaterialApp(
      theme: TemaDuo.claro(),
      home: Scaffold(
        body: PantallaProyectoCloud(
          proyecto: _proyecto(rol),
          volver: () {},
          cloud: _CloudFalso(tareas),
        ),
      ),
    );

void main() {
  testWidgets('viewer no ve acciones de escritura', (tester) async {
    await tester.pumpWidget(_app('viewer', [_tarea()]));
    await tester.pumpAndSettle();

    expect(find.text('Invitar'), findsNothing);
    expect(find.text('Nueva tarea'), findsNothing);
    expect(find.text('Registrar PR'), findsNothing);
  });

  testWidgets('editor crea tarea y no puede confirmar merge', (tester) async {
    await tester.pumpWidget(_app('editor', [_tarea()]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tareas'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva tarea'), findsOneWidget);
    await tester.tap(find.text('Registrar PR'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar merge'), findsNothing);
  });

  testWidgets('owner ve invitar y acciones owner', (tester) async {
    await tester.pumpWidget(_app('owner', [_tarea()]));
    await tester.pumpAndSettle();

    expect(find.text('Invitar'), findsOneWidget);
    await tester.tap(find.text('Tareas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar PR'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar merge'), findsNothing);
    expect(
      find.textContaining('El merge no se confirma manualmente aquí'),
      findsOneWidget,
    );
  });

  testWidgets('workspace conserva estructura embebida', (tester) async {
    await tester.pumpWidget(_app('owner', [_tarea()]));
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Miembros'), findsOneWidget);
    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('Revisiones'), findsOneWidget);
  });

  testWidgets('finalized se distingue de in_review en Revisiones', (tester) async {
    final abierto = PullRequestCloud(
      numero: 10,
      url: 'https://example.test/10',
      ramaOrigen: 'feature/a',
      ramaObjetivo: 'release',
      estado: 'open',
      estadoRevision: 'approved',
    );
    final merged = PullRequestCloud(
      numero: 11,
      url: 'https://example.test/11',
      ramaOrigen: 'feature/b',
      ramaObjetivo: 'release',
      estado: 'merged',
      mergedAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      _app('viewer', [
        _tarea(estado: 'in_review', pr: abierto),
        _tarea(estado: 'finalized', pr: merged),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revisiones'));
    await tester.pumpAndSettle();
    expect(find.text('IN REVIEW'), findsOneWidget);
    expect(find.text('MERGED'), findsOneWidget);
  });
}
