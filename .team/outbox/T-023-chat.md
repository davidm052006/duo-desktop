# T-023 — Entregable chat (continuación tras revisión)

## Estado

Continuación realizada en la misma rama:

`chat/t-023-implementa-fondos-de-video-configurables`

No se escribió ni se integró en `main`.

## Resumen

La ampliación de territorio permitió completar la implementación real de fondos de vídeo:

- backend multimedia real con `media_kit`;
- vídeo renderizado detrás de `MarcoApp`;
- audio silenciado desde la creación del `Player` y volumen 0;
- sin controles sobre el vídeo de fondo;
- cambio aleatorio por intervalo;
- salto automático a otro archivo cuando el reproductor reporta error;
- liberación del `Player` al cambiar de vídeo o destruir el widget;
- corrección del bug de modos no vídeo;
- opacidad global aplicada a superficies de panel, no a texto ni iconos;
- tests unitarios/widget añadidos;
- documentación de diseño actualizada.

## Dependencias

Añadidas en `app/pubspec.yaml`:

```yaml
media_kit: ^1.2.6
media_kit_video: ^2.0.1
media_kit_libs_video: ^1.0.7
```

`app/lib/main.dart` ejecuta:

```dart
WidgetsFlutterBinding.ensureInitialized();
MediaKit.ensureInitialized();
```

antes de arrancar la app.

## Reproducción real

Se añadió:

`app/lib/src/pantallas/fondo_video_reproductor.dart`

El widget:

- crea un `Player` real;
- crea un `VideoController`;
- abre archivos locales mediante URI `file://`;
- usa `Video(... fit: BoxFit.cover)`;
- no acepta interacción;
- inicia muteado;
- escucha `player.stream.error`;
- notifica un fallo una sola vez por ruta;
- cancela su suscripción y ejecuta `player.dispose()` en `dispose`.

`MarcoApp` usa una `ValueKey` basada en la ruta. Al cambiar de vídeo Flutter destruye el widget anterior y por tanto libera el reproductor antes/de forma asociada al nuevo render.

## Fallback ante vídeo inválido

Durante una sesión se mantiene el conjunto de rutas que fallaron.

Si el reproductor informa error:

1. la ruta actual se marca como fallida;
2. se elige aleatoriamente otro candidato;
3. no se vuelve a elegir una ruta fallida en esa sesión;
4. si ya no quedan candidatos, se muestra un estado de error y se deja de fingir reproducción.

La validación por extensión sigue siendo solo un filtro previo: el error real de decodificación lo decide el backend multimedia.

## Bug corregido — Sin fondo / Degradado

`MarcoApp` lee primero:

`personalizacion.fondo`

La rotación solo se activa cuando el valor es exactamente:

`video`

Para:

- `ninguno`;
- `degradado`;
- `imagen`;
- valores desconocidos;

se hace lo siguiente:

- se cancela cualquier timer anterior;
- se limpia el vídeo seleccionado;
- se limpia el estado de vídeo;
- no se enumera la carpeta;
- no se selecciona archivo;
- no se crea reproductor;
- no aparece indicador de vídeo.

Por tanto una carpeta guardada no activa vídeo por sí sola.

## Degradado

Cuando el modo es `degradado`, `MarcoApp` pinta un degradado real como capa de fondo, sin inicializar reproducción.

## Rotación

Intervalos aceptados:

- 5 minutos;
- 15 minutos;
- 30 minutos;
- 60 minutos;
- 120 minutos.

Cualquier valor inválido se normaliza a 30 minutos.

No se crea `Timer.periodic` si la carpeta no contiene candidatos.

Al cambiar carpeta/intervalo/modo desde Personalización se actualiza la rotación inmediatamente.

Cambiar únicamente la opacidad ya NO reinicia ni relee el reproductor.

## Opacidad global de superficies

Rango seguro:

`0.72 ... 0.98`

`TemaDuo.claro/oscuro` reciben la opacidad y generan una copia de `PaletaDatos` donde solo:

`panel`

lleva alfa reducido.

Texto e iconos mantienen sus colores de tinta con alfa completo.

No se usa `Opacity` sobre el árbol de widgets.

Esto afecta globalmente a componentes que consumen `paleta.panel`, incluyendo:

- `Tarjeta`;
- barra superior;
- barra lateral;
- app bars que usan la superficie de panel.

El `MaterialApp` se reconstruye al cambiar la preferencia mediante un `ValueListenableBuilder<double>`.

## Fondo global

El scaffold principal y el tema permiten fondo transparente.

Orden de capas en `MarcoApp`:

1. superficie/degradado base;
2. vídeo real cuando el modo es vídeo;
3. toda la interfaz de Duo Desktop.

