# WebSocket `/events`

`/events` exige la misma cabecera que la API HTTP: `Authorization: Bearer <token-local>`.
Una conexión sin token recibe HTTP 401 antes del upgrade; una petición HTTP normal recibe
HTTP 400 con `error.code = "websocket_required"`.

Cada frame es un objeto JSON UTF-8 y se identifica con `type`.

```json
{"type":"board_snapshot","board":{"project":{},"board":{"tasks":[]},"ledger":{"agents":[]}}}
```

Se envía una instantánea al conectar y `board_changed` cuando cambia `BOARD.md` o
`ledger.tsv`. Ambos llevan la respuesta completa de `GET /board` en `board`, para que el
cliente no tenga que reconstruir estados desde parches.

```json
{"type":"agent_output","taskId":"T-019","agent":"codex","text":"línea nueva\n"}
```

`agent_output` se emite por cada bloque nuevo escrito en `.team/sesiones/T-NNN.txt`.
`text` no se procesa ni se interpreta: puede contener varias líneas o códigos ANSI. Si una
sesión aún no tiene tarea en el tablero, `agent` es `null`.
