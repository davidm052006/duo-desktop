# Diseño de alto nivel: vista “Chats”

> **Rama:** `experiment/chats-webview`  
> **Alcance:** Fase 2, un solo panel.  
> **No contiene implementación.**

## Objetivo

Añadir a duo-desktop una vista `Chats` que aloje **un único WebView activo** y permita validar ChatGPT o Grok sin alterar el servicio C#, el estado del tablero ni el resto de pantallas.

El primer diseño debe optimizar aislamiento y capacidad de descarte: si el experimento falla, quitar la vista no debe dejar arquitectura transversal innecesaria.

## Encaje con la aplicación actual

La navegación actual se concentra en `app/lib/src/pantallas/marco_app.dart` mediante la lista de `Destino` y un `switch` que selecciona cada pantalla.

Para el prototipo se propone:

```text
MarcoApp
└── destino "Chats"
    └── PantallaChats
        ├── BarraChats
        │   ├── selector ChatGPT / Grok
        │   ├── Recargar
        │   └── Abrir en navegador
        └── PanelWebChat
            ├── estado cargando
            ├── WebView único
            └── estado de error / recuperación
```

No introducir rutas, router global ni un nuevo gestor de estado solo para este spike.

## Responsabilidades

### `PantallaChats`

Responsable de composición visual y del proveedor seleccionado.

Estado mínimo local:

- proveedor actual: ChatGPT o Grok;
- estado visual: iniciando / cargando / listo / error;
- URL visible o destino actual si resulta útil para diagnóstico.

No debe conocer detalles nativos de WPE.

### Adaptador/controlador WebView

Una capa pequeña encapsula la dependencia elegida. Aunque inicialmente sea un solo archivo, conviene evitar llamadas Linux-específicas dispersas por la pantalla.

Responsabilidades:

- crear/destruir controlador;
- activar JavaScript;
- cargar URL;
- navegación atrás/recarga;
- decidir qué navegaciones permanecen embebidas;
- manejar `window.open`/nueva ventana si la API lo permite;
- reportar errores y terminación del proceso web;
- exponer únicamente las capacidades que la UI necesita.

No exponer un bridge JavaScript privilegiado a ChatGPT/Grok.

### Apertura externa

Los destinos no necesarios para el funcionamiento del chat deben poder salir al navegador del sistema. El fallback también debe estar disponible cuando el WebView falle.

Si la app aún no tiene una abstracción para abrir URLs, crearla solo durante implementación y mantenerla pequeña.

## Política de un solo panel

Durante Fase 2 debe existir **un solo WebView vivo**.

Al cambiar ChatGPT ↔ Grok hay dos estrategias a medir:

1. **Reutilizar el mismo controlador y navegar a la otra URL**: menor memoria, pierde estado de página en memoria pero conserva almacenamiento persistente.
2. **Destruir y recrear controlador**: aislamiento más claro y libera recursos con mayor determinismo.

Para el primer prototipo se favorece **un controlador activo a la vez**. No conservar ChatGPT y Grok ocultos simultáneamente hasta que la medición de Fase 4 justifique dos procesos/paneles.

## Persistencia

La sesión no debe guardarse manualmente en `SharedPreferences`.

Cookies, localStorage, IndexedDB, Service Workers y caches pertenecen al data store de WebKit. La implementación debe usar un almacén **persistente, no efímero**, con ubicación estable de aplicación/perfil.

Reglas:

- no copiar tokens desde el DOM;
- no serializar cookies a Dart salvo necesidad demostrada;
- no mezclar secretos del WebView con configuración general;
- ofrecer en el futuro “Cerrar sesión / limpiar datos” mediante APIs del data store, no borrando archivos a mano.

## Navegación y seguridad

Política inicial:

- permitir navegación principal necesaria dentro de `chatgpt.com`, `openai.com` y dominios de Grok/xAI que aparezcan legítimamente en el flujo;
- los proveedores OAuth se evalúan caso por caso porque algunos rechazan WebViews embebidos;
- enlaces arbitrarios externos → navegador del sistema;
- no ignorar errores TLS;
- no desactivar sandbox/seguridad del motor para hacer funcionar un login;
- no inyectar scripts para saltar challenges anti-bot.

La lista exacta de hosts permitidos debe salir de la prueba real, no de suposiciones.

## UX mínima

La pantalla debe incluir:

- selector simple **ChatGPT / Grok**;
- indicador de carga no intrusivo;
- botón **Recargar**;
- botón **Abrir en navegador** siempre disponible;
- mensaje de error con acción de reintento;
- opcional para diagnóstico: URL/host actual en modo debug.

No implementar todavía pestañas, split view, historial propio, bookmarks, descargas ni barra de direcciones general.

## Ciclo de vida

Al entrar a Chats:

1. crear/inicializar el controlador si no existe;
2. cargar el proveedor seleccionado;
3. mostrar progreso hasta navegación lista.

Al salir de Chats hay que **medir** dos comportamientos antes de fijar política:

- mantener el controlador para preservar DOM/scroll y volver instantáneamente;
- disponerlo para liberar RAM.

`webview_flutter_linux` declara preservación de estado al desmontar/reanudar y también `dispose()` explícito. En hardware modesto, la política final debe decidirse por medición. Para la Fase 2, favorecer liberación determinista si mantener el WebView oculto incrementa de forma importante el consumo.

## Archivos previstos para la implementación

Estructura mínima sugerida:

```text
app/lib/src/pantallas/
└── pantalla_chats.dart

app/lib/src/chats/
├── proveedor_chat.dart
└── controlador_chat_web.dart
```

Si la integración resulta suficientemente simple, `proveedor_chat.dart` puede permanecer dentro de `pantalla_chats.dart`; no crear capas por anticipado.

Cambios esperados fuera de esos archivos:

- `app/pubspec.yaml`: dependencias WebView;
- `app/lib/src/pantallas/marco_app.dart`: destino/import/switch;
- Linux/CMake: **solo** si el paquete finalmente lo exige; el candidato principal pretende apoyarse en native assets/runtime WPE.

No tocar:

- `service/`;
- modelos de tablero;
- cliente HTTP del servicio;
- contratos de agentes.

## Estados de error mínimos

```text
Sin motor WPE
    → explicar dependencia faltante + abrir navegador

Fallo de red
    → reintentar + abrir navegador

Web process terminado
    → recrear/recargar + abrir navegador

Login no soportado
    → abrir flujo externo; documentar si la sesión puede volver al WebView

Sitio incompatible
    → fallback a navegador; registrar el caso antes de cambiar de motor
```

## Criterio de éxito de la vista

La Fase 2 se considera exitosa si, con **un solo panel**:

- la pantalla entra/sale sin crash;
- ChatGPT o Grok renderiza e interactúa correctamente;
- teclado, scroll y portapapeles básico funcionan;
- existe recuperación de error y fallback externo;
- no se introdujo dependencia de CEF;
- el delta de memoria queda medido y documentado.

La persistencia completa de login se valida formalmente en Fase 3.

## Evolución si el spike funciona

Solo después de validar un panel:

1. decidir si el segundo proveedor usa pestañas o split;
2. medir dos WebViews simultáneos;
3. definir política de suspensión/destrucción del panel oculto;
4. agregar limpieza de datos/sesión;
5. evaluar permisos multimedia y descargas únicamente si son requisitos reales.

La arquitectura de Fase 2 no debe asumir que el resultado final tendrá dos WebViews vivos.
