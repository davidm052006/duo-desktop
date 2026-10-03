# Diseño de la vista “Chats”

> **Rama:** `experiment/chats-webview`  
> **Alcance:** diseño de Fase 2 — un solo panel WebView configurable.  
> **Estado:** listo para implementación posterior.  
> **No incluye código de implementación.**

## 1. Decisión de nombre

El nombre propuesto para la nueva pantalla es **Chats**.

No se recomienda `Agentes en vivo` porque la aplicación ya tiene un destino llamado `Agentes`, usado para otra responsabilidad. Mantener `Chats` evita mezclar:

- agentes internos de Duo;
- ChatGPT/Grok como servicios web externos embebidos.

En navegación:

```text
Workspace
├── Inicio
├── Tablero
├── Tareas
├── Agentes
├── Chats          ← nuevo
├── Preguntas
├── Terminal
├── GitHub
├── Historial
└── Visualizaciones
```

Icono sugerido: `Icons.chat_bubble_outline` o `Icons.forum_outlined`.

---

## 2. Objetivo de la pantalla

`PantallaChats` debe permitir usar **un único WebView activo** que cargue uno de estos proveedores:

- ChatGPT;
- Grok.

El proveedor se selecciona desde la propia pantalla.

La pantalla debe ser explícita cuando:

- todavía está cargando;
- no hay sesión;
- la página no responde;
- el WebView falla;
- el sitio pide abrir una ventana externa;
- no se puede completar el login embebido.

Nunca debe mostrar un estado de “conectado”, “sesión iniciada” o “listo” si no existe una señal real que lo confirme.

---

# 3. Estructura visual

## Layout general

La vista usa toda el área central que actualmente entrega `MarcoApp`.

```text
┌──────────────────────────────────────────────────────────────┐
│ Chats                                                        │
│ Usa ChatGPT o Grok dentro de Duo.                            │
├──────────────────────────────────────────────────────────────┤
│ [ ChatGPT ] [ Grok ]              ⟳   Abrir en navegador ↗  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                                                              │
│                     PANEL WEBVIEW                            │
│                                                              │
│                                                              │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│ ● Cargando chatgpt.com...                                    │
└──────────────────────────────────────────────────────────────┘
```

El encabezado y la barra de herramientas pertenecen a Flutter.

Solo la zona central pertenece al WebView.

Esto garantiza que el usuario siempre conserva:

- selector de proveedor;
- botón de recarga;
- fallback a navegador;
- mensajes de estado;

aunque el contenido web esté roto.

---

## 3.1 Encabezado

Contenido:

```text
Chats
ChatGPT y Grok sin salir de Duo.
```

Estilo:

- fondo heredado de la superficie actual;
- título con `tintaPrincipal`;
- descripción con `tintaSecundaria`;
- sin crear un color específico para Chats.

Debe verse como otra pantalla nativa de Duo, no como un navegador incrustado aparte.

---

## 3.2 Selector de proveedor

Para Fase 2 se recomienda un **control segmentado con aspecto de pestañas**:

```text
[ ChatGPT ] [ Grok ]
```

No tabs reales con dos vistas vivas.

Razón: durante esta fase solo debe existir **un WebView activo**.

### Estado seleccionado

Usar:

- borde o fondo suave con `paleta.acento`;
- texto activo con `paleta.acento`;
- proveedor no seleccionado con `tintaSecundaria`.

En modo oscuro actual:

- rosa: `paleta.acento = #FF8FC4`;
- cian: `paleta.acentoAlt = #5CD7F2`.

No usar rosa/cian para “identificar” ChatGPT y Grok permanentemente. En la arquitectura actual esos acentos son semánticos de interfaz, no colores de identidad de agentes.

### Cambio de proveedor

Al pulsar otro proveedor:

1. cambiar el proveedor seleccionado;
2. cambiar el estado a `cargando`;
3. navegar/recrear el único WebView según decida la implementación;
4. actualizar el estado únicamente con callbacks reales del motor.

No simular una transición exitosa.

---

