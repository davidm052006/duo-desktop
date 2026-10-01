# Informe de avance — 2026-09-30

Qué hay construido de verdad, qué falta, y qué está bloqueado. Escrito desde
el código, no desde el plan.

## Resumen en una línea

La documentación estaba completa y la Fase 1 estaba al 0%: el servicio era el
`Hello World!` de `dotnet new web` y la app era el contador de `flutter create`.
Esta tarea deja la Fase 1 en pie y funcionando contra la pizarra real.

---

## 1. Dónde estábamos

| Pieza | Antes de T-005 | Realidad |
|---|---|---|
| `docs/ARQUITECTURA.md` | completo | Decisiones tomadas y razonadas. Nada que corregir. |
| `docs/FASES.md` | completo | Plan de 7 fases, cada una entregable por sí sola. |
| `docs/api/CONTRATO_BOARD.md` | entregado por `chat` (T-002) | 787 líneas. Rechazado por `codex` en T-003 por una incompatibilidad de cabecera. |
| `service/` | `app.MapGet("/", () => "Hello World!")` | Plantilla intacta. Cero dominio. |
| `app/` | el contador morado de la plantilla | Plantilla intacta. Las dependencias (`http`, `provider`, `web_socket_channel`) sí estaban puestas. |
| `scripts/bootstrap.fish`, `dev.fish` | funcionando | Puerto efímero + token compartido, tal como manda la arquitectura. |

O sea: tres tareas cerradas, todas de papel. La primera línea de código del
producto es esta.

## 2. Lo que la documentación espera de duo-desktop

Releída entera, la intención es consistente y vale la pena dejarla escrita:

- **Es la cara gráfica de un `duo` que ya funciona**, no una reimplementación.
  El servicio invoca al CLI y lee su pizarra; portar el motor a C# es un
  ejercicio para más adelante (`ARQUITECTURA.md`).
- **Dos procesos hablando por HTTP y WebSocket en loopback**, con token. C# para
  aprender, Flutter para la velocidad visual. Ni FFI, ni navegador embebido, ni
  Konsole embebida.
- **La pizarra ya es la API**: markdown y TSV versionados en git.
- **El objetivo que no se dice en voz alta** pero está en `FASES.md` §6-7: que
  esto se pueda enseñar. La visualización del reparto y el acabado visual no son
  adorno, son la razón de que alguien mire el proyecto dos veces.
- **Se construye con `duo` mismo**, y ese es medio portafolio: tres agentes
  repartidos por fortaleza, nadie revisa su propio trabajo.

Nada de eso ha cambiado. Lo construido en T-005 lo respeta punto por punto.

## 3. Dos cosas que el contrato daba por sentadas y no son ciertas

### 3.1 `.team/` no está donde el contrato dice

El contrato (§1) fija como fuente de verdad:

```text
.team/BOARD.md
.team/ledger.tsv
```

relativos al "proyecto activo". Pero `duo init` **no** deja la pizarra junto al
código: la pone en una rama aparte (`team/board`) con su propio worktree. Para
este proyecto:

```text
repo      /home/david/dev/activo/duo-desktop        ← no contiene .team/
pizarra   /home/david/dev/wt/board-duo-desktop/.team ← aquí está
```

La ruta real vive en `~/.config/duo/<slug>.conf`, en la variable `BOARD`. Un
servicio que buscara `.team/` junto al código devolvería `404 board_not_found`
siempre, en los tres worktrees y en el repo principal.

**Resuelto:** `service/Duo/DuoProject.cs` lee las `*.conf` de `duo` como texto
(no las ejecuta) y resuelve el proyecto activo con la misma regla que el CLI:
`DUO_P` manda; si no, el único proyecto; si hay varios, aquel a cuyo repo,
pizarra o worktree pertenezca el directorio actual.

El contrato debería corregirse en este punto. No es un fallo de diseño: es que
el detalle no se podía ver sin ejecutar nada.

### 3.2 La cabecera de autenticación seguía sin decidirse

`codex` bloqueó T-002 por esto, y con razón:

- el contrato fija `Authorization: Bearer <token>` (§2);
- `scripts/dev.fish:35` enseña `X-Duo-Token: <token>`.

