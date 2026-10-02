# Protocolo del equipo de agentes — duo-desktop

Cuatro agentes trabajan sobre este repo. Esta rama (`team/board`) es la pizarra
compartida: NO contiene código, solo coordinación.

## Agentes y territorios

| Agente  | Dónde trabaja      | Ramas    |
|---------|--------------------|----------|
| `chat`  | GitHub (ChatGPT)   | `chat/*` |
| `grokchat` | GitHub (GrokChat) | `grokchat/*` |
| `codex` | worktree `codex-duo-desktop`| `codex/*`|
| `cc`    | worktree `cc-duo-desktop`   | `cc/*`   |

Regla de oro: **nadie comparte working tree y nadie escribe en `main`**.
Los merges a `main` los autoriza David.

## Reparto por fortaleza

- `chat` — arquitectura, especificaciones, diseño, documentación larga.
  Tareas gruesas y pocos viajes: cada viaje cuesta atención humana.
- `grokchat` — alternativa externa para diseño, investigación y propuestas.
  Puede escribir en GitHub solo si su conector dispone de ese permiso.
- `codex` — implementación acotada, tests, refactors, bugs concretos.
- `cc` — auditorías multiarchivo, diagnóstico, revisión cruzada contra el
  código real, y lo que necesite ejecutarse en esta máquina.

## Ciclo de vida

1. `duo "<lo que quieres>"` — el router asigna por fortaleza y saldo.
2. El brief va a `.team/inbox/<agente>/T-NNN.md`.
3. El agente trabaja **en su rama** y termina con un resumen.
4. `duo` commitea su trabajo y archiva el entregable en `.team/outbox/`.
   Excepción: `chat` y `grokchat` pueden escribir el suyo desde GitHub.
5. `duo review T-NNN` — lo revisa alguien que NO lo hizo.
6. `duo done T-NNN` cierra; `duo clean` archiva (mueve, no borra).

La integración a `main` es siempre un paso aparte y humano.

## Cuando el agente necesita una decisión

Un agente headless no puede preguntar a media tarea. Hace todo lo que no
dependa de la duda y termina con un bloque `## PREGUNTA`. `duo` lo detecta,
deja la tarea en `esperando` y avisa. David responde con `duo ask T-NNN` y
`duo` **reanuda la sesión** del agente con su contexto intacto.

Una duda que el agente pueda resolver con una suposición razonable NO va ahí:
la declara y sigue.