## 3.3 Barra de acciones

A la derecha del selector:

### Recargar

Icono:

`Icons.refresh`

Tooltip:

`Recargar página`

Comportamiento:

- habilitado cuando existe un controlador WebView;
- reinicia carga del proveedor actual;
- cambia estado visual a cargando mientras el motor informa progreso.

### Abrir en navegador

Texto recomendado:

`Abrir en navegador`

Icono:

`Icons.open_in_new`

Debe estar **siempre visible**.

Es una salida de seguridad funcional, no una opción secundaria escondida en un menú.

Abre la URL base del proveedor seleccionado en el navegador del sistema.

Ejemplos:

- ChatGPT → `https://chatgpt.com`;
- Grok → URL oficial confirmada durante implementación.

Si el WebView está navegando por un login especial, el fallback puede abrir la URL actual únicamente si la implementación puede obtenerla de forma fiable.

---

## 3.4 Contenedor del WebView

El WebView ocupa todo el espacio restante.

Estructura visual:

```text
ClipRRect / contenedor
└── Stack
    ├── WebView
    ├── overlay de carga       (cuando corresponda)
    └── panel de error         (cuando corresponda)
```

Borde:

- `paleta.rejilla`;
- radio consistente con los paneles actuales;
- fondo inicial `paleta.panel`.

El contenido web mantiene el tema que ofrezca el sitio. No se inyectará CSS para obligar ChatGPT/Grok a imitar exactamente Duo durante este spike.

---

## 3.5 Indicador inferior de estado

Propuesta:

```text
● Cargando chatgpt.com...
```

o:

```text
✓ Página lista
```

o:

```text
! No se pudo cargar la página
```

Debe ser discreto.

Semántica de color:

| Estado | Color |
|---|---|
| iniciando / cargando | `paleta.acentoAlt` |
| listo | `paleta.bien` o tinta neutra |
| advertencia | `paleta.aviso` |
| error recuperable | `paleta.grave` |
| fallo técnico grave | `paleta.critico` |

El color nunca será la única señal: acompañar siempre con texto e icono.

---

# 4. Estados posibles de la vista

No conviene usar un único booleano `isLoading`.

Se propone modelar un estado visual explícito.

## 4.1 Inicializando

Significado:

> Flutter está creando/configurando el WebView.

UI:

```text
Preparando WebView…
```

Mostrar spinner pequeño o `LinearProgressIndicator`.

No mostrar aún “ChatGPT conectado”.

---

## 4.2 Cargando

Significado:

> El motor informó que una navegación está en curso.

UI:

```text
Cargando chatgpt.com…
```

o:

```text
Cargando grok.x.ai…
```

Usar cian informativo.

El WebView puede permanecer visible mientras carga.

---

## 4.3 Listo

Significado:

> El WebView informó que terminó la navegación principal.

Esto **no significa que el usuario tenga sesión iniciada**.

Texto:

```text
Página lista
```

Importante: no usar `Sesión activa` salvo que exista una señal fiable que lo confirme.

---

## 4.4 Sin sesión / login visible

Este estado debe tratarse con cuidado.

El wrapper WebView no necesariamente sabe si el usuario está autenticado.

Por tanto hay dos niveles:

### Detectable

Si existe una señal robusta y estable del sitio:

```text
Inicio de sesión requerido
```

### No detectable

Si no existe una señal robusta:

mantener simplemente:

```text
Página lista
```

y dejar que el propio sitio muestre su login.

**No inferir sesión por URL, por tiempo de carga o por la presencia de una cookie genérica.**

---

## 4.5 Error de navegación

Ejemplos:

- DNS;
- conexión rechazada;
- timeout;
- fallo HTTP grave disponible mediante callback.

UI:

```text
No se pudo cargar ChatGPT

El WebView informó un error de red.
[ Reintentar ]  [ Abrir en navegador ]
```

Mostrar mensaje técnico resumido opcional debajo, sin transformar un código desconocido en una causa inventada.

---

## 4.6 WebView no disponible

Ejemplo:

- WPE WebKit no está instalado;
- inicialización nativa falla.

UI:

```text
El WebView no está disponible

Duo no pudo iniciar el motor web de Linux.
Puedes seguir usando este servicio en tu navegador.

[ Abrir en navegador ]
```

Si se dispone del error real:

```text
Detalle: <mensaje original resumido>
```

No decir automáticamente “falta WPE” salvo que el error realmente lo indique.

---

## 4.7 Proceso web terminado

WebKit puede finalizar un proceso auxiliar.

UI:

```text
El contenido web dejó de responder

El proceso del WebView terminó inesperadamente.

[ Recargar ]
[ Abrir en navegador ]
```

La implementación debe intentar recrear el controlador si una simple recarga no es válida.

---

## 4.8 Login externo requerido

Puede ocurrir con Google, Microsoft, X u otro OAuth.

UI:

```text
Este inicio de sesión necesita abrirse fuera de Duo.

[ Continuar en navegador ]
```

No presentar esto como fallo de cuenta.

No intentar saltarse restricciones de OAuth cambiando artificialmente el user-agent sin evidencia de que sea apropiado.

---

## 4.9 Popup / ventana nueva

Cuando la página intente `window.open` o `target=_blank`:

- si forma parte de un flujo soportado de login, la implementación decidirá si abre un WebView relacionado;
- para navegación externa general, abrir navegador del sistema.

Mientras no exista soporte probado:

```text
Este enlace se abrirá en tu navegador.
```

---

## 4.10 Sin conexión

No crear un detector paralelo de red salvo que sea necesario.

Si el WebView informa fallo de red:

```text
No se pudo conectar al sitio.
```

Evitar afirmar:

```text
No tienes Internet
```

porque el error podría pertenecer al sitio, DNS, proxy o WebKit.

---

# 5. Árbol de widgets propuesto

Diseño conceptual, no implementación:

```text
PantallaChats
└── Padding
    └── Column
        ├── _EncabezadoChats
        │   ├── Text("Chats")
        │   └── Text("ChatGPT y Grok sin salir de Duo.")
        │
        ├── SizedBox
        │
        ├── _BarraChats
        │   └── Row
        │       ├── _SelectorProveedor
        │       │   ├── ChatGPT
        │       │   └── Grok
        │       ├── Spacer
        │       ├── _BotonRecargar
        │       └── _BotonAbrirNavegador
        │
        ├── SizedBox
        │
        ├── Expanded
        │   └── _MarcoWebChat
        │       └── Stack
        │           ├── WebViewWidget
        │           ├── _IndicadorCarga
        │           └── _PanelError
        │
        ├── SizedBox
        │
        └── _EstadoChatWeb
```

Los widgets privados pueden empezar dentro de `pantalla_chats.dart`.

No extraer cada pieza a archivos independientes hasta que la implementación demuestre que realmente lo necesita.

---

# 6. Modelo mínimo de proveedor

Conceptualmente:

```text
ProveedorChat
├── nombre
├── urlInicial
└── hostVisible
```

Valores:

```text
ChatGPT
└── https://chatgpt.com

Grok
└── URL oficial vigente
```

No guardar cookies, tokens o estado de autenticación dentro de este modelo.

---

# 7. Modelo visual de estado

Conceptualmente:

```text
EstadoChatWeb
├── inicializando
├── cargando
├── listo
├── errorNavegacion
├── webViewNoDisponible
├── procesoTerminado
└── requiereNavegadorExterno
```

Opcionalmente cada estado puede transportar:

- mensaje real;
- código de error;
- URL implicada;
- acción recuperable.

No crear estados como:

- `autenticado`;
- `cuentaPremium`;
- `ChatGPTOnline`;

hasta contar con una fuente fiable que realmente los confirme.

---

# 8. Integración en la navegación actual

Actualmente `MarcoApp` usa:

1. `destinosTrabajo`;
2. un índice `_activo`;
3. un `switch` sobre `destinos[_activo].nombre`.

La integración mínima propuesta es:

## Paso 1

Añadir import conceptual:

```text
pantalla_chats.dart
```

## Paso 2

Añadir después de `Agentes`:

```text
Destino('Chats', Icons.chat_bubble_outline)
```

Orden recomendado:

```text
Inicio
Tablero
Tareas
Agentes
Chats
Preguntas
Terminal
GitHub
Historial
Visualizaciones
```

Esto deja Chats cerca de Agentes, pero sin mezclarlos.

## Paso 3

Añadir caso al `switch`:

```text
'Chats' → PantallaChats
```

No hace falta:

- introducir Navigator 2.0;
- crear rutas nombradas;
- cambiar `EstadoTablero`;
- tocar Provider global;
- modificar el servicio C#.

---

# 9. Archivos propuestos

El requisito pide mantener la integración en `app/lib/src/pantallas/`.

Para la primera implementación:

```text
app/lib/src/pantallas/
├── marco_app.dart
└── pantalla_chats.dart       ← nuevo
```

Si el código WebView empieza a crecer, entonces:

```text
app/lib/src/pantallas/
├── marco_app.dart
├── pantalla_chats.dart
└── chats/
    ├── proveedor_chat.dart
    └── controlador_chat_web.dart
```

Sin embargo, para respetar la estructura actual del proyecto se recomienda **empezar únicamente con `pantalla_chats.dart`** y extraer después.

Archivos adicionales que previsiblemente cambiarán durante implementación:

```text
app/pubspec.yaml
app/pubspec.lock
```

Los archivos Linux/CMake solo deben tocarse si el paquete WebView realmente lo exige.

No modificar:

```text
service/
app/lib/src/estado/estado_tablero.dart
app/lib/src/datos/
```

---

# 10. Ciclo de vida del panel

## Entrada a Chats

```text
usuario abre Chats
      ↓
crear controlador
      ↓
estado = inicializando
      ↓
cargar proveedor
      ↓
estado = cargando
      ↓
callback real del WebView
      ↓
estado = listo o error
```

## Cambio ChatGPT → Grok

```text
selector cambia
      ↓
estado = cargando
      ↓
mismo WebView navega a la nueva URL
      ↓
callback real
```

En Fase 2 se recomienda **reutilizar un solo controlador** inicialmente.

Si aparecen fugas, estado cruzado extraño o memoria excesiva, probar destruir/recrear al cambiar proveedor.

## Salida de Chats

La política final debe decidirse con medición.

Dos opciones:

### A. conservar WebView

Ventaja:

- vuelta instantánea;
- scroll/DOM conservados.

Costo:

- RAM retenida incluso fuera de Chats.

### B. destruir WebView

Ventaja:

- libera memoria de forma más agresiva.

Costo:

- recarga al volver.

Dado que el hardware objetivo es modesto, el spike debe medir ambas y no decidir por intuición.

---

# 11. Tema visual

La pantalla debe consumir únicamente `context.paleta`.

## Superficies

- fondo: `paleta.superficie`;
- barras/paneles: `paleta.panel`;
- divisores: `paleta.rejilla`.

## Texto

- principal: `paleta.tintaPrincipal`;
- secundario: `paleta.tintaSecundaria`;
- deshabilitado: `paleta.tintaTenue`.

## Interacción

- selector activo / acción relevante: `paleta.acento` — rosa;
- carga/información: `paleta.acentoAlt` — cian.

## Estados

- correcto: `paleta.bien`;
- advertencia: `paleta.aviso`;
- error: `paleta.grave`;
- error crítico: `paleta.critico`.

No definir constantes hexadecimales dentro de `pantalla_chats.dart`.

---

# 12. Filosofía de errores

La pantalla aplica la misma regla de Duo:

> mostrar lo que sabemos, no lo que suponemos.

Ejemplos:

### Correcto

```text
No se pudo cargar la página.
Error informado por WebView: conexión rechazada.
```

### Incorrecto

```text
ChatGPT está caído.
```

salvo que exista una señal externa real que lo confirme.

### Correcto

