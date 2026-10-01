# T-002 — entregable de `chat`

**Rama:** `chat/t-002-disena-el-contrato-de-la-api-del-servici`  
**Recogido:** 2026-09-30 17:27  
**Vía:** portapapeles

---

# Contrato API — `GET /board`

Estado: **diseño de contrato v1**. Este documento define el comportamiento observable del endpoint; no implementa código.

## 1. Alcance

El endpoint expone en una sola respuesta JSON el estado actual del tablero de `duo` para el proyecto activo.

La fuente de verdad es exclusivamente:

```text
.team/BOARD.md
.team/ledger.tsv
```

El endpoint es de **solo lectura**.

No ejecuta el CLI `duo`, no consulta GitHub, no inspecciona ramas y no modifica ningún archivo.

---

## 2. Endpoint

```http
GET /board
```

El servicio local escucha únicamente en `127.0.0.1`, según la arquitectura actual de `duo-desktop`.

### Autenticación

La arquitectura ya establece que Flutter y el servicio se comunican usando un token local en una cabecera.

Para este contrato se fija:

```http
Authorization: Bearer <token-local>
```

Ejemplo:

```http
GET /board HTTP/1.1
Host: 127.0.0.1:54321
Authorization: Bearer 6d75b98c...
Accept: application/json
```

No hay parámetros de path, query ni body.

---

# 3. Respuesta `200 OK`

```http
Content-Type: application/json
```

Forma exacta:

```json
{
  "board": {
    "tasks": [
      {
        "id": "T-002",
        "title": "diseña el contrato de la API del servicio: GET /board que devuelve el tablero y el ledger leyendo .team/, con el JSON exacto de respuesta y los codigos de error",
        "owner": "chat",
        "branch": "chat/t-002-disena-el-contrato-de-la-api-del-servici",
        "status": "abierta",
        "opened": "2026-09-30"
      }
    ]
  },
  "ledger": {
    "agents": [
      {
        "agent": "chat",
        "points": 2,
        "tasks": 2,
        "last": "2026-09-30"
      },
      {
        "agent": "codex",
        "points": 0,
        "tasks": 0,
        "last": null
      },
      {
        "agent": "cc",
        "points": 0,
        "tasks": 0,
        "last": null
      }
    ]
  }
}
```

La estructura superior siempre contiene exactamente estos dos objetos conceptuales:

```text
board
ledger
```

---

# 4. Modelo JSON

## `board`

```json
{
  "tasks": []
}
```

### `board.tasks[]`

| Campo | Tipo JSON | Nullable | Significado |
|---|---|---:|---|
| `id` | string | no | Identificador `T-NNN`. |
| `title` | string | no | Título completo de la tarea. |
| `owner` | string | no | Agente dueño: actualmente `chat`, `codex` o `cc`. |
| `branch` | string | no | Rama de trabajo declarada por `duo`. |
| `status` | string | no | Estado registrado en `BOARD.md`. |
| `opened` | string | no | Fecha ISO `YYYY-MM-DD`. |

Ejemplo:

```json
{
  "id": "T-002",
  "title": "diseña el contrato de la API del servicio",
  "owner": "chat",
  "branch": "chat/t-002-disena-el-contrato-de-la-api-del-servici",
  "status": "abierta",
  "opened": "2026-09-30"
}
```

---

## `ledger`

```json
{
  "agents": []
}
```

### `ledger.agents[]`

| Campo | Tipo JSON | Nullable | Significado |
|---|---|---:|---|
| `agent` | string | no | Identificador del agente. |
| `points` | integer | no | Puntos acumulados en el ledger. |
| `tasks` | integer | no | Cantidad registrada de tareas. |
| `last` | string | sí | Fecha ISO de última actividad, o `null`. |

Ejemplo:

```json
{
  "agent": "chat",
  "points": 2,
  "tasks": 2,
  "last": "2026-09-30"
}
```

Cuando `ledger.tsv` contiene:

```text
-
```

en la columna `ultima`, el JSON devuelve:

```json
"last": null
```

Nunca:

```json
"last": "-"
```

---

# 5. Mapeo desde `.team/BOARD.md`

El formato actual es:

```markdown
| Tarea | Título | Dueño | Rama | Estado | Abierta |
|-------|--------|-------|------|--------|---------|
| T-002 | ... | `chat` | `chat/...` | abierta | 2026-09-30 |
```

El mapeo es:

| Markdown | JSON |
|---|---|
| `Tarea` | `id` |
| `Título` | `title` |
| `Dueño` | `owner` |
| `Rama` | `branch` |
| `Estado` | `status` |
| `Abierta` | `opened` |

Los backticks Markdown son formato visual y no forman parte del valor.

Por ejemplo:

```markdown
`chat`
```

se serializa como:

```json
"chat"
```

y:

```markdown
`chat/t-002-disena-el-contrato-de-la-api-del-servici`
```

como:

```json
"chat/t-002-disena-el-contrato-de-la-api-del-servici"
```

---

# 6. Estados de tarea

El protocolo actual declara:

```text
abierta
esperando
entregada
integrada
```

`GET /board` no traduce ni interpreta estos estados.

Por ejemplo:

```markdown
esperando
```

se devuelve exactamente como:

```json
"status": "esperando"
```

El servicio tampoco calcula el estado a partir de inbox, outbox, Git o procesos en ejecución.

`BOARD.md` es la fuente de verdad.

---

# 7. Mapeo desde `.team/ledger.tsv`

Formato:

```tsv
agente	puntos	tareas	ultima
chat	2	2	2026-09-30
codex	0	0	-
cc	0	0	-
```

Mapeo:

| TSV | JSON |
|---|---|
| `agente` | `agent` |
| `puntos` | `points` |
| `tareas` | `tasks` |
| `ultima` | `last` |

`points` y `tasks` se convierten a enteros.

Por tanto esto:

```text
chat	2	2	2026-09-30
```

no puede serializarse como:

```json
{
  "agent": "chat",
  "points": "2",
  "tasks": "2"
}
```

Debe ser:

```json
{
  "agent": "chat",
  "points": 2,
  "tasks": 2
}
```

---

# 8. Orden de los elementos

El endpoint conserva el orden de origen.

## Tareas

`board.tasks` mantiene el orden de las filas de `BOARD.md`.

## Agentes

`ledger.agents` mantiene el orden de las filas de `ledger.tsv`.

El servicio no ordena alfabéticamente ni por puntuación.

Esto evita que la UI tenga cambios de posición inesperados y hace deterministas las pruebas.

---

# 9. Tablero sin tareas

Un `BOARD.md` válido sin filas de tareas **no es un error**.

Respuesta:

```json
{
  "board": {
    "tasks": []
  },
  "ledger": {
    "agents": [
      {
        "agent": "chat",
        "points": 0,
        "tasks": 0,
        "last": null
      },
      {
        "agent": "codex",
        "points": 0,
        "tasks": 0,
        "last": null
      },
      {
        "agent": "cc",
        "points": 0,
        "tasks": 0,
        "last": null
      }
    ]
  }
}
```

La inexistencia de tareas y la inexistencia de la pizarra son situaciones diferentes.

---

# 10. Contrato de errores

Todos los errores propios del servicio usan la misma envoltura:

```json
{
  "error": {
    "code": "codigo_estable",
    "message": "Mensaje legible."
  }
}
```

`code` está pensado para lógica de Flutter.

`message` está pensado para mostrar información comprensible o registrar el fallo.

La UI no debe depender del texto exacto de `message`; debe usar `code`.

---

## `401 Unauthorized`

