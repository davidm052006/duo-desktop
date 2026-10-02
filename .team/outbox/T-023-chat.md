# T-023 — Entregable chat

## Estado

Trabajo realizado en:

`chat/t-023-implementa-fondos-de-video-configurables`

Base: `origin/main` / `main`.

No se escribió ni se integró en `main`.

## Territorio respetado

El brief contiene una contradicción: la descripción pide tocar tema global, dependencias, tests y documentación, pero la sección **Territorio** restringe explícitamente la tarea a:

`app/lib/src/pantallas`

Se respetó esa restricción estricta. Solo se modificaron:

- `app/lib/src/pantallas/fondo_video_config.dart`
- `app/lib/src/pantallas/pantalla_personalizacion.dart`
- `app/lib/src/pantallas/marco_app.dart`

No se modificaron:

- `app/pubspec.yaml`
- `app/lib/src/tema/`
- `app/lib/src/widgets/`
- `app/test/`
- `docs/`
- `service/`
- `scripts/`

## Implementado

### Configuración de carpeta de vídeos

En Personalización:

- selector de carpeta local implementado sin dependencias nuevas;
- navegación por carpetas dentro de un diálogo Flutter;
- manejo de carpeta inexistente;
- manejo de permisos/errores de lectura;
- listado de subcarpetas;
- carpeta seleccionada persistida con `shared_preferences`.

Clave:

`personalizacion.video.carpeta`

### Enumeración y validación básica

Se enumeran archivos de la carpeta sin seguir enlaces simbólicos.

Extensiones candidatas:

- `.mp4`
- `.m4v`
- `.mov`
- `.webm`
- `.mkv`

La UI muestra:

- carpeta vacía;
- carpeta no legible;
- cantidad de vídeos candidatos;
- nombres de archivos detectados.

Importante: esta es validación por extensión y acceso al archivo. La validación real de codec/contenedor requiere el backend de reproducción que el territorio actual no permite añadir.

### Selección aleatoria y rotación

`MarcoApp`:

- lee las preferencias al iniciar;
- elige un archivo candidato aleatorio;
- configura un `Timer.periodic` para volver a seleccionar;
- cancela el timer al liberar el widget;
- vuelve a cargar la configuración al reanudar la app;
- reacciona inmediatamente a cambios hechos desde Personalización mediante una señal local;
- maneja carpeta vacía, carpeta no legible y archivos desaparecidos.

Intervalos disponibles:

- 5 minutos;
- 15 minutos;
- 30 minutos;
- 60 minutos;
- 120 minutos.

Clave:

`personalizacion.video.intervalo_minutos`

### Opacidad de paneles

Se añadió en Personalización:

- slider 72–98%;
- valor persistido;
- normalización de valores inválidos;
- rango deliberadamente seguro para no permitir transparencias extremas.

Clave:

`personalizacion.paneles.opacidad`

La aplicación global de esta opacidad a todas las cards/paneles NO se implementó porque `Tarjeta` y la paleta/tema están fuera del territorio permitido.

### Estado visible

La barra superior muestra un indicador cuando:

- existe un vídeo seleccionado para la rotación; o
- la configuración del fondo tiene un error.

El tooltip deja claro que el playback real todavía no está conectado.

## Playback de vídeo: bloqueo por territorio

No se simuló reproducción.

El proyecto no tiene actualmente un backend de vídeo Linux entre sus dependencias.

El paquete oficial `video_player` no soporta Linux desktop. Para Linux sería necesario añadir un backend compatible, por ejemplo `media_kit` / `media_kit_video`, lo cual requiere modificar `app/pubspec.yaml` y posiblemente inicialización/plataforma fuera de `app/lib/src/pantallas`.

Como el territorio prohíbe esos cambios, T-023 deja preparada la configuración, enumeración, selección y rotación, pero **no reproduce el archivo detrás de la interfaz**.

Tampoco se creó un reproductor falso ni una imagen sustituta presentada como vídeo.