```text
Página lista.
```

### Incorrecto

```text
Sesión iniciada.
```

si solo terminó `onPageFinished`.

### Correcto

```text
El WebView terminó inesperadamente.
```

### Incorrecto

```text
Tu GPU falló.
```

si esa causa no está demostrada.

---

# 13. Tareas de implementación

Orden diseñado para Grok/Codex.

## Tarea 1 — Dependencias

- [ ] Instalar/verificar `wpewebkit` en Arch.
- [ ] Añadir `webview_flutter`.
- [ ] Añadir `webview_flutter_linux`.
- [ ] Ejecutar `flutter pub get`.
- [ ] Confirmar que la app Linux compila antes de tocar UI.

**Criterio:** build limpio con plugin registrado.

---

## Tarea 2 — Crear pantalla vacía

Crear:

```text
app/lib/src/pantallas/pantalla_chats.dart
```

Inicialmente solo:

- título Chats;
- texto descriptivo;
- selector ChatGPT/Grok;
- botón Abrir en navegador;
- placeholder del WebView.

**Criterio:** pantalla renderiza con tema actual y sin WebView aún.

---

## Tarea 3 — Integrar navegación

Modificar `marco_app.dart`:

- [ ] importar `pantalla_chats.dart`;
- [ ] añadir `Destino('Chats', ...)`;
- [ ] añadir caso `Chats` al switch;
- [ ] confirmar selección correcta en sidebar.

**Criterio:** entrar/salir de Chats no afecta las demás pantallas.

---

## Tarea 4 — Modelo de proveedor

Crear dentro de `pantalla_chats.dart` inicialmente:

- [ ] proveedor ChatGPT;
- [ ] proveedor Grok;
- [ ] URL inicial de cada uno;
- [ ] selector local.

No persistir selección aún salvo que resulte útil.

**Criterio:** selector cambia la intención de navegación.

---

## Tarea 5 — Inicializar WebView

- [ ] crear un único controlador;
- [ ] habilitar JavaScript;
- [ ] configurar delegates/callbacks;
- [ ] cargar ChatGPT por defecto;
- [ ] renderizar `WebViewWidget`.

**Criterio:** ChatGPT muestra contenido real.

---

## Tarea 6 — Estado real de carga

Conectar callbacks del WebView:

- [ ] navegación iniciada → cargando;
- [ ] navegación terminada → listo;
- [ ] error → errorNavegacion;
- [ ] proceso terminado → procesoTerminado, si el plugin lo expone.

No usar delays artificiales para marcar `listo`.

**Criterio:** la UI refleja eventos reales.

---

## Tarea 7 — Selector ChatGPT/Grok

Al cambiar:

- [ ] mantener un solo WebView;
- [ ] cargar URL del nuevo proveedor;
- [ ] reiniciar estado a cargando;
- [ ] verificar navegación de ida y vuelta.

**Criterio:** nunca quedan dos WebViews activos.

---

## Tarea 8 — Recarga

- [ ] añadir botón recargar;
- [ ] conectar con controlador;
- [ ] reflejar estado cargando.

**Criterio:** recupera fallo simple sin recrear toda la pantalla.

---

## Tarea 9 — Fallback externo

- [ ] implementar apertura de URL en navegador del sistema;
- [ ] botón siempre visible;
- [ ] comprobar ChatGPT;
- [ ] comprobar Grok.

**Criterio:** aunque el WebView falle, el usuario puede continuar.

---

## Tarea 10 — Panel de errores

Implementar mensajes separados para:

- [ ] error de navegación;
- [ ] WebView no disponible;
- [ ] proceso WebKit terminado;
- [ ] login externo requerido cuando se detecte realmente.

Acciones:

- [ ] Reintentar;
- [ ] Abrir en navegador.

**Criterio:** ningún fallo termina en pantalla vacía sin explicación.

---

## Tarea 11 — Popups y navegación externa

- [ ] detectar `target=_blank` / `window.open` si el plugin lo permite;
- [ ] registrar qué dominios aparecen durante login;
- [ ] abrir destinos generales en navegador;
- [ ] no crear allowlist final hasta observar flujos reales.

