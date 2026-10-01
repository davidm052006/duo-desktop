# Contrato API — WebSocket `/events`

Estado: **diseño de contrato v1**.

Este documento define el comportamiento observable del canal WebSocket de eventos entre el servicio local de duo-desktop y la app Flutter.

No implementa código.

---

## 1. Alcance

`/events` transporta eventos efímeros de actividad en vivo:

- salida de un agente;
- cambio de estado de una tarea;
- aparición de una pregunta;
- fin de una tarea.

El WebSocket **no sustituye** a los endpoints HTTP de estado.

La fuente de verdad sigue siendo el servicio y sus recursos HTTP, especialmente:

- `GET /board`;
- `GET /questions` cuando esté disponible.

Si el cliente pierde eventos, debe reconstruir el estado actual mediante HTTP.

---

## 2. Endpoint

```text
ws://127.0.0.1:<puerto>/events
```

En producción local el servicio escucha únicamente en loopback.

No se define `wss://` para v1 porque el canal no sale de la máquina y ya está protegido por token efímero.

---

## 3. Handshake y autenticación

El WebSocket usa la misma autenticación que el resto del servicio:

```http
Authorization: Bearer <token-local>
```

Ejemplo conceptual del upgrade:

```http
GET /events HTTP/1.1
Host: 127.0.0.1:54321
Upgrade: websocket
Connection: Upgrade
Authorization: Bearer 6d75b98c...
Sec-WebSocket-Version: 13
Sec-WebSocket-Key: ...
```

### Token inválido o ausente

Si falta la cabecera, no tiene el esquema `Bearer` o el token es incorrecto, el servicio debe rechazar el upgrade con:

```http
401 Unauthorized
```

