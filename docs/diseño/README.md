# Diseños de la interfaz

Referencia visual para la app Flutter. Los agentes pueden leer estas imágenes
directamente desde el repo.

| Archivo | Pantalla |
|---|---|
| `01-inicio-centro-de-control.jpeg` | Inicio: resumen de agentes, tareas, preguntas y actividad del repo |
| `tablero kaban.png` | Tablero en Kanban con inspector de tarea lateral |

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

## Guía para implementar los diseños

Lee esta sección completa antes de modificar la aplicación. Una imagen fija la
intención visual; `docs/FASES.md` y `docs/api/CONTRATO_BOARD.md` fijan qué
capacidades existen realmente.

### Producto y arquitectura

`duo-desktop` es una aplicación de escritorio para coordinar el trabajo de
tres agentes sobre un repositorio local:

- `chat`: contratos, diseño de dominio y documentación.
- `codex`: implementación C#/Dart y pruebas.
- `cc`: auditoría, revisión cruzada y verificación local.

La UI está en `app/` y usa **Flutter desktop para Linux** (Dart). El backend
está en `service/` y usa **ASP.NET Core minimal API con C#/.NET 10**.

```text
Flutter desktop --HTTP/WebSocket--> servicio C# local --> .team/BOARD.md + .team/ledger.tsv
```

Flutter no lee `.team/` directamente: consulta al servicio local. Este escucha
en `127.0.0.1`, usa un puerto efímero y exige
`Authorization: Bearer <token-local>`. La app dispone de `http`,
`web_socket_channel` y `provider`; no añadir dependencias solo por estética.

No convertir Duo en un dashboard ficticio de infraestructura: no hay GPU/VRAM,
CPU, métricas de tokens, PID, locks AST, health porcentual, file watchers ni
telemetría de red que se puedan mostrar como datos reales.

Documentos de autoridad:

- [Arquitectura](../ARQUITECTURA.md)
- [Fases](../FASES.md)
- [Contrato de `GET /board`](../api/CONTRATO_BOARD.md)

Si alguno contradice un mockup, el contrato y las fases prevalecen.

### Qué construyó T-006

`01-inicio-centro-de-control.jpeg` está implementado en
`app/lib/src/pantallas/pantalla_inicio.dart`, dentro del armazón de navegación
`marco_app.dart`. Sus datos provienen de `GET /board`; lo que aún no tiene una
fuente real se marca con su fase, sin rellenarlo con datos de adorno.

- Agentes y tareas se derivan del tablero y del ledger.
- El estado del agente se deduce de sus tareas, no de un proceso CLI; los
  procesos vivos llegan en Fase 2.
- Preguntas reales requieren `GET /questions` en Fase 3.
- La actividad del repositorio y un vigilante de archivos no existen todavía.
- Nueva tarea y terminal se muestran deshabilitadas, con su fase indicada.

El tablero mapea los estados de `duo` así: `abierta` a En progreso,
`entregada` a En espera, `esperando` a Necesita decisión e `integrada` a
Finalizadas. Cada tarjeta debe mantener visible el estado literal para no
ocultar ese mapeo.

### Alcance exacto de Fase 1

La primera entrega es un tablero **de solo lectura**. Flutter solicita:

```http
GET /board
Authorization: Bearer <token-local>
```

La respuesta contiene estos datos y solo estos datos:

```text
board.tasks[]: id, title, owner, branch, status, opened
ledger.agents[]: agent, points, tasks, last
```

En Fase 1 se puede implementar:

- Kanban y filtros a partir de datos reales.
- Tarjetas con ID, título, dueño, rama, estado y fecha de apertura.
- Carga de trabajo por cantidad de tareas del ledger, nunca por recursos o
  tokens.
- Inspector de tarea solo de lectura.
- `Actualizar tablero`, carga, vacío, error y reintento.

Estas capacidades deben quedar ocultas o deshabilitadas con su fase, nunca
simuladas como funcionales:

| Capacidad | Fase |
|---|---:|
| Crear, editar, cerrar, reasignar o arrastrar tareas | 2 |
| Ejecutar `duo`, pausar/reanudar agentes y salida en vivo | 2 |
| Preguntas y respuestas de agentes | 3 |
| GitHub, PRs, diffs y merge | 4 |
| Terminal integrada | 5 |
| Línea de tiempo, grafos y visualizaciones | 6 |

No mostrar preguntas pendientes hasta que exista la API de Fase 3. En los
textos, usar “El servicio local lee `.team/BOARD.md` y `.team/ledger.tsv`”; no
decir que Flutter los lee directamente.

### Implementación visual

- Fondo negro azulado; paneles grafito, bordes y sombras sutiles.
- Magenta para atención/decisión, cian para conexión/progreso y violeta para
  selección.
- Fuente monoespaciada para IDs, ramas, rutas, estados y cifras; texto de
  lectura claro y con contraste suficiente.
