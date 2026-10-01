# T-017 — Entregable chat

## Estado

Implementado en:

`chat/t-017-implementa-el-inspector-de-tarea-en-la-a`

Base: `main`. No se escribió en `main`.

## Alcance mínimo

Solo:

- `app/lib/src/widgets/tablero_kanban.dart`
- `app/lib/src/modelos/tablero.dart`

No se modificó backend.

## Implementación

- Al pulsar una tarjeta del Kanban se selecciona y aparece un inspector persistente a la derecha.
- El inspector ya no usa un diálogo modal.
- Muestra:
  - id;
  - título;
  - estado;
  - agente;
  - rama Git;
  - fecha de apertura;
  - archivos tocados, cuando GET /board los entregue;
  - diagnóstico del agente, cuando GET /board lo entregue.
- La tarjeta seleccionada queda visualmente resaltada.
- El panel se puede cerrar con su botón.
- El tablero conserva un ancho mínimo legible y mantiene scroll horizontal.
- Si GET /board aún no entrega archivos/diagnóstico, se muestra un estado explícito de “no disponible”, sin inventar contenido.
- El modelo `Tarea` acepta de forma compatible campos opcionales:
  - `files`, `touchedFiles` o `touched_files`;
  - `diagnosis` o `diagnostic`.
- Tras refrescar el tablero, el inspector se resincroniza con la instancia nueva de la misma tarea o se cierra si la tarea desaparece.

## Commits

- `aaed68b` feat(model): admite datos opcionales del inspector
- `1882950` feat(board): añade inspector lateral de tarea
- `acd00e0` fix(board): resincroniza inspector tras refrescar

Todos llevan:

`Tarea: T-017`
`Agente: chat`

## Validación

Contra `main`:

- ahead: 3
- behind: 0
- archivos modificados: 2

No se pudo ejecutar el worktree local desde el conector GitHub. Verificar en la rama:

`cd app && flutter analyze`

y abrir la app Linux para comprobar el comportamiento del panel lateral a distintos anchos.

## Nota de contrato

El GET /board actual de main todavía no expone archivos tocados ni diagnóstico. La UI queda preparada para esos campos sin atribuir datos inexistentes.
