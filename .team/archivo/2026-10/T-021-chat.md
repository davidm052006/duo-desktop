# T-021 — Entregable chat

## Estado

Implementado en:

`chat/t-021-implementa-las-acciones-de-la-vista-gith`

Base: `main`. No se escribió en `main`.

## Alcance mínimo

Cambios limitados a:

- `app/lib/src/pantallas/pantalla_github.dart`
- `app/lib/src/datos/cliente_duo.dart`
- `docs/api/CONTRATO_GITHUB.md`

No se modificó el servicio C#.

## Acciones GitHub en Flutter

La vista GitHub ahora:

- relaciona las ramas devueltas por `GET /github` con las tareas de `GET /board` usando el nombre de rama;
- muestra el ID de tarea cuando existe correspondencia;
- habilita `Publicar` y `Abrir PR` solo para ramas asociadas a una tarea conocida;
- pide confirmación antes de ambas operaciones;
- deshabilita temporalmente las acciones mientras una tarea está en operación;
- tras éxito refresca `GET /github`;
- no inventa éxito si falla el servicio.

## Cliente HTTP

Se añadieron:

- `ClienteDuo.publicarRama(taskId)` → `POST /github/push`
- `ClienteDuo.abrirPullRequest(taskId)` → `POST /github/pr`

Payload de ambos:

```json
{
  "taskId": "T-021"
}
```

Usan:

- `Authorization: Bearer`;
- `Content-Type: application/json`;
- timeout existente del cliente;
- la envoltura `error.code` / `error.message` cuando está disponible.

Ante error, la vista muestra el mensaje recibido y la alternativa manual:

`duo pr T-NNN`

Un 404 del endpoint no se convierte en éxito.

## Contrato

Se añadió `docs/api/CONTRATO_GITHUB.md` con el contrato de:

- `POST /github/push`
- `POST /github/pr`

Decisiones principales:

- Flutter envía solo `taskId`;
- el servicio resuelve rama, repo, remoto y base;
- v1 usa remoto `origin`;
- no hay force push;
- PR existente no se duplica;
- `POST /github/pr` puede responder `409 branch_not_published`;
- errores usan la envoltura común;
- credenciales GitHub nunca viajan desde Flutter;
- tras éxito Flutter vuelve a leer `GET /github`.

## Commits

- `07958c6` feat(api): añade acciones GitHub de escritura
- `1e699f4` feat(ui): añade acciones publicar rama y abrir PR
- `8921564` docs(api): define acciones GitHub de escritura

Todos incluyen:

`Tarea: T-021`
`Agente: chat`

## Validación

Comparación contra `main`:

- ahead: 3
- behind: 0
- 3 archivos modificados

No se pudo ejecutar el worktree local desde el conector GitHub. Verificar en la rama:

`cd app && flutter analyze`

y abrir la app Linux para comprobar:

1. ramas sin tarea asociada no permiten acciones;
2. Publicar pide confirmación;
3. Abrir PR pide confirmación;
4. cancelar no hace ninguna petición;
5. 404/error muestra el mensaje y `duo pr T-NNN`;
6. 2xx refresca la lista de GitHub.