- Personalizar Material para que no parezca una app corporativa genérica.

Para el Kanban:

- Las columnas son `En espera`, `En progreso`, `Necesita decisión` y
  `Finalizadas`. Centralizar en código el mapeo desde `status` de `BOARD.md`.
- Cada columna debe tener ancho mínimo; si no caben, usar desplazamiento
  horizontal. No estrechar tarjetas hasta truncar títulos.
- El inspector debe ser un drawer/modal superpuesto, cerrable, con ancho
  máximo aproximado de 420 px. No puede cubrir parcialmente las columnas.
- La tarjeta seleccionada puede tener un borde luminoso animado lento. Usarlo
  solo para selección, foco o actualización nueva, nunca en todas a la vez.
  Dejar preparada una preferencia futura para reducir movimiento.
- `Actualizar tablero` es la acción correcta. No usar “Sincronizar” para una
  simple consulta HTTP, pues sugiere Git/GitHub.

### Forma de trabajo esperada

1. Inspeccionar `app/lib/` y el contrato antes de editar; preservar cambios
   ajenos del worktree.
2. Crear modelos Dart tipados para el JSON. No propagar `Map<String, dynamic>`
   por los widgets.
3. Aislar URL, token, HTTP y parseo en un cliente/repositorio; la UI no debe
   construir cabeceras ni parsear JSON.
4. Separar componentes: navegación, tarjeta, encabezado de columna, chip de
   agente, panel vacío, panel de error e inspector.
5. Implementar primero datos reales y todos los estados de error; después el
   acabado visual. Ningún dato ficticio del mockup debe llegar a producción.
6. Verificar `flutter analyze`, las pruebas existentes y una compilación Linux
   antes de entregar.

### Criterios de aceptación

- `GET /board` válido se presenta como tablero y carga de trabajo.
- Cargando, 401, 404, 422 y 500 son claros y recuperables cuando corresponda.
- Los títulos largos permanecen legibles y el inspector no tapa tarjetas.
- Ninguna característica de una fase futura parece ya disponible.
- La implementación conserva la identidad visual de los mockups sin copiar
  sus valores ficticios.


### Fondos de vídeo (T-023)

La personalización de fondo puede usar una carpeta local de vídeos. La app:

- persiste la carpeta y el intervalo de rotación;
- enumera candidatos `.mp4`, `.m4v`, `.mov`, `.webm` y `.mkv`;
- elige un vídeo aleatorio al iniciar y cuando vence el intervalo;
- no selecciona ni rota vídeos si el modo de fondo es `ninguno` o `degradado`;
- reproduce el vídeo detrás de `MarcoApp` con `media_kit`;
- arranca siempre muteado y sin controles;
- mantiene un único reproductor activo;
- libera el `Player` cuando cambia el widget o se cierra la app;
- si un archivo falla al abrir o decodificar, lo marca como fallido durante esa sesión y prueba otro candidato.

Dependencias multimedia:

```yaml
media_kit: ^1.2.6
media_kit_video: ^2.0.1
media_kit_libs_video: ^1.0.7
```

`MediaKit.ensureInitialized()` se ejecuta antes de `runApp`.

#### Linux

El render usa el backend de `media_kit`/libmpv. La disponibilidad real de codecs depende del sistema y de libmpv. En Debian/Ubuntu, la documentación de media_kit indica instalar:

```bash
sudo apt install libmpv-dev mpv
```

No se debe asumir que una extensión válida implica que el codec interno sea reproducible; por eso la app escucha errores del reproductor y salta al siguiente archivo.

#### Opacidad de superficies

La preferencia de opacidad se limita a 72–98%. Se aplica al color `panel` del tema, no al árbol completo con `Opacity`. Así texto, iconos y bordes mantienen opacidad completa y contraste mientras las cards, barras y paneles dejan ver el fondo.


#### Persistencia en Linux

Antes de la primera lectura, `main.dart` registra explícitamente:

```dart
PathProviderLinux.registerWith();
SharedPreferencesLinux.registerWith();
```

Las dependencias `path_provider_linux` y `shared_preferences_linux` son directas en `pubspec.yaml`.

Al arrancar, Duo Desktop:

1. obtiene el application support path Linux;
2. crea el directorio si no existe;
3. escribe una clave de bootstrap;
4. ejecuta `reload()`;
5. relee esa clave;
6. comprueba que existe `shared_preferences.json`.

Con la configuración XDG por defecto de Linux, este archivo vive bajo `~/.local/share/<application-id>/shared_preferences.json`. Si `XDG_DATA_HOME` está definido, se respeta ese directorio.

Cada escritura de modo de fondo, carpeta, intervalo y opacidad comprueba el `bool` devuelto por `SharedPreferences`. Un `false` se considera fallo real: la UI muestra el error y no marca la preferencia como persistida. El cambio de modo se notifica a `MarcoApp` únicamente después de que la escritura haya tenido éxito.
