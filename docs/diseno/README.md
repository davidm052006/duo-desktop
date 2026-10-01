# Diseños de la interfaz

Referencia visual para la app Flutter. Los agentes pueden leer estas imágenes
directamente desde el repo.

| Archivo | Pantalla |
|---|---|
| `01-inicio-centro-de-control.jpeg` | Inicio: resumen de agentes, tareas, preguntas y actividad del repo |
| `02-tablero-kanban.jpeg` | Tablero en Kanban con inspector de tarea lateral |

## Lo que fijan estos diseños

- **Navegación lateral**: Inicio, Tablero, Tareas, Agentes, Preguntas,
  Terminal, GitHub, Historial, Visualizaciones + Personalización y
  Configuración.
- **Tema oscuro** con acentos en rosa y cian, tipografía monoespaciada para
  datos técnicos (rutas, ramas, hashes) y proporcional para el texto.
- **Columnas del tablero**: En espera, En progreso, Necesita decisión,
  Finalizadas. Coinciden con los estados reales de `duo`
  (`abierta`, `esperando`, `entregada`, `integrada`).
- **Carga de trabajo** por número de tareas, declarando explícitamente que no
  estima tokens ni recursos — igual que el ledger.
- Las acciones que todavía no existen se marcan con su fase (`Fase 2`,
  `Fase 3`) en vez de esconderse.

## Lo que NO fijan

Los textos de ejemplo (`#TASK-104`, `src/middleware/auth.ts`) son relleno del
mockup. Los identificadores reales son `T-NNN` y el proyecto es C# + Dart.