Token local ausente, malformado o incorrecto.

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Token local ausente o inválido."
  }
}
```

Aplica, por ejemplo, a:

```http
GET /board
```

sin cabecera de autenticación.

También a:

```http
Authorization: Bearer token-equivocado
```

---

## `404 Not Found`

El proyecto activo no contiene una pizarra de `duo` utilizable porque falta alguno de los archivos requeridos:

```text
.team/BOARD.md
.team/ledger.tsv
```

Respuesta:

```json
{
  "error": {
    "code": "board_not_found",
    "message": "No se encontró una pizarra de duo en el proyecto activo."
  }
}
```

También se usa si el directorio `.team/` no existe.

No se devuelve un tablero parcial.

Por ejemplo, si existe:

```text
.team/BOARD.md
```

pero falta:

```text
.team/ledger.tsv
```

la respuesta sigue siendo `404 board_not_found`.

---

## `422 Unprocessable Entity`

Los archivos existen, pero no respetan el formato que necesita el servicio.

Respuesta:

```json
{
  "error": {
    "code": "invalid_board",
    "message": "La pizarra de duo tiene un formato inválido."
  }
}
```

Casos incluidos:

- falta una columna requerida en `BOARD.md`;
- una fila del tablero tiene menos columnas;
- `Tarea` está vacía;
- `Dueño` está vacío;
- `Rama` está vacía;
- `Estado` está vacío;
- `Abierta` no contiene una fecha válida;
- `ledger.tsv` no contiene las columnas esperadas;
- `puntos` no puede convertirse a entero;
- `tareas` no puede convertirse a entero;
- `ultima` no es `-` ni una fecha válida.

El mensaje público no debe reproducir la línea completa que provocó el error.

El detalle técnico puede registrarse en logs locales.

---

## `500 Internal Server Error`

Fallo inesperado al leer la pizarra.

```json
{
  "error": {
    "code": "board_read_failed",
    "message": "No se pudo leer la pizarra del proyecto activo."
  }
}
```

Ejemplos:

- error de I/O inesperado;
- archivo inaccesible por permisos;
- lectura interrumpida;
- excepción no contemplada del parser.

La ausencia normal de archivos **no** debe terminar como `500`; es `404`.

Un formato incorrecto **no** debe terminar como `500`; es `422`.

---

# 11. Matriz resumida de estados HTTP

| HTTP | `error.code` | Caso |
|---:|---|---|
| `200` | — | Tablero y ledger válidos. |
| `401` | `unauthorized` | Token local ausente o inválido. |
| `404` | `board_not_found` | Falta `.team/`, `BOARD.md` o `ledger.tsv`. |
| `422` | `invalid_board` | Los archivos existen pero su formato es inválido. |
| `500` | `board_read_failed` | Error inesperado de lectura/procesamiento. |

No se define `403` en v1: el servicio tiene un único token local, no un sistema de permisos por usuario.

---

# 12. Atomicidad lógica de la respuesta

Aunque físicamente se leen dos archivos, la respuesta se considera una sola fotografía lógica.

El servicio debe:

1. leer `BOARD.md`;
2. leer `ledger.tsv`;
3. validar ambos;
4. construir ambos modelos;
5. responder `200` únicamente cuando los dos son válidos.

No se permite:

```json
{
  "board": {
    "tasks": [...]
  },
  "ledger": null
}
```

ni un `200` parcial equivalente.

Si una mitad no se puede obtener o validar, responde el error correspondiente.

---

# 13. Invariantes

1. `GET /board` nunca escribe en `.team/`.
2. No ejecuta `duo`.
3. No ejecuta comandos Git.
4. No consulta GitHub.
5. No deduce tareas desde `.team/inbox/`.
6. No deduce tareas terminadas desde `.team/outbox/`.
7. No reconstruye estados mirando ramas.
8. No recalcula puntos del ledger.
9. No altera el orden presente en los archivos.
10. No inventa agentes faltantes.
11. No inventa campos ausentes.
12. `BOARD.md` es fuente de verdad para tareas.
13. `ledger.tsv` es fuente de verdad para carga de agentes.
14. Una respuesta `200` contiene ambos recursos completos.
15. El endpoint solo está disponible en el servicio local protegido por token.

---

# 14. Qué no debe hacer el parser

No debe intentar ser un parser Markdown genérico.

Para Fase 1 basta con reconocer el contrato concreto producido por `duo`.

Por ejemplo, el comentario:

```html
<!-- duo escribe aquí. Estados: abierta, esperando, entregada, integrada -->
```

no forma parte de ninguna tarea.

Los encabezados:

```markdown
# Tablero
```

tampoco.

El parser consume únicamente las filas de datos de la tabla esperada.

---

# 15. Ejemplo completo

Archivos:

```markdown
# Tablero

