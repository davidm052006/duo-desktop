# T-016 — Entregable chat

## Estado

Implementado directamente en la rama:

`chat/t-016-implementa-el-formulario-nueva-tarea-en-`

Base: `main`. No se escribió en `main`.

## Alcance mínimo

Cambios limitados a:

- `app/lib/src/pantallas/pantalla_inicio.dart`
- `app/lib/src/datos/cliente_duo.dart`

No se modificó backend ni contrato HTTP del servicio.

## Nueva tarea

El botón de Inicio deja de estar deshabilitado y abre un diálogo con:

- descripción obligatoria;
- selector de agente: Automático, chat, codex o cc;
- alcance opcional;
- estado de envío;
- error visible dentro del diálogo.

El formulario mantiene el estilo oscuro de `pantalla_inicio.dart`, usando la paleta y componentes existentes.

## POST /tasks

Se añadió `ClienteDuo.crearTarea()`.

Envía:

```json
{
  "text": "texto de la tarea",
  "agent": "chat",
  "scope": "alcance opcional"
}
```

- `agent` se omite cuando se selecciona Automático.
- `scope` se omite cuando está vacío.
- Usa `Authorization: Bearer`.
- Usa `Content-Type: application/json`.
- Un 2xx se considera creación aceptada por el servicio.
- En errores JSON del servicio se muestra exactamente `error.message`.
- Si el backend aún no implementa el endpoint y devuelve 404, no se simula éxito y el diálogo permanece abierto.
- En éxito se cierra el diálogo y se refresca el tablero.

El nombre `text` se alineó con T-014 de Codex, cuya tarea de backend define que POST /tasks ejecuta duo con “el texto de la tarea”.

## Commits

- `505beec` feat(api): añade cliente POST /tasks
- `fbdb49a` feat(ui): añade diálogo Nueva tarea
- `2c84624` fix(api): alinea POST tasks con campo text

Todos incluyen:

`Tarea: T-016`
`Agente: chat`

## Validación

Comparación contra `main`:

- ahead por 3 commits
- behind por 0 commits
- 2 archivos modificados

No se pudo ejecutar `flutter analyze` desde el conector remoto de GitHub. En el worktree de la rama ejecutar:

`cd app && flutter analyze`

Después abrir la app Linux desde esta rama y verificar:

1. Nueva tarea abre el diálogo.
2. Descripción vacía no se envía.
3. Automático omite `agent`.
4. Los agentes manuales envían su alias.
5. Alcance vacío se omite.
6. Mientras POST /tasks no exista, el error permanece visible y no se informa éxito.
7. Tras integrar T-014, una respuesta 2xx cierra el diálogo y refresca Inicio.

## Coordinación

T-014 pertenece a Codex y toca únicamente `service/`. No se invadió su territorio.
