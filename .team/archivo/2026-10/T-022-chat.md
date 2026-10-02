# T-022 — Entregable chat

## Estado

Implementado en:

`chat/t-022-escribe-docs-api-contrato-eventos-md-el-`

Base: `main`. No se escribió en `main`.

## Alcance mínimo

Solo se añadió:

- `docs/api/CONTRATO_EVENTOS.md`

No se modificó código C# ni Flutter.

## Contrato definido

El documento especifica el WebSocket:

`/events`

y fija:

- handshake WebSocket sobre loopback;
- autenticación con `Authorization: Bearer <token-local>`;
- rechazo HTTP 401 antes del upgrade si el token es inválido;
- sobre JSON común con:
  - `type`;
  - `sequence`;
  - `timestamp`;
  - `payload`;
- secuencia monotónica por vida del proceso del servicio;
- tolerancia de campos y tipos futuros desconocidos.

## Tipos de evento

Se documentaron cuatro formatos exactos:

- `agent.output`;
- `task.status_changed`;
- `question.created`;
- `task.finished`.

Cada uno incluye su payload, tipos, nullabilidad y semántica.

## Reconexión

Se decidió v1 como:

**best effort + recuperación mediante snapshot HTTP**

No hay replay histórico ni `/events?since=`.

Al perder conexión Flutter debe:

1. marcar el canal como desconectado;
2. conservar el último estado como potencialmente obsoleto;
3. reconectar con backoff;
4. tras reconectar consultar `GET /board`;
5. consultar `GET /questions` cuando esté disponible;
6. continuar con eventos nuevos.

También se documentó cómo interpretar saltos o reinicios de `sequence`.

## Salida de terminal

`agent.output` se considera efímero en v1.

Si se pierden fragmentos durante una desconexión, el cliente no debe inventarlos. Puede indicar que existe un hueco.

## Coordinación con T-019

T-019 de Codex implementa el streaming en `service/` y define el mismo esquema Bearer. T-022 no invade su territorio: únicamente define el contrato en `docs/api/`.

## Commit

- `dafb90a` docs(api): define contrato WebSocket de eventos

Con trailers:

`Tarea: T-022`
`Agente: chat`

## Validación

Contra `main`:

- ahead: 1
- behind: 0
- archivos modificados: 1

No requiere tests porque es exclusivamente documentación de diseño.