Así el vídeo queda detrás de la UI y no intercepta eventos.

## Tests añadidos

Nuevo:

`app/test/fondo_video_config_test.dart`

Cubre:

- selección aleatoria;
- exclusión del vídeo actual;
- exclusión de vídeos fallidos;
- normalización del intervalo;
- modo `ninguno`;
- modo `degradado`;
- modo `video`;
- clamp de opacidad;
- opacidad solo del color `panel`;
- texto con alfa completo;
- enumeración de extensiones candidatas.

También se actualizó:

`app/test/pantalla_personalizacion_test.dart`

para:

- distinguir slider de tipografía y slider de opacidad;
- comprobar opacidad por defecto/persistencia;
- comprobar que `Sin fondo` no muestra controles de vídeo;
- comprobar que modo `video` sí muestra carpeta e intervalo.

## Documentación

Actualizado:

`docs/diseño/README.md`

Incluye:

- arquitectura del fondo de vídeo;
- dependencias;
- inicialización;
- mute;
- política de salto ante errores;
- comportamiento de modos no vídeo;
- opacidad de superficies;
- límite Linux/libmpv.

## Pruebas solicitadas

Solicitadas:

```bash
cd app
flutter analyze
flutter test
flutter build linux --debug
```

### Resultado real

**NO EJECUTADAS EN ESTE ENTORNO.**

El entorno disponible para ChatGPT en esta sesión:

- no tiene el worktree local de `duo-desktop` montado;
- no tiene ejecutable `flutter`;
- no tiene ejecutable `dart`;
- el contenedor no puede clonar GitHub por resolución de red.

Por eso no se declara ninguna de esas validaciones como pasada.

## pubspec.lock

`app/pubspec.lock` debe regenerarse exclusivamente mediante:

```bash
cd app
flutter pub get
```

No se modificó manualmente: fabricar un lockfile sin resolver toda la clausura de dependencias sería menos seguro que dejar explícita la validación pendiente.

Codex debe ejecutar `flutter pub get` en el worktree T-023, revisar el lockfile generado y commitearlo en esta misma rama antes de aprobar/integrar.

## Validación requerida por Codex

Desde el worktree:

```bash
git switch chat/t-023-implementa-fondos-de-video-configurables
cd app
flutter pub get
flutter analyze
flutter test
flutter build linux --debug
```

Después debe probar visualmente:

1. `Sin fondo`: nunca crea ni muestra vídeo.
2. `Degradado`: nunca crea ni muestra vídeo.
3. `Vídeo`: render real detrás de la UI.
4. El vídeo inicia sin audio.
5. Cambio de intervalo rota a otro candidato.
6. Archivo corrupto/no decodificable salta al siguiente.
7. Cambio de modo vídeo → ninguno destruye el reproductor.
8. Cambio de archivo destruye el reproductor anterior.
9. Opacidad mínima 72% deja texto/iconos totalmente opacos.
10. Cerrar app no deja proceso/controlador multimedia activo.

## Límites de plataforma

### Linux

`media_kit` usa libmpv para el backend multimedia de escritorio Linux.

La disponibilidad real de codecs depende del entorno/libmpv, no solo de la extensión del archivo.

En Debian/Ubuntu, la documentación de media_kit indica instalar las dependencias de libmpv/mpv cuando no estén presentes.

### Carpeta

El selector actual es un navegador de carpetas hecho en Flutter/`dart:io`.

- respeta permisos normales del proceso;
- muestra errores de acceso;
- no sigue symlinks al enumerar;
- no depende de un portal XDG/GTK.

## Commits de la continuación

Entre los commits añadidos en esta continuación están:

- `45ab6a2` chore(app): añade media_kit para fondo de vídeo
- `7e8444b` feat(app): inicializa backend multimedia
- `22b7615` feat(ui): reproduce vídeo real detrás de la interfaz
- `6273915` feat(ui): integra fondo de vídeo y respeta modos no vídeo
- `53c8088` feat(theme): aplica opacidad global a superficies de panel
- `f5db2a1` test(ui): cubre selección intervalo modo y opacidad
- `cd4d665` docs(design): documenta fondos de vídeo Linux
- `1e063cb` test(ui): adapta Personalización a fondo y opacidad
- `db0b442` perf(ui): separa opacidad de la rotación de vídeo
- `50bffc0` perf(ui): no inicia rotación con carpeta vacía

Todos los commits creados por chat incluyen:

`Tarea: T-023`
`Agente: chat`

## Estado Git

Comparación actual contra `main`:

- ahead: 33
- behind: 0
- archivos modificados: 10

No se realizó merge a `main`.
