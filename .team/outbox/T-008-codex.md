# T-008 — entregable de `codex`

**Rama:** `codex/t-008-implementa-las-vistas-preguntas-e-histor`  
**Cerrado:** 2026-10-01 15:17

## Cambios contra la base

```
 app/lib/src/pantallas/pantalla_preguntas.dart | 226 +++++++++++++++++++++++++-
 1 file changed, 219 insertions(+), 7 deletions(-)
```

## Lo que reportó el agente

+        child: OutlinedButton.icon(
+          onPressed: () => _muestraComando(context),
+          icon: const Icon(Icons.terminal, size: 16),
+          label: const Text('Responder'),
+        ),
+      ),
+    );
+  }
+
+  static String _fecha(DateTime fecha) {
+    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
+    return '${fecha.year}-${dosDigitos(fecha.month)}-${dosDigitos(fecha.day)}';
+  }
+
+  static Future<void> _muestraComando(BuildContext context) => showDialog<void>(
+    context: context,
+    builder: (contextoDialogo) => AlertDialog(
+      title: const Text('Responder desde Duo'),
+      content: Column(
+        mainAxisSize: MainAxisSize.min,
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          const Text(
+            'La app todavía no envía respuestas al agente. Ejecuta este comando:',
+          ),
+          const SizedBox(height: 14),
+          SelectableText(
+            'duo ask',
+            style: Theme.of(
+              contextoDialogo,
+            ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
+          ),
+        ],
+      ),
+      actions: [
+        TextButton(
+          onPressed: () => Navigator.pop(contextoDialogo),
+          child: const Text('Cerrar'),
+        ),
+      ],
+    ),
+  );
 }

tokens used
57.312
Implementé `PantallaPreguntas` en [pantalla_preguntas.dart](/home/david/dev/wt/codex-duo-desktop/app/lib/src/pantallas/pantalla_preguntas.dart):

- Consume `EstadoTablero` y filtra tareas `esperando`.
- Muestra carga, error/reintento, lista y estado vacío honesto.
- Declara que `/board` no incluye el texto real de la pregunta.
- Cada tarjeta muestra tarea, agente, fecha, estado y “Responder”, que abre el comando `duo ask` sin ejecutarlo.
- Verificado con `dart analyze`: sin incidencias. `flutter analyze` no pudo ejecutarse porque el SDK intenta escribir fuera del workspace.

Quedó pendiente Historial y los tests de widget: el territorio asignado autoriza exclusivamente ese archivo. Tampoco pude crear commit: el metadato Git del worktree está en un filesystem de solo lectura y no permite crear `index.lock`.

David debe verificar la pantalla con una tarea `esperando`, el diálogo de respuesta y el vacío.

## PREGUNTA
1. ¿Autorizas ampliar el territorio a `pantalla_historial.dart`, `marco_app.dart` y los tests correspondientes para completar Historial, habilitar ambas rutas y añadir las pruebas solicitadas?
