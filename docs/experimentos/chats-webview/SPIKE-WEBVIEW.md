# Spike: WebView ligero para Flutter Linux

> **Rama:** `experiment/chats-webview`  
> **Fecha de investigación:** 2026-10-02  
> **Estado:** validación runtime en curso. `webview_flutter_linux` quedó bloqueado por conflicto de `meta`; `webview_all` compila y navega, pero el WebView queda transparente. Ver `NOTAS-IMPLEMENTACION.md`.

## Resumen ejecutivo

Para este experimento conviene probar primero **`webview_flutter` + `webview_flutter_linux` 0.1.0-dev.2**, usando el **WPE WebKit 2.52+ instalado por el sistema**.

La razón principal no es que sea la opción más madura —todavía es experimental— sino que encaja mejor con el objetivo del spike: no empaqueta Chromium/CEF, usa la API estándar de `webview_flutter`, renderiza a una textura Flutter sin incrustar un widget GTK y en Arch Linux la dependencia nativa requerida está disponible directamente como `wpewebkit` 2.52.6.

Como segunda opción queda **`flutter_inappwebview` + backend Linux/WPE**. Tiene una API más amplia y un proyecto general mucho más establecido, pero el soporte Linux/WPE sigue siendo beta y existen incidencias recientes de build/renderizado en Linux. Es el fallback natural si el primer candidato falla por cookies, popups, permisos o APIs faltantes.

No se recomienda comenzar con CEF/Chromium embebido. `flutter_linux_webview` usa Chromium 96/CEF, arrastra una distribución de CEF y su propia documentación reconoce problemas históricos de estabilidad. Solo tendría sentido como último recurso de compatibilidad.

## Comparativa

| Opción | Motor / integración | Madurez Linux (oct. 2026) | Cookies / sesión | Facilidad | Memoria esperada* | Riesgo principal |
|---|---|---|---|---|---|---|
| **`webview_flutter_linux` 0.1.0-dev.2** | WPE WebKit 2.52+ del sistema; textura Flutter; API `webview_flutter` | **Nueva / experimental**. 2 prereleases; no es implementación oficial/endosada por Flutter | Tiene `LinuxWebViewCookieManager`, data manager y soporte de local storage/cache; hay que validar persistencia real entre procesos con ChatGPT/Grok | **Alta** para un spike: API conocida y poca superficie propia | **Baja-media para un navegador embebido**; presupuestar ~150–350 MB por panel SPA activo como rango de prueba, no benchmark | Juventud del plugin; autenticación compleja, popups o edge cases de WPE |
| **`flutter_inappwebview` 6.2 beta + `flutter_inappwebview_linux` 0.1.0-beta.1** | WPE WebKit; backend WPEPlatform moderno con DMA-BUF/SHM | Proyecto global muy maduro, **backend Linux beta** añadido en 2026 | Expone `LinuxCookieManager`, Web Storage/headless APIs y más hooks de navegador | **Media**: API potente pero mayor superficie/configuración | **Baja-media**, del mismo orden que WPE anterior; presupuestar ~170–400 MB por SPA activa | Linux beta; incidencias recientes de detección WPE y fallback GL |
| **`webview_linux` 0.0.2** | WebKitGTK 4.1 vía Dart FFI | **Muy inmaduro**: paquete nuevo, versión 0.0.2, poca adopción | WebKitGTK soporta persistencia nativamente, pero la API del paquete debe verificarse para exponer todo lo necesario | Media-baja para este caso | **Baja-media**; motor del sistema, pero sin evidencia suficiente para cuantificar mejor | Superficie incompleta y poco historial; mayor riesgo de mantener bindings propios |

\* Los rangos de RAM son **presupuestos de ingeniería para orientar la prueba**, no mediciones publicadas de estos paquetes ni garantía. Una SPA como ChatGPT/Grok puede dominar el consumo sobre el wrapper Flutter. En la Fase 1/6 hay que medir RSS/PSS real del proceso principal y procesos WebKit en el i5-7200U.

