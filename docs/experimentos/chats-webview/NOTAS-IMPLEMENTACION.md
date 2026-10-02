# Notas de implementación — Chats WebView

> **Rama:** `experiment/chats-webview`  
> **Fecha:** 2026-10-02  
> **Estado:** depuración del primer WebView embebido funcional a nivel de navegación, pero sin pintura visible.

## Hallazgo actual

La implementación con `webview_all: ^1.4.4`:

- compila y arranca en Linux;
- crea el controlador;
- navega;
- dispara `onPageStarted` / `onPageFinished`;
- actualiza la UI de Duo a `Página lista`;
- permite cambiar ChatGPT/Grok;
- permite abrir ambas URLs en el navegador del sistema.

Sin embargo, el área del WebView permanece vacía/transparente y deja ver el fondo de vídeo de Duo.

No se observan errores de navegación del WebView en los logs disponibles.

Esto separa el problema en dos capas:

1. **navegación/proceso web:** aparentemente activo;
2. **presentación/composición:** sospechosa.

Por ello no conviene depurar primero login, cookies o JavaScript.

---

# Diagnóstico ordenado

## Probabilidad alta — composición WebKitGTK / GPU / DMA-BUF

`webview_all` usa WebKitGTK 4.1 en Linux y monta una vista GTK nativa dentro de la ventana Flutter.

WebKitGTK tiene incidencias históricas y actuales con NVIDIA donde:

- el WebView existe;
- la página puede responder;
- la superficie queda blanca/vacía;
- aparecen fallos de GBM/DMA-BUF o de sincronización Wayland.

Esto encaja especialmente bien con el síntoma de Duo: `onPageFinished` llega, pero no se ve ningún frame web.

**Importante:** `WEBKIT_DISABLE_DMABUF_RENDERER=1` es una prueba diagnóstica, no una configuración definitiva. En versiones WebKitGTK actuales existen reportes donde deshabilitar DMA-BUF también causa crashes o defectos en WebGL.

## Probabilidad media-alta — interacción con media_kit / vídeo de fondo

Duo ya tiene una superficie de vídeo activa detrás de la UI.

Aunque el WebView debería poder coexistir, tanto vídeo como WebKit pueden usar EGL/GPU/DMABUF. Un problema de composición, stacking o contexto gráfico puede dejar la vista WebKit sin contenido visible.

La prueba más barata es ejecutar exactamente la misma pantalla con el fondo de vídeo desactivado.

## Probabilidad media — integración nativa de webview_all

`webview_all` ha corregido recientemente en Linux:

- vistas colapsadas a 0x0;
- sincronización de visibilidad;
- posición del widget GTK;
- routing de input;
- layout con `GtkOverlay`.

Por tanto, la integración Linux todavía está evolucionando y un bug específico del compositor/ventana de Duo es plausible.

## Probabilidad baja — layout Flutter 0x0

La implementación actual usa:

```text
Expanded
└── _MarcoWebChat
    └── Stack(fit: StackFit.expand)
        └── WebViewWidget
```

El WebView recibe restricciones finitas del área central.

Además, `webview_all` 1.3.x ya incluyó una corrección específica para evitar que una vista Linux estable colapse a 0x0.

No descartar por completo hasta medir tamaño en runtime, pero no es la hipótesis principal.

## Probabilidad baja — ChatGPT/Grok incompatibles

Una incompatibilidad del sitio podría producir contenido roto, challenge o error, pero que **example.com / HTML local también queden invisibles** señalaría inmediatamente que el problema está por debajo del sitio.

Por eso la siguiente prueba no debe ser otro login: debe ser una página trivial.

---

# Pruebas concretas, baratas y en orden

Ejecutar una sola variable a la vez y registrar resultado.

## P0 — baseline de entorno

Registrar:

```bash
flutter --version
echo "$XDG_SESSION_TYPE"
echo "$WAYLAND_DISPLAY"
echo "$DISPLAY"
lspci -k | grep -A3 -E 'VGA|3D|Display'
pacman -Q webkit2gtk-4.1 gtk3 2>/dev/null
```

Si hay NVIDIA:

```bash
nvidia-smi
```

Guardar versión de driver.

## P1 — cargar una página trivial

Temporalmente cambiar la URL del proveedor por:

```text
https://example.com
```

Resultado esperado:

- si **también es transparente** → problema de render/composición, no ChatGPT/Grok;
- si example.com pinta → investigar JS/WebGL/CSS del sitio real.

