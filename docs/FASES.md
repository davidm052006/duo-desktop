# Plan por fases

Cada fase termina en algo que funciona y se puede mostrar. Si el proyecto se
detiene en la fase 3, lo hecho sigue sirviendo.

## Fase 1 — El tablero se ve

**Objetivo:** las dos piezas hablándose. Es el 80% de la dificultad
conceptual; el resto es repetir el patrón.

- Servicio: `GET /board` que lee `.team/BOARD.md` y `.team/ledger.tsv` del
  proyecto activo y responde JSON.
- App: tabla de tareas y barras de carga por agente.
- Sin ejecutar nada todavía. Solo lectura.

**Se aprende:** proyecto .NET, minimal API, DI, records, serialización JSON.
En Flutter: `http`, modelos, `FutureBuilder`, layout.

## Fase 2 — Lanzar y ver

- Servicio: `POST /tasks` que ejecuta `duo "<texto>"` y difunde su salida por
  WebSocket.
- App: campo de texto para la tarea y panel de salida en vivo.

**Se aprende:** `Process` y streams en C#, WebSockets a dos bandas,
`StreamBuilder` en Flutter.

## Fase 3 — Preguntas como objetos

- Servicio: detectar `## PREGUNTA`, exponer `GET /questions` y
  `POST /questions/{id}/answer`, que reanuda la sesión del agente.
- App: ventana propia, texto completo, multilínea, con scroll.

**Se aprende:** modelado de dominio, estado en el servidor, diálogos en
Flutter. Y se arregla el problema que tenía `kdialog`: recortaba el texto.

## Fase 4 — GitHub dentro de la app

- Servicio: `Octokit` para ramas, commits y PRs.
- App: ver qué produjo cada agente y abrir un PR sin salir.

**Se aprende:** cliente HTTP con autenticación, paginación, async en serio.

## Fase 5 — Terminal integrada

- `xterm.dart` + `flutter_pty`: correr los agentes dentro de la app.

**Se aprende:** cómo funciona un PTY de verdad.

## Fase 6 — Visualización

- Línea de tiempo de tareas, grafo de quién revisó a quién, reparto en vivo.

Es lo que hace que alguien mire el portafolio dos veces.

## Fase 7 — Lo bonito

Fuentes, colores, temas claro y oscuro, y al final fondos de vídeo
(`video_player`). Va último no por ser menos importante, sino porque es lo
único que no bloquea nada más.

---

## Nota sobre el reparto del trabajo

Este proyecto se construye **con** `duo`. Regla que conviene respetar:

- `chat` (ChatGPT) — diseño de los contratos de la API, modelado del dominio,
  documentación. Tareas gruesas: cada viaje cuesta atención humana.
- `codex` — implementación acotada en C# y Dart, tests.
- `cc` (Claude Code) — auditorías multiarchivo, revisión cruzada, y todo lo
  que haya que compilar o ejecutar aquí.

Nadie revisa su propio trabajo: `duo review T-NNN`.
