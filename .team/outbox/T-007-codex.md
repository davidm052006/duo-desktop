# T-007 — entregable de `codex`

**Rama:** `codex/t-007-continua-con-la-fase-dos-en-docs-diseno-`  
**Cerrado:** 2026-10-01 00:22

## Cambios contra la base

```
 app/lib/main.dart                                  |  10 +-
 app/lib/src/modelos/resumen.dart                   | 162 ++++
 app/lib/src/pantallas/marco_app.dart               | 277 +++++++
 app/lib/src/pantallas/pantalla_inicio.dart         | 849 +++++++++++++++++++++
 app/lib/src/pantallas/pantalla_tablero.dart        |  73 +-
 app/lib/src/tema/paleta.dart                       |  28 +
 app/lib/src/widgets/tablero_kanban.dart            | 401 ++++++++++
 app/lib/src/widgets/tarjeta.dart                   | 138 ++++
 app/test/pantalla_inicio_test.dart                 | 173 +++++
 app/test/pantalla_tablero_test.dart                |  55 +-
 app/test/resumen_test.dart                         | 114 +++
 docs/diseno/02-tablero-kanban.jpeg                 | Bin 387621 -> 0 bytes
 docs/diseno/README.md                              |  29 -
 .../01-inicio-centro-de-control.jpeg"              | Bin
 "docs/dise\303\261o/README.md"                     | 175 +++++
 "docs/dise\303\261o/tablero kaban 2.png"           | Bin 0 -> 966961 bytes
 "docs/dise\303\261o/tablero kaban.jpeg"            | Bin 0 -> 156171 bytes
 17 files changed, 2419 insertions(+), 65 deletions(-)
```

## Lo que reportó el agente

       ),
     );
diff --git a/app/test/pantalla_tablero_test.dart b/app/test/pantalla_tablero_test.dart
index b05791c002ab2223f7e06c22d1820255b85f8a85..c3611aa0bd391f9ed93132e1992d76a4d56db4c5
--- a/app/test/pantalla_tablero_test.dart
+++ b/app/test/pantalla_tablero_test.dart
@@ -63,7 +63,7 @@
 );
 
 void main() {
-  testWidgets('pinta las tareas en el orden del tablero', (tester) async {
+  testWidgets('pinta las tareas y las distribuye según su estado', (tester) async {
     final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
     await tester.pumpWidget(_app(estado));
 
@@ -71,8 +71,9 @@
     expect(find.text('informe de avance'), findsOneWidget);
     expect(find.text('T-002'), findsOneWidget);
 
-    double posY(String t) => tester.getTopLeft(find.text(t)).dy;
-    expect(posY('T-005'), lessThan(posY('T-002')));
+    double posX(String t) => tester.getTopLeft(find.text(t)).dx;
+    // `entregada` va a En espera y `abierta` a En progreso.
+    expect(posX('T-002'), lessThan(posX('T-005')));
   });
 
   testWidgets('cada estado se nombra, no solo se colorea', (tester) async {
@@ -95,7 +96,13 @@
     expect(find.text('EN PROGRESO'), findsOneWidget);
     expect(find.text('NECESITA DECISIÓN'), findsOneWidget);
     expect(find.text('FINALIZADAS'), findsOneWidget);
+    expect(find.text('INSPECTOR DE TAREA'), findsNothing);
+
+    await tester.tap(find.text('T-005'));
+    await tester.pumpAndSettle();
+
     expect(find.text('INSPECTOR DE TAREA'), findsOneWidget);
+    expect(find.byTooltip('Cerrar inspector'), findsOneWidget);
   });
 
   testWidgets('cada barra de carga lleva su cifra escrita al lado', (

tokens used
62,026
Implementé la corrección de T-007:

- Corregí el mapeo de estados a las columnas acordadas.
- Las cuatro columnas conservan ancho legible y usan desplazamiento horizontal.
- El inspector pasó a ser un modal cerrable de máximo 420 px, sin tapar columnas lateralmente.
- Añadí acciones futuras deshabilitadas por fase.
- Actualicé pruebas para el mapeo y apertura del inspector.

Cambios en:

- [tablero_kanban.dart](/home/david/dev/wt/codex-duo-desktop/app/lib/src/widgets/tablero_kanban.dart)
- [pantalla_tablero_test.dart](/home/david/dev/wt/codex-duo-desktop/app/test/pantalla_tablero_test.dart)

Verificación: `git diff --check` pasó.

Pendiente: no pude ejecutar Flutter ni crear commit; el sandbox bloquea escritura en la caché global de Flutter y en el `index.lock` administrativo del worktree. David debe ejecutar `flutter analyze` y `flutter test test/pantalla_tablero_test.dart` desde `app/`, y crear el commit con los trailers T-007 indicados.
