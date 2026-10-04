# Fase 2 — Lanzar y ver

## Objetivo

Cerrar el flujo de extremo a extremo:

```text
Flutter
  │
  ├── POST /tasks ──► servicio .NET ──► duo "<tarea>"
  │
  └── WS /events ◄── board_snapshot / board_changed / agent_output
```

La Fase 2 no implementa un PTY. La salida de agente es observabilidad en vivo;
la terminal interactiva sigue perteneciendo a la Fase 5.

## Fuente de verdad en Flutter

`EstadoTablero` es el único estado compartido del workspace.

1. Hace una lectura HTTP inicial de `GET /board`.
2. Abre `ws://127.0.0.1:<puerto>/events` con el mismo Bearer token.
3. Al recibir `board_snapshot` o `board_changed`, sustituye el tablero completo.
4. Al recibir `agent_output`, conserva bloques recientes para la vista de salida.
5. Mientras el WebSocket está conectado, no sondea `GET /board`.
6. Si el WebSocket cae, conserva la última pizarra válida, vuelve al sondeo y reintenta la conexión.

Esto evita dos stores que puedan divergir.

## Contrato de eventos

### Pizarra

```json
{
  "type": "board_snapshot",
  "board": {
    "project": {},
    "board": {"tasks": []},
    "ledger": {"agents": []}
  }
}
```

`board_changed` tiene la misma forma.

### Salida

```json
{
  "type": "agent_output",
  "taskId": "T-042",
  "agent": "codex",
  "text": "..."
}
```

La app no interpreta el contenido de `text`; lo presenta como salida del proceso.

## Recuperación

El canal en vivo es optimista, no obligatorio para conservar la app usable:

- HTTP inicial permite arrancar aunque el WebSocket tarde.
- caída del WebSocket no borra el tablero visible;
- sondeo de respaldo mantiene el estado;
- reconexión automática devuelve la app al modo en vivo.

## Seguridad

HTTP y WebSocket usan el mismo token efímero. El WebSocket se conecta solamente
a `127.0.0.1`. No se añade un segundo mecanismo de autenticación.

## Criterio de cierre

La Fase 2 está cerrada cuando se demuestra:

- una tarea puede crearse desde Flutter;
- `duo` recibe el texto como un único argumento;
- el ID creado vuelve por HTTP;
- la pizarra se actualiza por WebSocket;
- la salida de sesión aparece en la vista en vivo;
- una caída del WebSocket activa sondeo y reconexión;
- servicio, tests y Flutter compilan;
- CEF/Chats no sufren regresiones.