## Audio

No hay reproducción, por lo que tampoco existe audio activo.

Cuando se conecte el backend de vídeo, el contrato visual de T-023 requiere iniciar con volumen 0 / mute.

## Liberación de recursos

Dentro del alcance actual:

- se cancela el `Timer` en `dispose`;
- se elimina el `WidgetsBindingObserver`;
- se elimina el listener de cambios de preferencias.

No existe todavía un controlador multimedia que liberar.

## Pruebas ejecutadas

No se pudieron ejecutar pruebas ni `flutter analyze` desde este conector porque el worktree local de la rama no está montado en el entorno de ejecución.

Sí se verificó mediante GitHub:

- rama basada en `main`;
- ahead: 8 commits;
- behind: 0;
- solo 3 archivos modificados;
- todos dentro de `app/lib/src/pantallas`.

Validación local requerida por Codex:

```bash
cd app
flutter analyze
flutter test
flutter build linux --debug
```

Después:

```fish
scripts/dev.fish
```

desde el worktree de T-023.

## Casos que Codex debe probar

1. Sin carpeta configurada.
2. Elegir una carpeta válida.
3. Carpeta vacía.
4. Carpeta sin permisos de lectura.
5. Carpeta eliminada después de guardarla.
6. Vídeos con extensiones admitidas y archivos no admitidos mezclados.
7. Cambio de intervalo sin reiniciar la app.
8. Reanudar la ventana/app.
9. Cerrar la app y comprobar que el timer se libera.
10. Preferencias corruptas o intervalo fuera de opciones.
11. Slider de opacidad entre 72% y 98%.

## Límites de plataforma

### Linux

La selección de carpeta implementada usa `dart:io` y un navegador de carpetas propio, por lo que no depende de portal GTK/XDG ni de `file_picker`.

Consecuencias:

- funciona sobre rutas que el proceso puede leer;
- permisos del sistema se reflejan como error;
- no sigue symlinks al enumerar vídeos;
- no ofrece integración nativa con portales/sandbox;
- no valida codecs porque todavía no existe backend multimedia.

### Reproducción

Pendiente por territorio.

Para Linux se necesita una dependencia con soporte real de vídeo desktop. Esto debe resolverse en una tarea que permita tocar `pubspec.yaml` e inicialización global.

### Opacidad global

Pendiente por territorio.

La preferencia ya existe, pero aplicarla correctamente requiere tocar `Tarjeta` y/o el tema/paleta para cambiar únicamente superficies sin reducir la opacidad del texto.

No debe implementarse envolviendo toda la UI en `Opacity`, porque eso degradaría también texto, iconos y contraste.

## Commits

- `a6e8454` feat(ui): añade configuración y selector de carpeta de vídeo
- `54e611f` feat(ui): configura carpeta intervalo y opacidad de fondos
- `02c4495` fix(ui): evita extension no disponible en selector
- `fceb6ca` feat(ui): selecciona y rota vídeos configurados
- `00650b1` fix(ui): ajusta tipo del intervalo de rotación
- `7c0494b` feat(ui): notifica cambios de configuración de fondo
- `ff0aafe` fix(ui): aplica cambios de rotación sin reiniciar
- `b36906f` fix(ui): normaliza preferencias de vídeo

Todos llevan:

`Tarea: T-023`
`Agente: chat`

## Pendiente para completar el brief original

Requiere una tarea con territorio ampliado para:

1. añadir dependencias de reproducción Linux;
2. inicializar el backend multimedia;
3. renderizar el vídeo detrás de `MarcoApp`;
4. iniciar siempre muteado;
5. detectar fallo de decodificación y saltar al siguiente vídeo;
6. liberar el controlador multimedia al cambiar/cerrar;
7. aplicar `personalizacion.paneles.opacidad` globalmente a superficies;
8. añadir tests en `app/test/`;
9. documentar la dependencia y límites en `docs/diseño/`.

No se invadieron esos archivos en T-023.
