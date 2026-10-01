# T-006 — entregable de `chat`

**Rama:** `chat/t-006-corrige-docs-api-contrato-board-md-la-ca`  
**Recogido:** 2026-09-30 22:19  
**Vía:** portapapeles

---

# T-006 — Entregable chat

## Alcance
Únicamente `docs/api/CONTRATO_BOARD.md`.

## Cambio requerido
- Sustituir cualquier uso de:
  `X-Duo-Token: <token>`
  por:
  `Authorization: Bearer <token>`

- Eliminar toda referencia que presente `X-Duo-Token` como cabecera válida, alternativa o canónica.

- Mantener `Authorization: Bearer <token>` como la única cabecera documentada para autenticación del contrato `/board`.

- No modificar código, scripts, otros documentos ni comportamiento de la API.

## Validación
Ejecutar:

grep -n "X-Duo-Token" docs/api/CONTRATO_BOARD.md

Resultado esperado: cero coincidencias.

Ejecutar:

grep -n "Authorization.*Bearer" docs/api/CONTRATO_BOARD.md

Resultado esperado: debe aparecer la cabecera canónica `Authorization: Bearer <token>`.

## Tests
No corresponde ejecutar pytest porque la tarea es exclusivamente documental y no modifica backend ni comportamiento.

## Estado
No pude aplicar ni commitear el cambio directamente porque:
- la rama `chat/t-006-corrige-docs-api-contrato-board-md-la-ca` no aparece publicada en el remoto accesible;
- `docs/api/CONTRATO_BOARD.md` no existe en `main` ni en `team/board` del remoto accesible;
- mi conexión de GitHub para este repositorio es de solo lectura.

No se modificó `main` ni `team/board`.

Aplicar este entregable sobre la copia local donde exista `docs/api/CONTRATO_BOARD.md` y registrar el resultado correspondiente para T-006.