## P2 — cargar HTML simple generado por la app

Usar temporalmente `loadHtmlString` con un fondo opaco y texto grande.

Ejemplo conceptual:

```html
<body style="background:#fff;color:#000">
  WEBVIEW VISIBLE
</body>
```

Si tampoco se ve, elimina red, TLS, CSP y SPA de la ecuación.

## P3 — desactivar completamente el fondo de vídeo

En Personalización:

- poner fondo `ninguno` o equivalente;
- reiniciar la app;
- probar otra vez.

No basta con tapar visualmente el vídeo: para esta prueba el reproductor `media_kit` no debe estar activo.

Interpretación:

- WebView aparece → conflicto de composición con vídeo/GPU;
- sigue transparente → continuar.

## P4 — probar DMA-BUF deshabilitado

Desde terminal:

```bash
WEBKIT_DISABLE_DMABUF_RENDERER=1 flutter run -d linux
```

o contra el binario construido:

```bash
WEBKIT_DISABLE_DMABUF_RENDERER=1 ./build/linux/x64/debug/bundle/duo_desktop
```

Interpretación:

- aparece contenido → fuerte evidencia de bug DMA-BUF/NVIDIA;
- crash → registrar; también es información válida en WebKitGTK moderno;
- sin cambio → continuar.

No incorporar esta variable al launcher todavía.

## P5 — forzar X11 para aislar Wayland

Si la sesión es Wayland:

```bash
GDK_BACKEND=x11 flutter run -d linux
```

Luego combinar **solo como prueba**:

```bash
GDK_BACKEND=x11 WEBKIT_DISABLE_DMABUF_RENDERER=1 flutter run -d linux
```

Interpretación:

- funciona solo bajo X11 → interacción Wayland/compositor;
- funciona solo con DMA-BUF desactivado → renderer WebKitGTK;
- requiere ambas → combinación conocida en algunos equipos NVIDIA;
- no funciona → continuar.

## P6 — NVIDIA explicit sync

Solo si:

- GPU NVIDIA;
- sesión Wayland;
- las pruebas anteriores apuntan a sincronización.

Probar:

```bash
__NV_DISABLE_EXPLICIT_SYNC=1 flutter run -d linux
```

Existe evidencia reciente de WebKitGTK/Wayland/NVIDIA donde esta variable evita un error de explicit sync.

No usar como solución permanente sin confirmar el driver/compositor afectados.

## P7 — quitar clipping temporalmente

En `_MarcoWebChat`, como prueba:

- quitar `clipBehavior: Clip.antiAlias`;
- eliminar temporalmente `borderRadius`;
- dejar un contenedor rectangular simple.

Las vistas nativas pueden tener limitaciones con transformaciones/clipping.

Si esto lo arregla, mantener el WebView sin clipping nativo y dibujar marco/decoración fuera de su superficie.

## P8 — tamaño explícito / medición

Aunque no sea la hipótesis principal:

- imprimir constraints del área;
- probar temporalmente un `SizedBox(width: 900, height: 600)`;
- confirmar que el native view recibe posición/tamaño > 0.

Si el tamaño real es correcto, cerrar esta hipótesis.

## P9 — MiniBrowser/WebKitGTK fuera de Flutter

Ejecutar una app mínima del propio WebKitGTK, idealmente `MiniBrowser` si el paquete lo incluye.

Objetivo:

- determinar si WebKitGTK pinta correctamente en el mismo host sin Flutter.

Si MiniBrowser también falla, Duo/webview_all quedan parcialmente exonerados.

## P10 — solo entonces probar otro wrapper

Si:

- HTML trivial sigue vacío;
- sin vídeo sigue vacío;
- tamaño correcto;
- variables GPU no resuelven;
- MiniBrowser funciona;

entonces el sospechoso principal pasa a ser la integración de `webview_all` con Flutter.

---

# Siguiente candidato recomendado

## flutter_inappwebview + flutter_inappwebview_linux

Si `webview_all` falla la matriz anterior, el siguiente candidato debe ser **`flutter_inappwebview` con backend Linux WPE**.

Razones:

- usa WPE WebKit en vez de insertar un widget WebKitGTK;
- está pensado para render offscreen;
- entrega frames a Flutter mediante textura;
- el backend moderno usa WPEPlatform;
- soporta DMA-BUF y fallback SHM;
- evita exactamente la misma ruta de composición GTK nativa que estamos poniendo bajo sospecha.

