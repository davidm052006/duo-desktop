# Contrato API — acciones GitHub

Estado: **diseño de contrato v1**.

Este documento define dos operaciones de escritura del servicio local:

- `POST /github/push`: publicar en `origin` la rama asociada a una tarea.
- `POST /github/pr`: abrir el pull request de una tarea.

La lectura de ramas y pull requests sigue viviendo en `GET /github`.

---

## 1. Principios

Estas operaciones salen de la máquina local hacia GitHub, por lo que:

1. requieren la misma autenticación Bearer que el resto del servicio;
2. Flutter debe pedir confirmación humana antes de llamarlas;
3. el servicio recibe un **ID de tarea**, no una rama arbitraria;
4. el servicio resuelve la rama real desde la fuente de verdad de `duo`;
5. un fallo nunca se convierte en éxito visual;
6. las respuestas de error usan la envoltura común de la API.

La UI puede ofrecer `duo pr T-NNN` como alternativa manual si el endpoint todavía no está implementado o falla.

---

# 2. Autenticación

Ambos endpoints requieren:

```http
Authorization: Bearer <token-local>
Content-Type: application/json
Accept: application/json
```

Token ausente o inválido:

```http
401 Unauthorized
```

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Token local ausente o inválido."
  }
}
```

---

# 3. Identificación de la tarea

El request usa:

```json
{
  "taskId": "T-021"
}
```

El cliente **no envía**:

- nombre de rama;
- remoto;
- owner;
- repo;
- base branch;
- credenciales GitHub.

El servicio debe resolver esos datos a partir del proyecto activo, `.team/BOARD.md`, Git y la configuración del repositorio.

Esto evita que la UI convierta el endpoint en un push arbitrario.

---

# 4. `POST /github/push`

## Objetivo

Publicar en `origin` la rama registrada para una tarea.

Ejemplo:

```http
POST /github/push HTTP/1.1
Host: 127.0.0.1:54321
Authorization: Bearer <token>
Content-Type: application/json

{
  "taskId": "T-021"
}
```

## Validación

`taskId`:

- es obligatorio;
- debe ser string no vacío;
- debe identificar una tarea existente en el tablero;
- la tarea debe tener una rama válida.

No se acepta una rama proporcionada directamente por el cliente.

---

## Respuesta `200 OK`

Forma exacta:

```json
{
  "taskId": "T-021",
  "branch": "chat/t-021-implementa-las-acciones-de-la-vista-gith",
  "remote": "origin",
  "pushed": true
}
```

Campos:

| Campo | Tipo | Significado |
|---|---|---|
| `taskId` | string | tarea solicitada |
| `branch` | string | rama realmente publicada |
| `remote` | string | remoto usado; v1 fija `origin` |
| `pushed` | boolean | `true` cuando la operación terminó correctamente |

El servicio no devuelve `200` antes de saber que el push terminó sin error.

---

# 5. Semántica de push

El servicio debe publicar la rama asociada a la tarea en el remoto `origin`.

Una implementación v1 puede equivaler conceptualmente a:

```text
git push -u origin <rama-de-la-tarea>
```

pero el contrato no obliga a usar Git CLI; puede usarse LibGit2Sharp u otra implementación.

La operación debe ser idempotente en el sentido práctico:

- si la rama remota ya está actualizada, responde `200`;
- si hay nuevos commits locales, los publica;
- no fuerza el historial;
- no ejecuta force push.

`--force` y `--force-with-lease` están fuera de alcance.

---

# 6. `POST /github/pr`

## Objetivo

Abrir el pull request correspondiente a una tarea.

Request:

```http
POST /github/pr HTTP/1.1
Host: 127.0.0.1:54321
Authorization: Bearer <token>
Content-Type: application/json

