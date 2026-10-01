# duo-desktop

> Una interfaz de escritorio para coordinar **ChatGPT, Codex y Claude Code sobre el mismo repositorio sin que se pisen entre sí**.

duo-desktop es la cara gráfica de `duo`: un flujo de trabajo donde varios agentes de IA reciben tareas separadas, trabajan en ramas distintas y dejan trazabilidad en Git.

El proyecto nace de un problema muy concreto: usar varios agentes en paralelo es útil, pero enseguida se vuelve difícil saber **quién está haciendo qué, en qué rama está trabajando, qué necesita una decisión humana y qué ya está listo para revisar**.

duo-desktop intenta convertir ese caos en un workspace visible y verificable.

> **Estado:** proyecto en desarrollo activo. Algunas vistas ya son funcionales; otras muestran información parcial o una demo explícita porque sus fases de backend todavía no están completas.

---

## Capturas

> **[CAPTURA PENDIENTE — Inicio / Centro de control]**  
> Colocar aquí una captura de `docs/diseño/01-inicio-centro-de-control` o de la aplicación real.

> **[CAPTURA PENDIENTE — Tablero Kanban]**  
> Colocar aquí una captura de `docs/diseño/02-tablero-kanban` o de la aplicación real.

> **[CAPTURA PENDIENTE — Terminal / GitHub / Visualizaciones]**  
> Añadir cuando esas vistas estén listas para mostrarse como portafolio.

---

## El problema que resuelve

El flujo de `duo` reparte trabajo entre tres agentes:

- **ChatGPT web** — diseño, contratos, documentación y tareas de razonamiento.
- **Codex CLI** — implementación acotada, especialmente código y pruebas.
- **Claude Code** — revisión cruzada, auditorías multiarchivo y validaciones.

Cada agente trabaja en su propia rama o worktree. Eso evita que dos agentes modifiquen la misma copia de trabajo a la vez, pero introduce otro problema: hay que seguir tareas, ramas, estados, preguntas, carga y entregables.

duo-desktop reúne esa información en una aplicación Linux de escritorio y mantiene una regla importante:

**la UI no inventa estado.** Si el servicio todavía no sabe algo, la pantalla lo dice.

---

## Arquitectura

```text
┌───────────────────────────┐       HTTP / WebSocket       ┌────────────────────────────┐
│       Flutter Desktop     │ ◄──────────────────────────► │   Servicio local C#/.NET   │
│                           │                              │                            │
│ UI, Kanban, gráficas,     │                              │ dominio, .team, Git,       │
│ temas, diálogos, terminal │                              │ GitHub y procesos          │
└───────────────────────────┘                              └────────────────────────────┘
                                                                    │
                                                                    ▼
                                                           duo + repositorio local
```

### Flutter

Flutter se encarga de todo lo visual:

- navegación;
- tablero Kanban;
- formularios y diálogos;
- visualizaciones;
- personalización;
- terminal renderizada;
- estados de carga y errores.

Se eligió Flutter porque permite construir una interfaz de escritorio rica sin mezclar la presentación con el dominio.

### C# / .NET 10

El servicio local usa ASP.NET Core Minimal API y posee la lógica que no debería vivir en Flutter:

- lectura de `.team/BOARD.md` y `.team/ledger.tsv`;
- acceso a Git y GitHub;
- descubrimiento del proyecto activo;
- ejecución futura de `duo` y agentes;
- streaming de eventos.

La separación también tiene un objetivo de aprendizaje: **C# concentra dominio e infraestructura; Flutter concentra UX**.

### Comunicación local

La app y el servicio se comunican en `127.0.0.1`.

El servicio recibe:

- un puerto local;
- un token efímero;
- peticiones autenticadas con `Authorization: Bearer <token>`.

La intención arquitectónica es que Flutter lance el servicio como proceso hijo. En desarrollo, `scripts/dev.fish` levanta ambos procesos juntos.

