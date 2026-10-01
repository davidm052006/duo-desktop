# T-003 — entregable de `codex`

**Rama:** `codex/t-003-revision-t-002`  
**Cerrado:** 2026-09-30 18:09

## Cambios contra la base

```
(sin cambios)
```

## Lo que reportó el agente

+      {
+        "agent": "codex",
+        "points": 0,
+        "tasks": 0,
+        "last": null
+      },
+      {
+        "agent": "cc",
+        "points": 0,
+        "tasks": 0,
+        "last": null
+      }
+    ]
+  }
+}
+```
+
+La estructura superior siempre contiene exactamente estos dos objetos conceptuales:
+
+```text
+board
+ledger
+```
+
+---
+
+# 4. Modelo JSON
+
+## `board`
+
+```json
+{
+  "tasks": []
+}
+```
4d94ae6 docs(api): contrato v1 de GET /board

codex
Veredicto: no entra a `develop` todavía.

Falta resolver y unificar la cabecera de autenticación:

- [docs/api/CONTRATO_BOARD.md](/home/david/dev/wt/codex-duo-desktop/docs/api/CONTRATO_BOARD.md:34) fija `Authorization: Bearer <token-local>` (también en líneas 45 y 761).
- [scripts/dev.fish](/home/david/dev/wt/codex-duo-desktop/scripts/dev.fish:35), que define cómo se prueba/arranca el servicio, usa `X-Duo-Token: <token>`.

Es una incompatibilidad de contrato: Flutter, `curl` y la futura implementación no sabrían cuál enviar. El propio documento deja esa decisión pendiente en la línea 783, así que aún no es un contrato cerrado “exacto”.

Por lo demás, el diseño sí cubre el alcance: lectura exclusiva de ambos archivos `.team/`, mapeo JSON, normalización de números/`-`, orden y códigos `401/404/422/500`; no modifica código existente.
tokens used
30.403
Veredicto: no entra a `develop` todavía.

Falta resolver y unificar la cabecera de autenticación:

- [docs/api/CONTRATO_BOARD.md](/home/david/dev/wt/codex-duo-desktop/docs/api/CONTRATO_BOARD.md:34) fija `Authorization: Bearer <token-local>` (también en líneas 45 y 761).
- [scripts/dev.fish](/home/david/dev/wt/codex-duo-desktop/scripts/dev.fish:35), que define cómo se prueba/arranca el servicio, usa `X-Duo-Token: <token>`.

Es una incompatibilidad de contrato: Flutter, `curl` y la futura implementación no sabrían cuál enviar. El propio documento deja esa decisión pendiente en la línea 783, así que aún no es un contrato cerrado “exacto”.

Por lo demás, el diseño sí cubre el alcance: lectura exclusiva de ambos archivos `.team/`, mapeo JSON, normalización de números/`-`, orden y códigos `401/404/422/500`; no modifica código existente.
