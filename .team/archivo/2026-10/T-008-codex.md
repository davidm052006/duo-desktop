# T-008 — entregable de `codex`

**Rama:** `codex/t-008-implementa-las-vistas-preguntas-e-histor`  
**Cerrado:** 2026-10-01 15:24

## Cambios contra la base

```
 app/lib/src/pantallas/pantalla_historial.dart | 255 +++++++++++++++++++++++++-
 app/lib/src/pantallas/pantalla_preguntas.dart | 226 ++++++++++++++++++++++-
 app/test/pantalla_historial_test.dart         |  97 ++++++++++
 app/test/pantalla_preguntas_test.dart         | 114 ++++++++++++
 4 files changed, 679 insertions(+), 13 deletions(-)
```

## Lo que reportó el agente

+    );
+
+    await tester.pumpWidget(_app(estado));
+
+    expect(find.text('T-008'), findsOneWidget);
+    expect(find.text('decidir el nombre de la vista'), findsOneWidget);
+    expect(find.text('codex'), findsOneWidget);
+    expect(find.text('esperando'), findsOneWidget);
+    expect(find.text('El texto de la pregunta no viene en /board.'), findsOneWidget);
+    expect(find.text('una tarea que sigue abierta'), findsNothing);
+  });
+
+  testWidgets('Responder revela duo ask sin ejecutar una acción', (tester) async {
+    final estado = await _estadoCon(
+      _tablero([
+        {
+          'id': 'T-008',
+          'title': 'decidir el nombre de la vista',
+          'owner': 'codex',
+          'branch': 'codex/t-008',
+          'status': 'esperando',
+          'opened': '2026-10-01',
+        },
+      ]),
+    );
+    await tester.pumpWidget(_app(estado));
+
+    await tester.tap(find.text('Responder'));
+    await tester.pumpAndSettle();
+
+    expect(find.text('Responder desde Duo'), findsOneWidget);
+    expect(find.text('duo ask'), findsOneWidget);
+  });
+
+  testWidgets('sin tareas esperando muestra un estado vacío', (tester) async {
+    final estado = await _estadoCon(_tablero([]));
+    await tester.pumpWidget(_app(estado));
+
+    expect(find.text('SIN PREGUNTAS PENDIENTES'), findsOneWidget);
+    expect(find.text('Ningún agente está esperando una respuesta.'), findsOneWidget);
+  });
+}

tokens used
109.289
Completé T-008 sin tocar `marco_app.dart`.

- Preguntas: tareas `esperando`, vacío honesto, carga/error, y diálogo con `duo ask` sin ejecutar comandos.
- Historial: línea de tiempo agrupada por fecha de apertura, con tarea, agente y estado; aclara que `/board` no aporta eventos ni fechas de cambio.
- Añadí tests de widget para ambas pantallas: filtrado y respuesta en Preguntas; agrupación, orden y vacío en Historial.
- Verificado con `dart format`, `dart analyze` y `git diff --check`.

Pendiente de entorno: `flutter test` no pudo iniciar porque el SDK Flutter está montado como solo lectura y no puede crear su lock/caché. David debe ejecutar:

```bash
cd app
flutter test test/pantalla_preguntas_test.dart test/pantalla_historial_test.dart
```

También debe habilitar ambos destinos en el sidebar al integrar, como indicó.