| Tarea | Título | Dueño | Rama | Estado | Abierta |
|-------|--------|-------|------|--------|---------|
| T-001 | implementa el servicio | `codex` | `codex/t-001` | entregada | 2026-09-30 |
| T-002 | diseña GET /board | `chat` | `chat/t-002` | abierta | 2026-09-30 |
```

y:

```tsv
agente	puntos	tareas	ultima
chat	2	2	2026-09-30
codex	3	1	2026-09-30
cc	1	1	2026-09-29
```

producen:

```json
{
  "board": {
    "tasks": [
      {
        "id": "T-001",
        "title": "implementa el servicio",
        "owner": "codex",
        "branch": "codex/t-001",
        "status": "entregada",
        "opened": "2026-09-30"
      },
      {
        "id": "T-002",
        "title": "diseña GET /board",
        "owner": "chat",
        "branch": "chat/t-002",
        "status": "abierta",
        "opened": "2026-09-30"
      }
    ]
  },
  "ledger": {
    "agents": [
      {
        "agent": "chat",
        "points": 2,
        "tasks": 2,
        "last": "2026-09-30"
      },
      {
        "agent": "codex",
        "points": 3,
        "tasks": 1,
        "last": "2026-09-30"
      },
      {
        "agent": "cc",
        "points": 1,
        "tasks": 1,
        "last": "2026-09-29"
      }
    ]
  }
}
```

---

# 16. Responsabilidad de Flutter

Flutter recibe este JSON ya normalizado.

Por tanto, Flutter:

- no debe leer `.team/` directamente;
- no debe parsear Markdown;
- no debe parsear TSV;
- no debe convertir `-` a `null`;
- no debe conocer nombres de columnas internas;
- no debe reconstruir estados.

La app consume exclusivamente el contrato JSON del servicio.

Esto conserva la separación definida en `docs/ARQUITECTURA.md`: el servicio C# posee dominio y pizarra; Flutter posee presentación.

---

# 17. Evolución compatible

Se pueden añadir campos en versiones posteriores sin cambiar la semántica de los actuales.

Ejemplos futuros:

```json
{
  "project": {
    "name": "duo-desktop"
  }
}
```

o:

```json
{
  "board": {
    "tasks": [...],
    "counts": {
      "open": 2
    }
  }
}
```

pero Fase 1 no los necesita.

No se deben añadir ahora campos que requieran Git, GitHub, inbox/outbox o ejecución de procesos.

---

# 18. Decisiones tomadas

- `GET /board` devuelve tablero y ledger juntos.
- La respuesta raíz es `{ "board": ..., "ledger": ... }`.
- Las tareas se exponen mediante `board.tasks`.
- Los agentes se exponen mediante `ledger.agents`.
- Los nombres se normalizan a inglés/camelCase para el contrato HTTP, sin obligar a cambiar los archivos internos de `duo`.
- `-` en `ultima` se convierte a `null`.
- Los números del TSV salen como enteros JSON.
- Se conserva el orden de los archivos.
- Una pizarra válida sin tareas responde `200`.
- Falta de archivos responde `404`.
- Formato inválido responde `422`.
- Error inesperado de lectura responde `500`.
- El endpoint no admite respuestas parciales.
- Se fija `Authorization: Bearer <token-local>` como forma concreta de cumplir el requisito arquitectónico existente de un token en cabecera.

# 19. Fuera de alcance

- `POST /tasks`.
- WebSocket.
- Ejecución de `duo`.
- Preguntas y respuestas de agentes.
- Git y GitHub.
- Crear, modificar o cerrar tareas.
- Recalcular el ledger.
- Elegir o cambiar el proyecto activo.
- Leer inbox/outbox como parte del tablero.
- Historial de tareas.
- Paginación.
- Persistencia propia del servicio.
- Cambios al formato de `.team/`.
- Implementación C#.
- Implementación Flutter.

# 20. Qué debe verificar David

1. Confirmar que quiere adoptar `Authorization: Bearer <token-local>` como cabecera concreta. La arquitectura existente exige un token, pero todavía no fija su sintaxis.
2. Confirmar que los nombres JSON en inglés (`tasks`, `owner`, `status`, `agents`, etc.) son los que quiere mantener como API pública entre C# y Flutter.
3. Confirmar que `404` debe cubrir tanto `.team/` inexistente como ausencia individual de `BOARD.md` o `ledger.tsv`.

Fuera de esas decisiones de interfaz, el contrato puede implementarse directamente en la Fase 1.
