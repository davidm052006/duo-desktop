# T-010 — Entregable chat

## Estado

Implementado directamente en la rama:

`chat/t-010-implementa-las-vistas-personalizacion-y-`

Base: `main`. No se escribió en `main`.

## Alcance mínimo

Cambios limitados a la UI Flutter necesaria para hacer utilizables las vistas de Personalización y Configuración:

- `app/lib/src/pantallas/pantalla_personalizacion.dart`
- `app/lib/src/pantallas/pantalla_configuracion.dart`
- `app/lib/src/pantallas/marco_app.dart` — únicamente para habilitar las dos vistas en navegación.
- `app/pubspec.yaml` — únicamente para añadir `shared_preferences`.

No se añadió backend ni se cambió el contrato HTTP.

## Implementación

### Personalización

- Selector de tema claro/oscuro.
- Selector de acento: rosa, morado, cian y azul cielo.
- Escala tipográfica de 85% a 130%.
- Selector de fondo: ninguno, degradado, imagen o vídeo.
- Vista previa coherente con el diseño oscuro rosa/cian.
- Persistencia local mediante `shared_preferences`.

Claves:

- `personalizacion.tema`
- `personalizacion.acento`
- `personalizacion.escala_texto`
- `personalizacion.fondo`

### Configuración

- Proyecto activo leído desde `EstadoTablero`.
- Repo y ruta de la pizarra.
- Host y puerto reales del servicio local desde `ConfigDuo.desdeEntorno`.
- Estado real de conexión usando el estado actual del tablero.
- Rutas configurables de duo y de su configuración.
- Persistencia local mediante `shared_preferences`.

Claves:

- `config.ruta_duo`
- `config.ruta_config_duo`

Las rutas guardadas son preferencias de la UI; no reconfiguran el backend en ejecución.

## Navegación

Personalización y Configuración dejan de aparecer como destinos de Fase 7 deshabilitados y pasan a ser destinos navegables.

## Dependencia

Añadido:

`shared_preferences: ^2.5.3`

a `app/pubspec.yaml`.

## Commits

- `df8169b` feat(ui): implementa vista de personalización
- `7c28b89` feat(ui): implementa vista de configuración
- `43d4dd3` chore(app): añade shared_preferences
- `9155859` feat(nav): habilita personalización y configuración
- `4e8acc8` fix(ui): ajusta tipo de escala tipográfica

Todos incluyen:

`Tarea: T-010`
`Agente: chat`

## Validación

Comparación GitHub contra `main`:

- rama ahead por 5 commits
- behind por 0 commits
- 4 archivos modificados
- no hay cambios en backend

No pude ejecutar `flutter analyze` desde el conector de GitHub porque este canal permite modificar el repositorio pero no ejecutar el worktree local. Al recoger/integrar, ejecutar:

`cd app && flutter pub get && flutter analyze`

y abrir la app Linux para comprobar ambas vistas.

## Nota

Las preferencias visuales quedan persistidas. Aplicarlas globalmente en tiempo real a `MaterialApp` (tema/acento/escala/fondo de toda la aplicación) requiere un controlador global de apariencia, que queda fuera del alcance mínimo de estas dos vistas y no se fingió dentro de T-010.
