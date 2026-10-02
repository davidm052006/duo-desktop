# T-023 — Entregable chat (persistencia Linux corregida)

## Estado

Continuación realizada en la misma rama:

`chat/t-023-implementa-fondos-de-video-configurables`

No se integró ni se escribió en `main`.

## Corrección principal

La app ya no depende únicamente del registro automático Dart de plugins Linux.

Antes de la primera lectura de preferencias, `main.dart` ejecuta explícitamente:

```dart
PathProviderLinux.registerWith();
SharedPreferencesLinux.registerWith();
```

Se añadieron como dependencias directas:

```yaml
shared_preferences_linux: ^2.4.1
path_provider_linux: ^2.2.2
```

y el lockfile marca ambas como `direct main`.

## Bootstrap real de preferencias en Linux

`FondoVideoConfig.inicializarPersistencia()`:

1. obtiene el application support path con `PathProviderLinux`;
2. crea el directorio;
3. calcula la ruta de `shared_preferences.json`;
4. escribe una clave bootstrap;
5. comprueba el bool de `setBool`;
6. ejecuta `reload()`;
7. relee la clave;
8. verifica que el archivo existe físicamente.

La ruta queda disponible en:

`FondoVideoConfig.rutaArchivoPreferencias`

Con XDG_DATA_HOME por defecto, el archivo queda bajo:

`~/.local/share/<application-id>/shared_preferences.json`

Si el bootstrap falla, la app no aborta: conserva el error real en
`FondoVideoConfig.falloInicializacion` para mostrarlo en Personalización.

## Escrituras verificadas

Ahora se comprueba explícitamente el `bool` devuelto por SharedPreferences para:

- modo de fondo;
- carpeta de vídeos;
- intervalo;
- opacidad.

Si SharedPreferences devuelve `false`, se lanza `FalloPreferencias` con el detalle de la operación y, cuando está disponible, la ruta real del archivo.

La UI:

- muestra el error;
- revierte el valor visual;
- muestra `sin guardar`;
- no muestra `persistido`;
- no notifica a MarcoApp un modo de fondo que no llegó a disco.

## Cambio de modo Vídeo en la misma sesión

`FondoVideoConfig.guardarModoFondo()` incrementa `FondoVideoConfig.cambios` únicamente después de un `setString` exitoso.

`MarcoApp` escucha ese notifier.

Por tanto:

1. usuario selecciona `Vídeo`;
2. se persiste `personalizacion.fondo = video`;
3. solo si la escritura devuelve true se emite el cambio;
4. MarcoApp relee las preferencias en esa misma sesión;
5. enumera la carpeta configurada;
6. selecciona el vídeo;
7. crea el reproductor real.

Si la escritura falla, MarcoApp no recibe un falso cambio.

## Tests añadidos/corregidos

### Fallo de persistencia

`pantalla_personalizacion_test.dart` puede hacer que el mock de SharedPreferences devuelva `false` para una clave concreta.

El test:

`si guardar el modo falla se muestra el error y no dice persistido`

comprueba que:

- aparece el error `SharedPreferences devolvió false`;
- aparece `sin guardar`;
- no aparecen los controles de vídeo;
- el valor no queda guardado.

### Notificación de modo vídeo

Se cubre de dos formas:

- widget test: `cambiar a video notifica a MarcoApp tras persistir`;
- unit test: `guardar modo video notifica solo después de persistir`.

El unit test verifica que el valor ya existe en SharedPreferences antes de comprobar que `cambios` avanzó.

## Otros ajustes de tests

Se corrigieron regresiones de los tests anteriores:

- import faltante de `FondoVideoConfig`;
- asserts que todavía asumían que existía un único Slider;
- expectativa obsoleta del mensaje de error de preferencias.

## Documentación

`docs/diseño/README.md` documenta ahora:

- registro explícito Linux;
- ruta XDG/`~/.local/share`;
- bootstrap;
- comprobación de escritura;
- comportamiento de notificación tras persistencia.

## Validación solicitada

Se intentó ejecutar en el entorno disponible:

```bash
flutter analyze
flutter test
flutter build linux --debug
```

Resultado real de los tres:

```text
flutter: command not found
exit=127
```

También se verificó:

```text
command -v flutter -> vacío
command -v dart    -> vacío
```

El contenedor de esta sesión tampoco tiene el worktree local de duo-desktop y no puede resolver github.com para clonarlo.

Por tanto **no se declara analyze/test/build como pasados**.

Deben ejecutarse en el worktree real de T-023:

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build linux --debug
```

## Archivos relevantes modificados en esta corrección

- `app/pubspec.yaml`
- `app/pubspec.lock`
- `app/lib/main.dart`
- `app/lib/src/pantallas/fondo_video_config.dart`
- `app/lib/src/pantallas/pantalla_personalizacion.dart`
- `app/test/fondo_video_config_test.dart`
- `app/test/pantalla_personalizacion_test.dart`
- `docs/diseño/README.md`

## Commits principales de esta corrección

- `c50c9df` fix(linux): declara backends de preferencias y paths
- `3940b2a` chore(app): marca plugins Linux como dependencias directas
- `d05ede5` fix(linux): registra preferencias antes de la primera lectura
- `6fcc954` fix(linux): verifica archivo y escrituras de preferencias
- `25f5a7e` fix(ui): muestra fallos reales de persistencia
- `07dfa52` fix(linux): no aborta la app si falla el bootstrap de preferencias
- `45f5061` test(ui): corrige regresiones de Personalización
- `d95840f` docs(design): documenta persistencia Linux explícita
- `778347a` test(ui): verifica notificación tras persistir modo vídeo

Todos los commits de chat llevan:

`Tarea: T-023`
`Agente: chat`

## Estado frente a main

- ahead: 12
- behind: 1
- archivos modificados: 8

No se realizó merge a `main`.
