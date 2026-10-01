# T-013 — Entregable chat

## Estado

Implementado directamente en la rama:

`chat/t-013-implementa-las-vistas-terminal-y-github-`

Base: `main`. No se escribió en `main`.

## Alcance mínimo

Cambios limitados a:

- `app/lib/src/pantallas/pantalla_terminal.dart`
- `app/lib/src/pantallas/pantalla_github.dart`
- `app/lib/src/pantallas/marco_app.dart` únicamente para habilitar navegación a ambas vistas.

No se modificó backend ni se inventó un contrato nuevo de servicio.

## Terminal

- Vista con estética de terminal oscura.
- Scroll vertical.
- Salida diferenciada por agente usando la paleta existente.
- Datos de ejemplo claramente marcados como `DEMO` / `ejemplo`.
- Aviso explícito de que PTY, ejecución real y streaming llegan en Fase 5.
- Texto seleccionable en la salida.

## GitHub

- Consulta `GET /github` usando el mismo token Bearer y configuración local de la app.
- Lista de ramas por agente.
- Lista de pull requests.
- Refresco manual.
- Estado vacío honesto si el endpoint todavía no existe (404/501), si responde sin datos o si el servicio local no está disponible.
- Parser tolerante a `pullRequests`, `pull_requests` o `prs` mientras Codex termina el endpoint.
- No se muestran ramas/PRs inventados.

## Navegación

- Terminal deja de estar bloqueada como destino de Fase 5.
- GitHub deja de estar bloqueado como destino de Fase 4.
- Las dos vistas son navegables desde la barra lateral.

## Commits

- `285bf4d` feat(ui): implementa vista de terminal
- `2c49668` feat(ui): implementa vista de GitHub
- `68f28be` feat(nav): habilita Terminal y GitHub
- `7250674` fix(ui): evita scrollbar sin controlador

Todos incluyen:

`Tarea: T-013`
`Agente: chat`

## Validación

Comparación contra `main`:

- ahead por 4 commits
- behind por 0 commits
- 3 archivos modificados

No se pudo ejecutar `flutter analyze` desde el conector remoto de GitHub. En el worktree de la rama ejecutar:

`cd app && flutter analyze`

y luego abrir la app Linux desde esta rama para revisar ambas vistas.

## Coordinación con Codex

El contrato de `GET /github` todavía no está publicado en `main` ni en una rama visible del remoto. La vista se diseñó para degradar de forma honesta mientras Codex termina el endpoint y para tolerar nombres comunes de la colección de PRs sin fingir datos.