y la misma envoltura de error usada por el resto de la API cuando sea posible:

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Token local ausente o inválido."
  }
}
```

Una vez completado el upgrade no se reautentica cada mensaje.

---

## 4. Formato común de mensajes

Todos los mensajes del servidor son JSON UTF-8 y comparten este sobre:

```json
{
  "type": "agent.output",
  "sequence": 42,
  "timestamp": "2026-10-01T18:20:31.482Z",
  "payload": {}
}
```

Campos:

| Campo | Tipo | Nullable | Significado |
|---|---|---:|---|
| `type` | string | no | Tipo estable del evento. |
| `sequence` | integer | no | Secuencia monotónica dentro de la vida actual del proceso del servicio. |
| `timestamp` | string ISO-8601 UTC | no | Momento en que el servicio emitió el evento. |
| `payload` | object | no | Datos propios del tipo de evento. |

### Reglas del sobre

- `type` usa nombres en inglés con punto como separador.
- `sequence` empieza en un entero positivo y aumenta en 1 por evento emitido.
- `sequence` **no es persistente entre reinicios del servicio**.
- `timestamp` siempre va en UTC y termina en `Z`.
- El cliente debe ignorar campos adicionales que no conozca.
- Un tipo desconocido no debe romper la conexión: se ignora y se registra.

---

## 5. Evento `agent.output`

Representa una unidad de salida producida por un agente o por el proceso que lo ejecuta.

Formato exacto:

```json
{
  "type": "agent.output",
  "sequence": 42,
  "timestamp": "2026-10-01T18:20:31.482Z",
  "payload": {
    "taskId": "T-019",
    "agent": "codex",
    "stream": "stdout",
    "text": "Compilando servicio...\n"
  }
}
```

Campos de `payload`:

| Campo | Tipo | Nullable | Significado |
|---|---|---:|---|
| `taskId` | string | sí | Tarea asociada, si se conoce. |
| `agent` | string | no | Alias del agente: `chat`, `codex`, `cc` u otro futuro. |
| `stream` | string | no | `stdout` o `stderr`. |
| `text` | string | no | Fragmento de salida tal como fue recibido. |

### Semántica

- `text` puede contener uno o varios saltos de línea.
- El servicio no debe quitar ANSI ni reescribir el texto solo para presentación.
- El cliente puede colorear por `agent` y distinguir `stderr`.
- El orden entre fragmentos se conserva mediante `sequence`.
- Un fragmento no garantiza corresponder a una línea completa.

---

## 6. Evento `task.status_changed`

Indica que el estado registrado de una tarea cambió.

Formato exacto:

```json
{
  "type": "task.status_changed",
  "sequence": 43,
  "timestamp": "2026-10-01T18:20:33.017Z",
  "payload": {
    "taskId": "T-019",
    "agent": "codex",
    "previousStatus": "abierta",
    "status": "esperando"
  }
}
```

Campos:

| Campo | Tipo | Nullable | Significado |
|---|---|---:|---|
| `taskId` | string | no | Identificador de tarea. |
| `agent` | string | sí | Dueño conocido en el momento del cambio. |
| `previousStatus` | string | sí | Estado anterior, si el servicio lo conoce. |
| `status` | string | no | Nuevo estado literal del tablero. |

Estados conocidos actualmente:

```text
abierta
esperando
entregada
integrada
```

El servicio no debe traducir esos valores.

El cliente debe tolerar estados futuros desconocidos.

---

## 7. Evento `question.created`

Indica que apareció una pregunta que requiere intervención humana.

Formato exacto:

```json
{
  "type": "question.created",
  "sequence": 44,
  "timestamp": "2026-10-01T18:20:35.901Z",
  "payload": {
    "id": "T-019",
    "taskId": "T-019",
    "agent": "codex",
    "text": "¿Debo conservar compatibilidad con el formato anterior?"
  }
}
```

Campos:

| Campo | Tipo | Nullable | Significado |
|---|---|---:|---|
| `id` | string | no | Identificador de la pregunta. En v1 puede coincidir con la tarea. |
| `taskId` | string | no | Tarea que originó la pregunta. |
| `agent` | string | no | Agente que espera respuesta. |
| `text` | string | no | Texto completo de la pregunta. |

### Regla de recuperación

El evento es una notificación de aparición.

La fuente recuperable debe ser `GET /questions`.

Si Flutter se reconecta y sospecha que pudo perder eventos, debe volver a consultar `GET /questions` en lugar de depender de que el WebSocket repita preguntas antiguas.

---

## 8. Evento `task.finished`

Indica que la ejecución asociada a una tarea terminó.

Formato exacto:

```json
{
  "type": "task.finished",
  "sequence": 45,
  "timestamp": "2026-10-01T18:21:02.114Z",
  "payload": {
    "taskId": "T-019",
    "agent": "codex",
    "result": "success",
    "exitCode": 0
  }
}
```

Campos:

| Campo | Tipo | Nullable | Significado |
|---|---|---:|---|
| `taskId` | string | no | Tarea asociada. |
| `agent` | string | sí | Agente que ejecutó la tarea. |
| `result` | string | no | `success`, `failed` o `cancelled`. |
| `exitCode` | integer | sí | Código del proceso cuando exista. |

### Importante

`task.finished` describe el final de una ejecución.

No sustituye a `task.status_changed`.

Por ejemplo, una ejecución puede terminar y después el tablero registrar `entregada`. El cliente debe tratar ambos eventos como conceptos distintos.

---

## 9. Orden y entrega

El contrato v1 garantiza:

- orden de emisión dentro de una conexión;
- `sequence` monotónica durante la vida del proceso del servicio.

El contrato v1 **no garantiza**:

- entrega exactamente una vez;
- persistencia histórica de eventos;
- replay automático después de reconectar;
- conservación de la secuencia tras reiniciar el servicio.

Por tanto el canal se considera:

**best effort + recuperación por snapshot HTTP**.

---

## 10. Reconexión

### Desconexión normal o inesperada

Si el WebSocket se cierra, Flutter debe:

1. marcar el canal en vivo como desconectado;
2. conservar en pantalla el último estado conocido, pero indicar que puede estar obsoleto;
3. iniciar reconexión con backoff;
4. al reconectar, volver a sincronizar por HTTP;
5. solo después continuar aplicando eventos nuevos.

### Backoff recomendado

Valores recomendados para v1:

```text
1 s
2 s
4 s
8 s
15 s
30 s
30 s...
```

El máximo recomendado es 30 segundos.

Tras una conexión estable de al menos 30 segundos, el contador de backoff puede volver al inicio.

No se recomienda reconectar en un bucle sin espera.

---

## 11. Qué pasa con `sequence` al reconectar

El cliente debe recordar la última `sequence` observada solo como ayuda de diagnóstico.

Al reconectar:

- si la nueva secuencia es mayor y continua, puede registrar que no detectó hueco;
- si hay un salto, debe asumir que perdió eventos;
- si la secuencia vuelve a un número menor, debe asumir que el servicio reinició.

En cualquiera de estos casos, Flutter debe sincronizar:

```text
GET /board
GET /questions
```

si los endpoints están disponibles.

No existe en v1:

```text
/events?since=42
```

ni un comando WebSocket de replay.

---

## 12. Sincronización después de reconectar

Tras completar el handshake, el cliente debe hacer una lectura fresca de las fuentes recuperables.

### Siempre

```http
GET /board
```

Esto corrige:

- estados de tareas;
- nuevas tareas;
- tareas integradas;
- carga del ledger.

### Cuando exista el endpoint

```http
GET /questions
```

Esto corrige preguntas aparecidas mientras el cliente estaba desconectado.

La salida histórica de terminal no tiene garantía de recuperación en v1.

Si se perdió `agent.output`, el cliente puede indicar visualmente que hay un hueco en la salida.

---

## 13. Comportamiento del cliente ante pérdida de conexión

Flutter no debe:

- borrar el tablero;
- fingir que una tarea sigue ejecutándose;
- simular eventos perdidos;
- marcar éxito por ausencia de conexión;
- asumir que no hubo preguntas nuevas.

Flutter sí debe:

- mostrar un indicador de desconexión;
- mantener el último snapshot visible como datos potencialmente obsoletos;
- deshabilitar acciones que requieran confirmación en vivo cuando sea necesario;
- intentar reconectar;
- refrescar `GET /board` tras recuperar conexión;
- refrescar `GET /questions` si está disponible;
- registrar huecos detectados en `sequence`.

---

## 14. Heartbeat

El contrato v1 usa los mecanismos normales de WebSocket para detectar cierre.

No se define un evento JSON de aplicación tipo `ping` o `heartbeat`.

El servidor y el cliente pueden usar frames WebSocket ping/pong si su librería lo soporta.

Un ping/pong de protocolo no lleva el sobre JSON de eventos y no incrementa `sequence`.

---

## 15. Mensajes del cliente al servidor

En v1, `/events` es un canal de servidor a cliente.

Flutter no necesita enviar mensajes JSON de aplicación después del handshake.

Las acciones siguen usando HTTP:

- crear tarea: `POST /tasks`;
- responder pregunta: `POST /questions/{id}/answer`.

Si el cliente envía un mensaje de aplicación no reconocido, el servidor puede ignorarlo o cerrar con código WebSocket `1003` (tipo/dato no soportado).

---

## 16. Cierre del WebSocket

Cierres esperables:

| Código | Significado |
|---:|---|
| `1000` | cierre normal |
| `1001` | servicio o cliente terminándose |
| `1003` | mensaje de aplicación no soportado |
| `1011` | error inesperado del servidor |

La autenticación incorrecta se rechaza antes del upgrade con HTTP `401`, no con un evento WebSocket.

---

## 17. Errores de evento

Un evento individual malformado no debe provocar que Flutter pierda todo su estado.

El cliente debe:

1. registrar el problema;
2. ignorar ese mensaje;
3. continuar escuchando;
4. si el error sugiere pérdida de coherencia, solicitar un nuevo `GET /board`.

El cliente no debe interpretar parcialmente un JSON cuyo `type` requiera campos obligatorios ausentes.

---

## 18. Evolución compatible

Se consideran cambios compatibles:

- añadir campos opcionales a `payload`;
- añadir nuevos tipos de evento;
- añadir metadatos al sobre.

El cliente debe ignorar campos y tipos que no conozca.

Cambiar el significado o tipo JSON de un campo existente requiere una nueva versión del contrato.

---

## 19. Ejemplo de sesión

```json
{
  "type": "agent.output",
  "sequence": 101,
  "timestamp": "2026-10-01T18:30:00.010Z",
  "payload": {
    "taskId": "T-019",
    "agent": "codex",
    "stream": "stdout",
    "text": "Iniciando tarea T-019\n"
  }
}
```

```json
{
  "type": "task.status_changed",
  "sequence": 102,
  "timestamp": "2026-10-01T18:30:00.120Z",
  "payload": {
    "taskId": "T-019",
    "agent": "codex",
    "previousStatus": "abierta",
    "status": "esperando"
  }
}
```

```json
{
  "type": "question.created",
  "sequence": 103,
  "timestamp": "2026-10-01T18:30:00.150Z",
  "payload": {
    "id": "T-019",
    "taskId": "T-019",
    "agent": "codex",
    "text": "¿Debo mantener compatibilidad con el formato anterior?"
  }
}
```

Tras responder por HTTP y reanudar:

```json
{
  "type": "agent.output",
  "sequence": 104,
  "timestamp": "2026-10-01T18:31:10.400Z",
  "payload": {
    "taskId": "T-019",
    "agent": "codex",
    "stream": "stdout",
    "text": "Respuesta recibida. Continuando.\n"
  }
}
```

Al finalizar:

```json
{
  "type": "task.finished",
  "sequence": 105,
  "timestamp": "2026-10-01T18:32:50.000Z",
  "payload": {
    "taskId": "T-019",
    "agent": "codex",
    "result": "success",
    "exitCode": 0
  }
}
```

---

## 20. Invariantes

1. Todos los eventos son JSON UTF-8.
2. Todo evento lleva `type`, `sequence`, `timestamp` y `payload`.
3. `sequence` aumenta durante la vida del proceso actual.
4. El servicio no promete replay en v1.
5. El WebSocket no sustituye a `GET /board`.
6. La reconexión siempre termina con resincronización HTTP.
7. La UI no inventa eventos perdidos.
8. La autenticación usa exclusivamente `Authorization: Bearer`.
9. `agent.output.text` conserva la salida recibida.
10. Los estados de tarea usan los valores literales del dominio actual.
11. `question.created` es recuperable mediante `GET /questions`.
12. `task.finished` y `task.status_changed` no son equivalentes.
13. Un tipo futuro desconocido no rompe clientes v1.

---

## 21. Fuera de alcance de v1

- replay histórico de eventos;
- ACK por evento;
- entrega exactly-once;
- almacenamiento persistente de salida de terminal;
- compresión a nivel de aplicación;
- multiplexar varios proyectos activos en una conexión;
- eventos binarios;
- comandos de cliente por WebSocket;
- autenticación distinta al token local;
- exposición del WebSocket fuera de loopback.

---

## 22. Responsabilidad de Flutter

Flutter debe separar dos conceptos:

### Estado recuperable

Se vuelve a leer por HTTP:

- tablero;
- estados;
- preguntas.

### Actividad efímera

Solo existe mientras llega por WebSocket:

- salida en vivo;
- transiciones inmediatas;
- avisos de fin.

La pantalla puede usar los eventos para reaccionar al instante, pero el snapshot HTTP sigue siendo la autoridad después de cualquier reconexión.