### Opción descartada como candidata principal: CEF

`flutter_linux_webview` 0.1.0 usa CEF/Chromium 96 y descarga binarios de CEF al construir. Su documentación reporta creación de WebViews inestable y hangs/crashes en determinadas versiones/plataformas. Además contradice el objetivo de reutilizar el motor del sistema. Si WPE falla por incompatibilidad web concreta, antes de CEF conviene evaluar el navegador del sistema como fallback.

## Recomendación

### Probar primero: `webview_flutter_linux`

**Por qué:**

1. Cumple exactamente la restricción de peso: usa **WPE WebKit del host** y no incluye un Chromium privado.
2. En Arch Linux actual existe `wpewebkit 2.52.6`, superior al mínimo 2.52 solicitado por el plugin.
3. La integración usa `webview_flutter` 4.x, reduciendo código específico de Linux y dejando una salida más limpia si en el futuro Flutter endosa una implementación Linux.
4. El changelog reciente cubre varios puntos relevantes para este experimento: `window.open`/ciclo de vistas, preservación de estado al desmontar/ocultar, file chooser, HTTP auth, TLS, headers, terminación del proceso web y limpieza de cache/local storage.
5. Para **un solo panel**, su API más pequeña es preferible a introducir de entrada toda la superficie de InAppWebView.

### Cuándo cambiar al segundo candidato

Pasar a `flutter_inappwebview` si durante la prueba aparece alguno de estos bloqueos y su backend Linux sí lo resuelve:

- flujo OAuth/popups imposible de completar;
- control insuficiente de cookies o almacenamiento;
- permisos web no manejables;
- necesidad de interceptar navegación/ventanas/descargas con más detalle;
- incompatibilidad concreta de la implementación federada de `webview_flutter_linux`.

No migrar solo porque InAppWebView tenga más features: primero demostrar que una feature faltante es necesaria.

## Instalación mínima — Arch Linux

### Candidato 1: WPE + webview_flutter_linux

Dependencia nativa:

```bash
sudo pacman -S wpewebkit
```

Comprobación recomendada:

```bash
pkg-config --modversion wpe-webkit-2.0 wpe-platform-2.0
```

Debe ser **2.52 o superior** para `webview_flutter_linux` actual.

Cuando comience la implementación, las dependencias Dart previstas son:

```text
webview_flutter
webview_flutter_linux
```

No se añaden todavía en este commit de investigación.

Para audio/vídeo o formatos multimedia que lo requieran, WPE depende de GStreamer; instalar los plugins necesarios del sistema (`gst-plugins-base/good/bad/ugly`, `gst-libav`) solo si la validación demuestra que hacen falta.

### Candidato 2: flutter_inappwebview Linux/WPE

En Arch, comenzar igualmente con:

```bash
sudo pacman -S wpewebkit
```

Verificar además las interfaces que el backend detecta:

```bash
pkg-config --cflags --libs wpe-webkit-2.0
pkg-config --cflags --libs wpe-platform-2.0
```

El backend de InAppWebView selecciona WPEPlatform cuando está disponible y usa el backend FDO antiguo solo como fallback.

### Genérico

En otras distribuciones instalar WPE WebKit 2.52+ y sus archivos de desarrollo/pkg-config cuando el paquete compile bindings localmente. Los nombres cambian según distro. No fijar instrucciones de Ubuntu/Debian hasta comprobar qué versión de WPE ofrece la release objetivo: hay reportes de 2026 donde el paquete no es detectado correctamente.

## Compatibilidad esperada con SPAs modernas

WPE WebKit/WebKitGTK es un WebKit moderno con JavaScriptCore, almacenamiento web, procesos de red/web y soporte de APIs web contemporáneas. Por arquitectura es apto para SPAs intensivas en JavaScript.

