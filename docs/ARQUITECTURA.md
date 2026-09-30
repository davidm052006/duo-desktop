# Arquitectura y decisiones

Cada decisión de aquí tiene un motivo. Si el motivo deja de ser cierto, la
decisión se puede revisar.

## El patrón: backend local

```
┌──────────────────────┐        ┌─────────────────────────┐
│  Flutter desktop     │  HTTP  │  Servicio C# (.NET 10)  │
│  (toda la UI)        │◄──────►│  ASP.NET Core minimal   │
│                      │   WS   │                         │
│  temas, vídeo,       │        │  dominio, pizarra,      │
│  gráficas, terminal  │        │  GitHub, procesos       │
└──────────────────────┘        └─────────────────────────┘
        │                                  │
        └──── lanza como proceso hijo ─────┘
```

Flutter arranca el binario del servicio al abrir, en `127.0.0.1` con puerto
efímero y un token en la cabecera. Al cerrar, lo termina. Para quien usa la
app, es un solo programa.

- **HTTP** para lo que se pide una vez: `GET /board`, `POST /tasks`.
- **WebSocket** para lo que llega en vivo: salida del agente, cambios de
  estado, preguntas.

## Reparto de responsabilidades

**Servicio C#** — la lógica, porque es donde está el aprendizaje:

- Dominio: `Task`, `Agent`, `Question`, `Answer`, `Ledger`, `Router`.
- Leer y escribir la pizarra `.team/`.
- Git y GitHub: `LibGit2Sharp` + `Octokit`.
- Lanzar los agentes y difundir su salida.

**App Flutter** — todo lo visual:

- Tablero, tematización, fuentes, colores, fondos de vídeo.
- Gráficas del reparto (`CustomPainter` o `fl_chart`).
- Terminal integrada con `xterm.dart` + `flutter_pty`.
- Ventanas de preguntas, con el tamaño y el scroll bajo control.

## Decisiones que ya se tomaron, y por qué

### El servicio invoca al `duo` que ya existe, no lo reimplementa

`duo` funciona y está probado: el router, el ledger, el canal de preguntas.
Reescribirlo en C# el primer día significa tres meses sin nada que mirar.
El servicio lo llama como proceso y lee su pizarra, que ya es markdown y TSV
en git — o sea, **la pizarra ya es la API**.

Portar el motor a C# es un ejercicio para más adelante, sin prisa y con la app
ya en pie.

### Konsole no se embebe

Wayland no tiene XEmbed, y Konsole solo se embebe en aplicaciones Qt/KDE.
En su lugar: PTY real renderizado con `xterm.dart` + `flutter_pty` dentro de
Flutter. Los agentes corren en una terminal de verdad; el render es nuestro.

### No hay navegador embebido

Chromium embebido son +150MB y se nota en un i5-7200U. Para probar
`localhost` se controla el Chrome del sistema por Chrome DevTools Protocol
(`PuppeteerSharp` desde el servicio). Más capacidad, cero peso.

### El chat de ChatGPT no se automatiza

Automatizar su interfaz web va contra los términos de OpenAI y pone en riesgo
la cuenta, además de romperse con cada cambio de DOM.

El canal legítimo ya está resuelto en `duo`: ChatGPT lee su brief desde la
rama `team/board` por su conector de GitHub y escribe su entregable ahí
mismo. El único paso manual es pegar una línea, y ese paso se queda.

### No se usa FFI entre Flutter y C#

`dart:ffi` contra una librería NativeAOT es posible, pero el marshalling de
cadenas y los callbacks asíncronos cuestan más de lo que aportan. Dos
procesos y HTTP es más simple y más honesto.

## Seguridad del canal local

El servicio escucha **solo** en `127.0.0.1` y exige un token que Flutter le
pasa al arrancar. Sin eso, cualquier proceso de la máquina podría mandarle
órdenes a los agentes.