**Resuelto de momento aceptando las dos** en el servicio, con comparación en
tiempo constante. Así ni el script ni el contrato mienten y nadie queda
bloqueado. La app Flutter manda `Bearer`, que es lo que dice el contrato.
Elegir cuál es *la* canónica y quitar la otra sigue siendo decisión tuya.

## 4. Lo que queda por fase

### Fase 1 — El tablero se ve · **hecha**

- `GET /board` leyendo `BOARD.md` y `ledger.tsv`, con los cinco códigos del
  contrato (200/401/404/422/500) y la envoltura de error acordada.
- App Flutter con la tabla de tareas y las barras de carga por agente, tema
  claro y oscuro, refresco cada 5 s y estados de fallo explicados.
- 26 tests en Dart. El servicio verificado a mano contra la pizarra real y
  contra pizarras rotas a propósito.

Queda fuera, a propósito: **tests automáticos del servicio C#**. No hay proyecto
de test en la solución. Es lo primero que haría falta antes de seguir, y es
trabajo acotado — perfil de `codex`.

### Fase 2 — Lanzar y ver · pendiente

- `POST /tasks` que ejecute `duo "<texto>"` y difunda su salida por WebSocket.
- En Flutter, el campo de tarea y el panel de salida en vivo.
- Hay una decisión de diseño sin tomar: `duo` lanza a los agentes en terminales
  propias y captura su sesión en `.team/sesiones/T-NNN.txt`. ¿El servicio sigue
  ese archivo, o reemplaza el lanzamiento por uno propio? Lo primero es mucho
  más barato y respeta "el servicio no reimplementa `duo`".

### Fase 3 — Preguntas como objetos · pendiente

Es la fase que arregla un dolor real: `kdialog` recortaba el texto. `duo` ya
deja las preguntas en `.team/preguntas/T-NNN.md` y las respuestas se reanudan
con `duo ask`. El servicio tiene el trabajo medio hecho por el CLI.

### Fases 4 a 7 · pendientes

GitHub con Octokit, terminal integrada con `xterm.dart` + `flutter_pty`,
visualización del reparto, y el acabado visual. Sin bloqueos conocidos.

## 5. Capacidades de `duo` que la app todavía no toca

El CLI tiene 1415 líneas y la Fase 1 solo lee dos archivos. Lo que queda por
exponer, más o menos en orden de valor:

| Capacidad de `duo` | Fase | Nota |
|---|---|---|
| `duo "<texto>"` — enrutar y lanzar | 2 | El router decide por reglas y ledger, sin LLM: coste cero. Mantenerlo así. |
| salida en vivo del agente | 2 | `duo` ya la guarda en `.team/sesiones/`. |
| `duo status` — preguntas pendientes | 3 | Hoy la app no muestra que un agente está esperando respuesta. |
| `duo ask` — responder y reanudar | 3 | El motivo original del proyecto. |
| `duo show` — leer entregables | 3-4 | Están en `.team/outbox/*.md`, ya en markdown. |
| `duo review` / `done` / `clean` | 4 | Cerrar el ciclo sin salir de la app. |
| `duo doctor`, `duo sync` | — | Diagnóstico; buen candidato a una pestaña de ajustes. |
| varios proyectos (`DUO_P`) | — | El servicio ya los resuelve; falta el selector en la UI. |

## 6. Lo que hace falta decidir

1. **La cabecera canónica.** Hasta que se elija, T-002 sigue rechazada por
   `codex` aunque el código ya funcione con las dos.
2. **Quién implementa en C#.** `PROTOCOL.md` asigna la implementación a `codex`
   y a `cc` las auditorías y lo que haya que ejecutar. Esta tarea pedía arrancar
   el sistema, así que hice las dos mitades; si la regla se mantiene, el
   servicio vuelve a `codex` desde la Fase 2.
3. **Corregir el contrato** con el hallazgo de §3.1, o dejarlo como está y que
   la corrección viva solo en el código.

## 7. Lo más corto hasta algo que se pueda enseñar

Si el objetivo es tener algo que se mire dos veces, el camino más corto no es
seguir las fases en orden estricto:

1. Fase 2 (lanzar y ver en vivo) — es lo que convierte una tabla en un producto.
2. Un repaso de Fase 7 sobre lo ya hecho: tipografía y ventana. Barato, y es lo
   primero que se ve.
3. Fase 3 (preguntas), que es la razón original del proyecto.

GitHub y la terminal integrada pueden esperar: impresionan menos de lo que
cuestan.