Eso **no garantiza** que ChatGPT o Grok acepten el entorno. Ambos servicios pueden cambiar requisitos, user-agent, autenticación, challenge anti-bot o flujos OAuth sin previo aviso. Por eso el criterio real del spike no es “abre una SPA de prueba”, sino completar login y una conversación real en ambos sitios.

## Problemas esperados y mitigaciones

| Problema | Qué puede ocurrir | Mitigación propuesta |
|---|---|---|
| **Login OAuth / Google / Microsoft / X** | El proveedor puede bloquear user-agents embebidos o requerir una ventana nueva | Interceptar navegación/`window.open`; permitir popup controlado o abrir el login en navegador externo. No falsificar UA salvo que una prueba concreta lo justifique |
| **Cookies / sesión** | Sesión funciona durante la ejecución pero desaparece al reiniciar | Usar almacenamiento WebKit no efímero; mantener un directorio de datos estable por app/perfil; prueba obligatoria de cerrar proceso y reabrir |
| **localStorage / IndexedDB / Service Workers** | Una SPA puede depender de datos además de cookies | No implementar “persistencia de cookies” aislada: validar el **website data store completo** |
| **Popups / target=_blank** | OAuth, enlaces o herramientas abren otra ventana | Política explícita: dominios de auth en popup/WebView relacionado si el plugin lo soporta; enlaces generales al navegador del sistema |
| **Anti-bot / CAPTCHA** | Cloudflare u otros challenges pueden detectar WebView | No intentar evadirlos. Mostrar estado claro y ofrecer “Abrir en navegador” |
| **User-Agent** | Sitio entrega UI degradada o rechaza navegador | Mantener UA nativo primero; cambiarlo solo si hay evidencia reproducible |
| **Portapapeles** | Copiar/pegar puede necesitar permisos/política | El candidato 1 añadió política de clipboard opt-in; habilitar solo lo necesario |
| **Carga de archivos** | Adjuntar imágenes/documentos necesita file chooser | Validar el file selector del plugin; limitarse a interacción iniciada por usuario |
| **Descargas** | El sitio intenta descargar archivos fuera del WebView | En el spike, abrir/derivar a navegador o manejador externo; no construir gestor de descargas |
| **Micrófono/cámara** | Voz o cámara pueden requerir permisos WebKit/backend | Fuera del criterio mínimo. Mantener deshabilitado hasta una fase posterior |
| **GPU / Wayland / drivers** | Pantalla blanca, glitches o incompatibilidad DMA-BUF | Probar sesión Wayland y X11 del hardware objetivo; registrar renderer/driver. Evitar forzar software salvo diagnóstico |
| **Proceso WebKit termina** | La SPA o driver puede tumbar el web process | Mostrar panel recuperable con botón Recargar; el candidato 1 expone terminación anormal |
| **RAM** | ChatGPT/Grok mantienen DOM, historial y JS activos | Un panel en Fase 2. Al cambiar de proveedor, reutilizar o destruir el controlador según medición; no mantener dos WebViews activos hasta Fase 4 |
| **Seguridad** | Web content no confiable comparte capacidades con la app | No exponer bridges Dart/JS privilegiados. Lista de navegación esperada y navegador externo para destinos no necesarios |

## Plan de validación de Fase 1

Probar en este orden:

1. Instalar WPE y confirmar versión.
2. Crear una vista temporal mínima con **un único WebView**.
3. Cargar `https://chatgpt.com`; comprobar render, scroll, teclado, copiar/pegar y envío de mensaje.
4. Completar login si es necesario.
5. Cerrar **todo el proceso** de duo-desktop, reabrir y comprobar sesión.
6. Repetir con `https://grok.x.ai` o la URL oficial vigente.
7. Probar `target=_blank`/OAuth, selector de archivos y recuperación tras reload.
8. Medir memoria en reposo, después de cargar, después del login y tras 10–15 min de conversación.
9. Solo si hay un bloqueo del wrapper, repetir el mismo guion con `flutter_inappwebview`.

### Medición de memoria

No usar únicamente la cifra del proceso Flutter. WebKit usa procesos auxiliares. Registrar como mínimo:

- RSS/PSS de `duo_desktop`;
- procesos WPE/WebKit Web/Network/GPU relacionados;
- total antes de abrir Chats;
- total con un panel vacío;
- total con ChatGPT cargado;
- total con Grok cargado;
- pico después de uso sostenido.

El objetivo no es perseguir una cifra artificialmente baja, sino comparar **delta de memoria atribuible al panel** entre candidatos bajo la misma sesión.

## Hallazgo de implementación — 2026-10-02

### webview_flutter_linux

El primer intento con `webview_flutter` + `webview_flutter_linux` no llegó a runtime por conflicto de dependencias:

```text
Flutter SDK → meta 1.18.0
webview_flutter_linux → hooks → record_use → meta ^1.19.0
```

La salida recomendada es **actualizar Flutter a una stable cuyo framework/tooling ya use meta 1.19.x** y repetir el spike. No se recomienda fijar `dependency_overrides: meta: ^1.19.0` como solución permanente.

### webview_all

Se probó `webview_all ^1.4.4` con WebKitGTK 4.1.

Resultado:

- compila;
- la aplicación abre;
- `onPageStarted` / `onPageFinished` funcionan;
- la UI llega a “Página lista”;
- el área del WebView permanece vacía/transparente;
- el fondo de vídeo de Duo queda visible a través del panel.

El síntoma apunta más a **presentación/composición WebKitGTK** que a navegación. La hipótesis prioritaria es incompatibilidad GPU/DMA-BUF/Wayland-NVIDIA o interacción con la superficie de vídeo de `media_kit`.

Antes de abandonar `webview_all`, ejecutar la matriz de depuración de `NOTAS-IMPLEMENTACION.md`: página trivial, HTML local, vídeo desactivado, `WEBKIT_DISABLE_DMABUF_RENDERER=1`, X11, explicit-sync NVIDIA, clipping/tamaño y MiniBrowser.

### siguiente candidato

Si WebKitGTK funciona fuera de Flutter pero `webview_all` continúa transparente, probar **`flutter_inappwebview` + backend Linux/WPE** manteniendo la misma UI de `PantallaChats` y sustituyendo únicamente la capa de navegador.

## Decisión del spike

**Decisión actual: continuar priorizando WebView embebido.**

Orden:

1. aislar el fallo de render de `webview_all`;
2. si el wrapper queda señalado, migrar a `flutter_inappwebview_linux`/WPE;
3. volver a probar `webview_flutter_linux` después de un upgrade controlado de Flutter compatible con `meta 1.19.x`;
4. mantener navegador externo como fallback, no como solución principal del experimento.

## Fuentes consultadas

- webview_flutter_linux (pub.dev): https://pub.dev/packages/webview_flutter_linux
- API/changelog de webview_flutter_linux: https://pub.dev/packages/webview_flutter_linux/changelog
- flutter_inappwebview_linux (pub.dev): https://pub.dev/packages/flutter_inappwebview_linux
- Flutter InAppWebView (GitHub): https://github.com/pichillilorenzo/flutter_inappwebview
- Backend WPE de InAppWebView: https://github.com/pichillilorenzo/flutter_inappwebview/blob/master/flutter_inappwebview_linux/WPE_BACKEND.md
- webview_linux (pub.dev): https://pub.dev/packages/webview_linux
- flutter_linux_webview/CEF (pub.dev): https://pub.dev/packages/flutter_linux_webview
- Arch Linux wpewebkit: https://archlinux.org/packages/extra/x86_64/wpewebkit/
- Arch Linux webkit2gtk-4.1: https://archlinux.org/packages/extra/x86_64/webkit2gtk-4.1/
- WebKitGTK WebsiteDataManager: https://webkitgtk.org/reference/webkit2gtk/stable/class.WebsiteDataManager.html
- WebKitGTK CookieManager: https://webkitgtk.org/reference/webkit2gtk/stable/class.CookieManager.html
