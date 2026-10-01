# T-008 — entregable de `chat`

**Rama:** `chat/t-008-la-vista-de-el-tablero-kaban-se-ve-rara-`  
**Recogido:** 2026-10-01 01:29  
**Vía:** portapapeles

---

# T-008 — Entregable chat

## Alcance mínimo declarado
La corrección debe limitarse a la vista del tablero Kanban de Flutter y al inspector/card de detalle de una tarea.

No modificar backend, contrato de `/board`, modelos de dominio ni otras pantallas salvo que exista un widget visual compartido estrictamente necesario para conservar el diseño.

## Hallazgos

Revisé la tarea y el estado publicado del repositorio.

La referencia visual oficial está en:

- `docs/diseno/02-tablero-kanban.jpeg`
- `docs/diseno/README.md`

El diseño fija explícitamente:

- tablero Kanban;
- inspector lateral de tarea;
- tema oscuro;
- acentos rosa y cian;
- columnas:
  - En espera
  - En progreso
  - Necesita decisión
  - Finalizadas;
- tipografía monoespaciada para datos técnicos;
- interfaz completa y legible.

Sin embargo, en el `main` remoto actualmente accesible todavía aparece la implementación anterior basada en:

- `app/lib/src/pantallas/pantalla_tablero.dart`
- `app/lib/src/widgets/tabla_tareas.dart`

y no aparece publicada la implementación Kanban que originó T-008.

La rama solicitada:

`chat/t-008-la-vista-de-el-tablero-kaban-se-ve-rara-`

tampoco aparece publicada en el remoto accesible.

Por tanto, la corrección debe aplicarse sobre la copia/rama local donde ya existe el Kanban.

## Correcciones requeridas

### 1. Responsive del tablero Kanban

El tablero no debe comprimir las columnas hasta deformar cards, títulos, chips o contenido cuando disminuye el ancho de la ventana.

Implementar el layout con estas reglas:

- Cada columna Kanban debe conservar un ancho mínimo usable.
- No reducir indefinidamente el ancho de las columnas mediante `Expanded` si eso provoca overflow o cards deformadas.
- Cuando no quepan todas las columnas, el tablero debe permitir desplazamiento horizontal.
- El contenido vertical de cada columna debe seguir siendo visible y desplazable.
- No cortar títulos de sección, badges ni controles importantes.
- Las cards deben conservar padding y jerarquía visual incluso en ventanas pequeñas.

Patrón recomendado en Flutter:

- `LayoutBuilder`
- `SingleChildScrollView(scrollDirection: Axis.horizontal)`
- columnas con `SizedBox` o `ConstrainedBox` y ancho mínimo estable
- separación constante entre columnas

Ejemplo conceptual:

`SingleChildScrollView(horizontal) -> Row -> columnas con ancho mínimo`

y no:

`Row -> Expanded -> Expanded -> Expanded -> Expanded`

cuando el ancho disponible sea insuficiente.

### 2. Card de tarea

Las cards del Kanban deben conservar el lenguaje visual del mockup:

- superficie oscura diferenciada del fondo;
- borde sutil;
- esquinas redondeadas;
- buen padding;
- título legible;
- ID visible;
- propietario/agente identificable;
- estado visible;
- rama u otros datos técnicos en tipografía monoespaciada;
- hover/selección claramente perceptible.

Evitar cards planas que se mezclen con el fondo.

### 3. Inspector/card al abrir una tarea

El inspector lateral debe usar la misma identidad visual de `docs/diseno/02-tablero-kanban.jpeg`.

Actualmente el problema reportado es que al abrir la card pierde los colores del diseño.

Corregir para que el inspector:

- no use superficies blancas/grises genéricas;
- herede correctamente el tema oscuro de la aplicación;
- mantenga acentos rosa/cian del diseño;
- use fondo oscuro consistente con el tablero;
- tenga borde/separación visual respecto al Kanban;
- conserve colores correctos para estados y agentes;
- mantenga contraste suficiente del texto;
- use los mismos tokens/constantes de tema que el resto del tablero en vez de colores hardcodeados aislados.

No crear una segunda paleta independiente para el inspector.

### 4. Comportamiento del inspector en ventanas pequeñas

El inspector no debe hacer que el Kanban quede inutilizable.

Comportamiento recomendado:

- ancho amplio: inspector lateral;
- ancho intermedio: inspector lateral con ancho limitado;
- ancho pequeño: inspector como modal/dialog/panel superpuesto o vista adaptada.

Nunca permitir que tablero + inspector compriman las columnas hasta hacerlas ilegibles.

### 5. Integridad visual del tablero

Verificar específicamente:

- títulos completos;
- encabezados de columnas completos;
- cards completas;
- badges/chips completos;
- botones accesibles;
- inspector completo;
- ningún `RenderFlex overflow`;
- ningún texto esencial desaparece;
- scrolling horizontal cuando corresponda;
- scrolling vertical independiente donde sea necesario.

## Criterios de aceptación

La tarea se considera correcta cuando:

1. El Kanban se ve correctamente a ancho grande.
2. Al reducir el ancho de la ventana no se deforman las cuatro columnas.
3. Si no caben, aparece desplazamiento horizontal en lugar de comprimirlas.
4. No aparecen errores `RenderFlex overflow`.
5. Las cards mantienen tamaño, padding y legibilidad.
6. Al abrir una tarea, el inspector conserva el tema oscuro y los colores rosa/cian del diseño.
7. El inspector no rompe el layout en ventanas pequeñas.
8. La información importante permanece completa y accesible.
9. La vista sigue visualmente la referencia `docs/diseno/02-tablero-kanban.jpeg`.
10. No se altera comportamiento del backend ni contrato `/board`.

## Validación recomendada

Ejecutar la aplicación real de Linux:

`scripts/dev.fish`

y revisar manualmente la pantalla Tablero en varios anchos de ventana, especialmente:

- ventana maximizada;
- aproximadamente 1200 px;
- aproximadamente 900 px;
- ventana estrecha cercana al mínimo permitido.

También ejecutar:

`cd app && flutter analyze`

y los tests Flutter relacionados con la pantalla/tablero, si existen.

No es necesario ejecutar pytest del backend porque el territorio de T-008 es exclusivamente Flutter/UI.

## Estado

No pude modificar ni commitear directamente el código porque:

- mi conexión GitHub para este repositorio es de solo lectura;
- la rama `chat/t-008-la-vista-de-el-tablero-kaban-se-ve-rara-` no está publicada en el remoto accesible;
- la implementación Kanban que presenta el problema tampoco aparece todavía en el `main` remoto accesible.

No se modificó `main` ni `team/board`.

Aplicar este entregable con `duo collect T-008` sobre la rama/copia local donde ya exista la implementación Kanban.

Si se crea un commit para esta tarea, debe incluir exactamente estos trailers:

Tarea: T-008
Agente: chat