**Criterio:** no perder silenciosamente ventanas nuevas.

---

## Tarea 12 — Login ChatGPT

Probar manualmente:

- [ ] login normal;
- [ ] OAuth si aplica;
- [ ] cerrar app completamente;
- [ ] abrir de nuevo;
- [ ] verificar si la sesión persiste.

Registrar resultado en documentación.

**Criterio:** saber si persistencia funciona; no exigir todavía solucionarla si corresponde a Fase 3.

---

## Tarea 13 — Login Grok

Repetir exactamente el mismo protocolo.

**Criterio:** comparación bajo condiciones equivalentes.

---

## Tarea 14 — Interacciones esenciales

Comprobar:

- [ ] teclado;
- [ ] scroll;
- [ ] seleccionar texto;
- [ ] copiar;
- [ ] pegar;
- [ ] links;
- [ ] selector de archivos si el sitio lo solicita.

**Criterio:** chat utilizable para una conversación real.

---

## Tarea 15 — Medición de memoria

Medir:

1. Duo sin Chats;
2. Chats abierto sin sitio cargado;
3. ChatGPT listo;
4. Grok listo;
5. conversación después de 10–15 min;
6. después de salir de Chats.

Registrar proceso Flutter + procesos WPE.

**Criterio:** disponer de delta de memoria real.

---

## Tarea 16 — Decidir ciclo de vida

Comparar:

- mantener WebView al salir;
- destruir al salir.

Elegir según:

- memoria;
- rapidez al volver;
- estabilidad;
- persistencia de sesión.

**Criterio:** decisión documentada, no intuitiva.

---

## Tarea 17 — Tests Flutter posibles

No intentar testear el motor WPE completo con widget tests si no es viable.

Sí cubrir:

- [ ] selector de proveedor;
- [ ] render de mensajes de estado;
- [ ] acciones habilitadas/deshabilitadas;
- [ ] panel de error;
- [ ] integración de destino Chats en navegación, si el test actual lo permite.

La carga real de ChatGPT/Grok debe tratarse como validación manual/integración de Linux.

---

# 14. Fuera de alcance para esta fase

No implementar todavía:

- dos WebViews simultáneos;
- split ChatGPT | Grok;
- pestañas reales con WebViews vivos;
- historial propio;
- sincronización entre chats;
- lectura automática del contenido de las conversaciones;
- inyección de prompts;
- bridge JS privilegiado;
- scraping del DOM;
- gestor de descargas;
- cámara;
- micrófono;
- login gestionado por Duo;
- almacenamiento manual de tokens;
- CEF.

---

# 15. Criterios de aceptación de Fase 2

La vista se considera terminada cuando:

- [ ] aparece `Chats` en el Workspace;
- [ ] respeta la paleta actual rosa/cian;
- [ ] existe un solo WebView;
- [ ] se puede seleccionar ChatGPT o Grok;
- [ ] el proveedor seleccionado carga o muestra un error real;
- [ ] existe indicador de carga;
- [ ] existe botón de recarga;
- [ ] existe fallback permanente a navegador;
- [ ] ningún error importante deja un panel vacío;
- [ ] no se afirma que existe sesión sin evidencia;
- [ ] entrar/salir de Chats no altera el servicio C#;
- [ ] el comportamiento y consumo observados quedan documentados.

---

# 16. Evolución posterior

Si Fase 2 funciona:

### Fase 3

Persistencia de cookies/data store y validación formal de sesión.

### Fase 4

Añadir segundo panel.

Antes de elegir split o pestañas habrá que responder:

- cuánto cuesta en RAM mantener dos WebViews;
- si los dos continúan ejecutando JS en segundo plano;
- si conviene suspender/destruir el panel no visible;
- si el ancho disponible sigue siendo usable para las interfaces responsive de ChatGPT y Grok.

La arquitectura actual no debe comprometer esa decisión antes de tener esas mediciones.
