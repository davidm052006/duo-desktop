# T-008 — entregable de `codex`

**Rama:** `codex/t-008-la-vista-de-el-tablero-kaban-se-ve-rara-`  
**Cerrado:** 2026-10-01 02:00

## Cambios contra la base

```
 app/lib/main.dart                           |   3 +-
 app/lib/src/pantallas/pantalla_tablero.dart | 104 ++++++---
 app/lib/src/tema/paleta.dart                |  23 ++
 app/lib/src/widgets/carga_agentes.dart      | 148 +++++++-----
 app/lib/src/widgets/tablero_kanban.dart     | 350 ++++++++++++++++++++++++++++
 app/test/pantalla_tablero_test.dart         |  65 +++++-
 6 files changed, 588 insertions(+), 105 deletions(-)
```

## Lo que reportó el agente

     expect(find.text('T-002'), findsOneWidget);
 
-    double posY(String t) => tester.getTopLeft(find.text(t)).dy;
-    expect(posY('T-005'), lessThan(posY('T-002')));
+    expect(find.text('EN ESPERA'), findsOneWidget);
+    expect(find.text('EN PROGRESO'), findsOneWidget);
+    expect(find.text('NECESITA DECISIÓN'), findsOneWidget);
+    expect(find.text('FINALIZADAS'), findsOneWidget);
+
+    double posX(String t) => tester.getTopLeft(find.text(t)).dx;
+    expect(posX('T-002'), lessThan(posX('T-005')));
   });
 
   testWidgets('cada estado se nombra, no solo se colorea', (tester) async {
@@ -83,6 +90,33 @@
     expect(find.text('entregada'), findsOneWidget);
   });
 
+  testWidgets('en una ventana estrecha el tablero conserva sus columnas', (
+    tester,
+  ) async {
+    await tester.binding.setSurfaceSize(const Size(360, 700));
+    addTearDown(() => tester.binding.setSurfaceSize(null));
+    final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
+    await tester.pumpWidget(_app(estado));
+
+    expect(find.text('EN ESPERA'), findsOneWidget);
+    expect(find.text('EN PROGRESO'), findsOneWidget);
+    expect(tester.takeException(), isNull);
+  });
+
+  testWidgets('al abrir una tarjeta el inspector usa el detalle completo', (
+    tester,
+  ) async {
+    final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
+    await tester.pumpWidget(_app(estado));
+
+    await tester.tap(find.text('T-005'));
+    await tester.pumpAndSettle();
+
+    expect(find.text('INSPECTOR DE TAREA'), findsOneWidget);
+    expect(find.text('ESTADO ACTUAL'), findsOneWidget);
+    expect(find.byTooltip('Cerrar inspector'), findsOneWidget);
+  });
+
   testWidgets('cada barra de carga lleva su cifra escrita al lado', (tester) async {
     final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
     await tester.pumpWidget(_app(estado));

tokens used
89.837
Completado el alcance mínimo: tablero Kanban, inspector de tarjetas y responsive.

- Reemplacé la tabla por 4 columnas Kanban; en ventanas estrechas conserva la lectura con scroll horizontal, sin aplastar cards.
- El inspector abre como diálogo adaptativo y aplica el panel oscuro y acentos rosa/cian del diseño.
- La carga de agentes ahora se reorganiza en formato compacto para evitar desbordes.
- El título y el contenido principal truncan/scrollan correctamente al reducir la ventana.
- Añadí pruebas para columnas, tamaño estrecho e inspector.

Verificación: `dart analyze lib test/pantalla_tablero_test.dart` pasó sin incidencias; `git diff --check` también. No fue posible correr `flutter test` porque el SDK compartido intenta crear un lockfile en una ruta de solo lectura. Tampoco pude crear el commit: el índice Git compartido está en esa misma ruta de solo lectura. Los cambios quedan listos en el worktree para que duo los formalice.