Esto no garantiza que NVIDIA deje de ser problemática: WPE también toca DMA-BUF. Pero cambia suficientemente la arquitectura como para ser una prueba útil.

## Migración mínima de pantalla_chats.dart

La UI actual debe conservarse.

No reescribir:

- selector ChatGPT/Grok;
- estados;
- barra de acciones;
- fallback externo;
- `_MarcoWebChat`;
- tema.

Cambiar solo la capa de navegador:

1. import de `webview_all` → import de `flutter_inappwebview`;
2. `WebViewController` → controlador de InAppWebView;
3. `WebViewWidget(controller: ...)` → `InAppWebView(...)`;
4. mapear:
   - inicio navegación → `cargando`;
   - fin navegación → `listo`;
   - error → `errorNavegacion`;
5. `reload()` y carga de URL se conectan al nuevo controlador;
6. mantener **un solo widget/controlador activo**;
7. no aprovechar todavía APIs adicionales.

La migración debe verse como reemplazo de adapter, no rediseño de pantalla.

---

# webview_flutter_linux y conflicto de meta

## Qué ocurrió

`webview_flutter_linux 0.1.0-dev.2` depende de tooling moderno de native assets:

```text
webview_flutter_linux
└── hooks
    └── record_use
        └── meta ^1.19.0
```

El Flutter SDK instalado en la máquina del experimento fija `meta 1.18.0`.

Pub no puede satisfacer ambas restricciones.

## Opción recomendada: upgrade de Flutter

El Flutter upstream actual ya usa `meta ^1.19.0` / `meta 1.19.0` en sus paquetes de framework/tooling.

Por eso la solución limpia es:

1. registrar `flutter --version`;
2. revisar el cambio de versión en una rama/commit aislado;
3. actualizar Flutter a una stable que use `meta 1.19.x`;
4. ejecutar:
   - `flutter pub get`;
   - `flutter analyze`;
   - tests existentes;
   - build Linux;
5. volver a intentar:
   - `webview_flutter ^4.14.1`;
   - `webview_flutter_linux ^0.1.0-dev.2`.

Esto elimina el conflicto en la raíz.

## No recomendado: dependency_overrides de meta

Es técnicamente tentador añadir:

```yaml
dependency_overrides:
  meta: ^1.19.0
```

pero no es la primera opción.

Razones:

- sustituye una versión que el Flutter SDK de esa instalación eligió/pinó;
- puede dejar el proyecto en una combinación que Flutter no probó;
- oculta el requisito real del nuevo sistema de hooks/native assets;
- el objetivo del experimento es evaluar WebView, no mantener un SDK parcheado.

Solo usarlo como prueba desechable para confirmar el diagnóstico del resolver, nunca como solución que llegue a `main`.

## Versión anterior del plugin

`webview_flutter_linux` solo tiene dos prereleases públicas actuales: `0.1.0-dev.1` y `0.1.0-dev.2`.

Ambas pertenecen a la misma generación basada en native assets/WPE. No hay una rama estable antigua claramente recomendable para evitar el conflicto.

Por tanto, **no invertir tiempo en downgrade del plugin** salvo que al inspeccionar su pubspec concreto se demuestre una restricción compatible.

---

# Árbol de decisión

```text
webview_all → onPageFinished pero invisible
        │
        ├─ example.com / HTML simple invisible?
        │      │
        │      ├─ no → investigar ChatGPT/Grok
        │      │
        │      └─ sí
        │
        ├─ sin media_kit funciona?
        │      └─ sí → conflicto compositor/GPU
        │
        ├─ DMABUF/X11/explicit-sync cambia resultado?
        │      └─ sí → workaround de entorno documentado
        │
        ├─ MiniBrowser también falla?
        │      └─ sí → bug/driver/WebKitGTK del host
        │
        └─ MiniBrowser funciona pero webview_all no
               └─ probar flutter_inappwebview/WPE
```

En paralelo:

```text
upgrade Flutter compatible con meta 1.19
        └─ volver a probar webview_flutter_linux/WPE
```

---

# Prioridad recomendada

1. No cambiar paquete todavía.
2. Ejecutar P1–P5.
3. Si NVIDIA + Wayland, ejecutar P6.
4. Ejecutar P7–P9.
5. Si el fallo queda aislado a `webview_all`, migrar solo la capa WebView a `flutter_inappwebview`.
6. En paralelo o después, probar upgrade controlado de Flutter para reabrir `webview_flutter_linux`.
7. Mantener Chrome externo solo como fallback; no convertirlo en implementación principal en esta fase.