{
  "taskId": "T-021"
}
```

El servicio resuelve:

- rama head desde la tarea;
- repositorio desde `origin`;
- rama base desde la configuración/repo activo;
- título a partir de la tarea.

---

## Respuesta `200 OK`

Forma exacta:

```json
{
  "taskId": "T-021",
  "number": 37,
  "title": "T-021 — implementa las acciones de la vista GitHub",
  "head": "chat/t-021-implementa-las-acciones-de-la-vista-gith",
  "base": "main",
  "url": "https://github.com/davidm052006/duo-desktop/pull/37",
  "created": true
}
```

Campos:

| Campo | Tipo | Significado |
|---|---|---|
| `taskId` | string | tarea |
| `number` | integer | número del PR |
| `title` | string | título real del PR |
| `head` | string | rama de la tarea |
| `base` | string | rama base real |
| `url` | string | URL HTTPS del pull request |
| `created` | boolean | `true` si se creó en esta llamada; `false` si ya existía |

---

# 7. PR ya existente

La operación debe ser idempotente.

Si ya existe un pull request abierto con la misma rama head hacia la misma base, no debe crear un duplicado.

Debe responder `200 OK` con los datos del PR existente:

```json
{
  "taskId": "T-021",
  "number": 37,
  "title": "T-021 — implementa las acciones de la vista GitHub",
  "head": "chat/t-021-implementa-las-acciones-de-la-vista-gith",
  "base": "main",
  "url": "https://github.com/davidm052006/duo-desktop/pull/37",
  "created": false
}
```

---

# 8. Relación entre push y PR

`POST /github/pr` puede exigir que la rama ya exista en GitHub.

Si la rama todavía no está publicada, el endpoint **no debe fingir** que el PR fue creado.

En v1 se recomienda responder:

```http
409 Conflict
```

```json
{
  "error": {
    "code": "branch_not_published",
    "message": "La rama de la tarea todavía no está publicada en GitHub."
  }
}
```

Flutter puede entonces mantener disponible la acción **Publicar**.

El contrato no obliga a `POST /github/pr` a hacer un push implícito.

---

# 9. Errores comunes

Todos usan:

```json
{
  "error": {
    "code": "codigo_estable",
    "message": "Mensaje legible."
  }
}
```

## `422 invalid_request`

Request ausente o `taskId` vacío:

```json
{
  "error": {
    "code": "invalid_request",
    "message": "El identificador de la tarea es obligatorio."
  }
}
```

## `404 task_not_found`

La tarea no existe:

```json
{
  "error": {
    "code": "task_not_found",
    "message": "No se encontró la tarea T-999 en el proyecto activo."
  }
}
```

## `404 repository_not_found`

No hay repositorio Git/GitHub válido:

```json
{
  "error": {
    "code": "repository_not_found",
    "message": "No se encontró un repositorio GitHub válido para el proyecto activo."
  }
}
```

## `409 branch_not_published`

Se intenta abrir un PR antes de publicar la rama:

```json
{
  "error": {
    "code": "branch_not_published",
    "message": "La rama de la tarea todavía no está publicada en GitHub."
  }
}
```

## `409 git_conflict`

La operación Git no puede completarse sin intervención:

```json
{
  "error": {
    "code": "git_conflict",
    "message": "La rama no puede publicarse automáticamente en su estado actual."
  }
}
```

## `502 github_failed`

GitHub rechazó o no pudo completar la operación:

```json
{
  "error": {
    "code": "github_failed",
    "message": "GitHub no pudo completar la operación solicitada."
  }
}
```

## `500 github_operation_failed`

Fallo inesperado local:

```json
{
  "error": {
    "code": "github_operation_failed",
    "message": "No se pudo completar la operación GitHub."
  }
}
```

---

# 10. Endpoint aún no implementado

Mientras el servicio no implemente estas rutas, ASP.NET puede responder simplemente:

```http
404 Not Found
```

La app Flutter debe:

1. mostrar el error real recibido;
2. no mostrar confirmación de éxito;
3. mantener el estado anterior;
4. ofrecer como alternativa manual:

```text
duo pr T-NNN
```

Ejemplo:

```text
duo pr T-021
```

La alternativa manual no significa que el POST haya funcionado.

---

# 11. Confirmación en Flutter

Antes de cualquiera de estas llamadas, Flutter debe pedir confirmación explícita.

Para push debe comunicar al menos:

- tarea;
- rama;
- que se modificará el remoto GitHub.

Para PR debe comunicar al menos:

- tarea;
- rama head;
- que se abrirá una entidad pública/remota en GitHub.

Cancelar el diálogo significa que **no se envía la petición HTTP**.

---

# 12. Seguridad

El servicio:

- escucha solo en `127.0.0.1`;
- exige Bearer token;
- obtiene credenciales GitHub de su entorno/configuración;
- nunca recibe tokens GitHub en el body desde Flutter;
- nunca devuelve secretos en la respuesta;
- no permite especificar un remoto arbitrario desde la UI;
- no permite especificar una rama arbitraria desde la UI.

---

# 13. Consistencia con `GET /github`

Después de un `200` de push o PR, Flutter debe volver a consultar:

```http
GET /github
```

Así la pantalla muestra el estado observado por el servicio, no un estado inventado localmente.

Después de crear un PR, la lista visible debe provenir de ese nuevo `GET /github`.

---

# 14. Invariantes

1. Las dos operaciones requieren confirmación en UI.
2. Ambas reciben únicamente `taskId` como identidad funcional.
3. La rama se resuelve en el servicio.
4. El remoto v1 es `origin`.
5. No existe force push.
6. Un PR existente no se duplica.
7. El servicio no devuelve éxito antes de completar la operación.
8. Los errores conservan la envoltura común.
9. Flutter refresca `GET /github` tras éxito.
10. Un 404 nunca se convierte en éxito simulado.
11. Las credenciales GitHub nunca viajan desde Flutter.
12. El comando `duo pr T-NNN` es alternativa manual, no fallback automático.

---

# 15. Fuera de alcance v1

- force push;
- elegir remoto;
- elegir base desde Flutter;
- editar título/cuerpo del PR desde Flutter;
- merge de PR;
- cerrar/reabrir PR;
- borrar ramas remotas;
- resolver conflictos;
- enviar credenciales GitHub por la API;
- operar sobre una rama que no pertenezca a una tarea de `duo`.