Más detalles: [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

---

## Las 11 vistas

| Vista | Qué muestra | Estado actual |
|---|---|---|
| **Inicio** | Centro de control con resumen de agentes, tareas, carga y actividad del tablero. | Funcional sobre `GET /board`. |
| **Tablero** | Kanban por estado con tarjetas de tarea y modo de inspección. | Funcional en solo lectura; acciones de edición todavía no. |
| **Tareas** | Lista completa con filtros por agente y estado. | Funcional sobre `GET /board`. |
| **Agentes** | Carga, actividad y tareas abiertas por agente. | Funcional con los datos disponibles en tablero/ledger. |
| **Preguntas** | Tareas detenidas esperando decisión humana. | Parcial: hoy detecta estado `esperando`; el contenido completo de preguntas requiere la Fase 3. |
| **Terminal** | Salida por agente con estética de terminal. | **Demo explícita**; PTY y ejecución real llegan en Fase 5. |
| **GitHub** | Ramas por agente y pull requests. | UI implementada; consume `GET /github` y muestra vacío/error honesto cuando no hay datos. |
| **Historial** | Línea de tiempo construida con la información temporal disponible. | Funcional, pero no reconstruye eventos que el backend todavía no registra. |
| **Visualizaciones** | Gráficas de reparto, estados y actividad derivadas del tablero. | Funcional para métricas que `GET /board` puede sostener; visualizaciones futuras necesitarán más fuentes. |
| **Personalización** | Tema, acento, escala tipográfica y preferencia de fondo. | Preferencias locales implementadas; parte de su aplicación global sigue en evolución. |
| **Configuración** | Proyecto activo, rutas locales y estado del servicio. | Funcional como vista/configuración local; no reconfigura mágicamente un proceso ya iniciado. |

---

## Estado por fases

El plan original está documentado en [docs/FASES.md](docs/FASES.md). La implementación ha avanzado de forma incremental y algunas pantallas de fases posteriores ya existen antes de que toda la infraestructura de su fase esté cerrada.

### Fase 1 — El tablero se ve

**Objetivo:** conectar Flutter con el servicio local y mostrar la fuente de verdad de `duo`.

Estado actual:

- `GET /board` implementado;
- lectura de `.team/BOARD.md` y `.team/ledger.tsv`;
- autenticación local con Bearer token;
- Inicio, Tareas, Agentes y Kanban consumen estos datos;
- refresco periódico desde Flutter.

**Estado: funcional.**

### Fase 2 — Lanzar y ver

Plan:

- `POST /tasks`;
- ejecución de `duo "<texto>"`;
- WebSocket con salida en vivo;
- creación de tareas desde la app.

En la UI ya existe trabajo adelantado para crear tareas, pero la fase solo puede considerarse completa cuando el backend de escritura y el streaming estén integrados y probados de extremo a extremo.

**Estado: en progreso.**

### Fase 3 — Preguntas como objetos

Plan:

- detectar `## PREGUNTA`;
- `GET /questions`;
- `POST /questions/{id}/answer`;
- reanudar al agente desde la interfaz.

La vista Preguntas existe, pero con `GET /board` solo puede identificar tareas en estado `esperando`.

**Estado: parcial.**

### Fase 4 — GitHub dentro de la app

Plan:

- ramas;
- commits;
- pull requests;
- acciones GitHub desde el workspace.

El servicio actual ya expone `GET /github` y la app tiene una vista dedicada. Aun así, las acciones de escritura y el flujo completo de PR no deben darse por terminados hasta probarse de extremo a extremo.

**Estado: parcialmente implementada.**

### Fase 5 — Terminal integrada

Plan:

- PTY real;
- `xterm.dart`;
- `flutter_pty`;
- ejecución interactiva de agentes.

La vista actual muestra una demo claramente etiquetada y no pretende ser una terminal real.

**Estado: pendiente.**

### Fase 6 — Visualización

Plan:

- línea de tiempo;
- grafo de revisiones;
- reparto de trabajo en vivo.

Ya existen visualizaciones derivadas de los datos actuales, pero un grafo real de revisiones y actividad en vivo necesita fuentes adicionales.

**Estado: parcial.**

### Fase 7 — Personalización

Plan:

- temas;
- colores;
- tipografía;
- fondos;
- fondos de vídeo.

Las pantallas de Personalización y Configuración ya existen y guardan preferencias locales. La integración completa de todas ellas a nivel global continúa evolucionando.

**Estado: parcial.**

---

## Endpoints actuales del servicio

En la rama principal actual, el servicio expone:

```text
GET /health
GET /board
GET /history
GET /github
```

Todos los endpoints protegidos usan el mismo token local.

Los endpoints de escritura y WebSocket forman parte de fases posteriores y no deben asumirse como disponibles hasta que estén integrados en `main`.

---

## Requisitos

El flujo de desarrollo actual está orientado a Linux.

Necesitas:

- .NET SDK compatible con **.NET 10**;
- Flutter con Linux desktop habilitado;
- CMake;
- Ninja;
- Fish shell para los scripts incluidos;
- Git;
- `duo` instalado y utilizable en el entorno local.

El script de bootstrap comprueba las herramientas principales.

En Arch/derivadas, el propio script sugiere:

```bash
sudo pacman -S dotnet-sdk cmake ninja
```

Flutter debe instalarse según la distribución y su documentación oficial.

---

## Instalación

Clona el repositorio:

```bash
git clone https://github.com/davidm052006/duo-desktop.git
cd duo-desktop
```

Prepara los proyectos y dependencias:

```fish
scripts/bootstrap.fish
```

El script es idempotente: si `service/` y `app/` ya existen, no los recrea.

También:

- habilita Flutter Linux desktop;
- verifica herramientas;
- asegura dependencias del servicio;
- comprueba dependencias base de Flutter;
- intenta compilar servicio y app.

---

## Arrancar en desarrollo

Desde la raíz del repositorio:

```fish
scripts/dev.fish
```

El script:

1. muestra **qué rama/worktree estás ejecutando**;
2. avisa si existen ramas de agentes con trabajo que no estás viendo;
3. genera un puerto efímero;
4. genera un token local;
5. inicia el servicio C#;
6. inicia Flutter Linux con el mismo puerto y token;
7. detiene el servicio al cerrar.

Esto evita un error fácil de cometer al trabajar con varios agentes: levantar la app desde `main` y pensar que estás viendo los cambios de una rama de agente.

Para validar manualmente el proyecto:

```bash
dotnet build service
cd app
flutter analyze
flutter build linux --debug
```

---

## Trabajar con ramas de agentes

El proyecto se construye usando su propio flujo de coordinación.

Ejemplo conceptual:

```text
main
├── chat/t-...
├── codex/t-...
└── cc/t-...
```

Cada tarea vive fuera de `main` hasta ser revisada e integrada.

Para revisar visualmente una tarea de Flutter, ejecuta la aplicación **desde el worktree de esa tarea**, no desde `main`.

```bash
pwd
git branch --show-current
scripts/dev.fish
```

---

## Principios del proyecto

### No inventar datos

Si el backend no proporciona una métrica, la UI no la fabrica.

Por ejemplo:

- una tarea en `esperando` no contiene automáticamente el texto de la pregunta;
- una fecha de apertura no equivale a un historial completo;
- una vista de terminal demo no es una terminal real;
- una preferencia guardada no significa que toda la app ya se reconfigure en caliente.

### Separar UI de dominio

Flutter presenta. C# conoce el proyecto, Git, GitHub, procesos y `.team`.

### Mantener trazabilidad

Las tareas, ramas y entregables permiten saber qué agente produjo cada cambio y facilitan la revisión cruzada.

---

## Diseño

La dirección visual usa:

- interfaz oscura;
- rosa y cian como acentos;
- colores de serie separados para agentes;
- tipografía monoespaciada para IDs, ramas y datos técnicos;
- paneles densos pero legibles;
- diseño pensado para escritorio.

Los mockups de referencia viven en `docs/diseño/`.

> **[CAPTURA PENDIENTE — detalle del Kanban + inspector]**

---

## Estructura del repositorio

```text
duo-desktop/
├── app/                 # Flutter desktop
├── service/             # ASP.NET Core / .NET
├── docs/                # arquitectura, fases, API y diseño
├── scripts/
│   ├── bootstrap.fish
│   └── dev.fish
└── README.md
```

---

## Lo que todavía no debe venderse como terminado

Para mantener este README útil como portafolio y no como marketing ficticio:

- la terminal PTY real todavía no está terminada;
- el streaming WebSocket completo sigue siendo trabajo de Fase 2/5;
- el sistema de preguntas/respuestas necesita sus endpoints dedicados;
- las acciones GitHub de escritura no están cerradas de extremo a extremo;
- fondos de vídeo y personalización global completa siguen pendientes;
- varias vistas actuales son deliberadamente de solo lectura.

---

## Objetivo del proyecto

duo-desktop no busca ser solo “otra interfaz bonita para IA”.

El objetivo es explorar cómo coordinar agentes diferentes sobre un repositorio real manteniendo:

- aislamiento de trabajo;
- trazabilidad;
- revisión humana;
- estados visibles;
- límites claros entre UI, dominio y automatización.

Y hacerlo mientras el propio proyecto se construye con esos agentes.

---

## Licencia

MIT.
