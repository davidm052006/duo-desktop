# T-007 — entregable de `codex`

**Rama:** `codex/t-007-continua-con-la-fase-dos-en-docs-diseno-`  
**Cerrado:** 2026-10-01 00:04

## Cambios contra la base

```
 app/lib/src/pantallas/pantalla_tablero.dart |  73 ++++--
 app/lib/src/widgets/tablero_kanban.dart     | 382 ++++++++++++++++++++++++++++
 app/test/pantalla_tablero_test.dart         |  40 ++-
 3 files changed, 465 insertions(+), 30 deletions(-)
```

## Lo que reportó el agente

+      children: [
+        Expanded(child: Text(etiqueta)),
+        Text(fase),
+      ],
+    ),
+  );
+}
+
+class _SinTareasKanban extends StatelessWidget {
+  const _SinTareasKanban();
+
+  @override
+  Widget build(BuildContext context) => Center(
+    child: Text(
+      'No hay tareas abiertas.',
+      style: Theme.of(context).textTheme.bodyMedium,
+    ),
+  );
+}
diff --git a/app/test/pantalla_tablero_test.dart b/app/test/pantalla_tablero_test.dart
index 65450cfd9e1990970cfd7b1f3df4f00b8d62b86e..0ffb8edfaac5f55c86d1ab841fb2883fcd5b2a3e
--- a/app/test/pantalla_tablero_test.dart
+++ b/app/test/pantalla_tablero_test.dart
@@ -83,6 +83,19 @@
     expect(find.text('entregada'), findsOneWidget);
   });
 
+  testWidgets('organiza las tareas en las cuatro columnas del Kanban', (tester) async {
+    await tester.binding.setSurfaceSize(const Size(1280, 900));
+    addTearDown(() => tester.binding.setSurfaceSize(null));
+    final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
+    await tester.pumpWidget(_app(estado));
+
+    expect(find.text('EN ESPERA'), findsOneWidget);
+    expect(find.text('EN PROGRESO'), findsOneWidget);
+    expect(find.text('NECESITA DECISIÓN'), findsOneWidget);
+    expect(find.text('FINALIZADAS'), findsOneWidget);
+    expect(find.text('INSPECTOR DE TAREA'), findsOneWidget);
+  });
+
   testWidgets('cada barra de carga lleva su cifra escrita al lado', (tester) async {
     final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
     await tester.pumpWidget(_app(estado));

tokens used
62.615
Implementé la vista Kanban de Fase 2:

- Cuatro columnas, tarjetas con datos reales, contadores e inspector lateral seleccionable.
- Adaptación responsive: inspector en escritorio; columnas apiladas en ancho reducido.
- Acciones aún no disponibles señaladas como Fase 2/Fase 3.
- Añadí test de estructura Kanban.
- Alcance mínimo: `app/lib/src/pantallas/pantalla_tablero.dart`, nuevo widget `app/lib/src/widgets/tablero_kanban.dart` y su test.

Pendiente: no pude crear el commit porque el directorio Git del worktree está montado en solo lectura al crear `index.lock`. Tampoco pude ejecutar Flutter tests: el SDK compartido intenta escribir su caché fuera del workspace. `git diff --check` pasó.

David debe verificar visualmente la distribución en escritorio y, cuando el SDK/Git sean escribibles, ejecutar `cd app && flutter test test/pantalla_tablero_test.dart`.

## PREGUNTA
1. En `docs/diseno/` solo existe `02-tablero-kanban.jpeg`; ¿dónde está la referencia de “tablero kanban 2” para implementar también ese diseño?
