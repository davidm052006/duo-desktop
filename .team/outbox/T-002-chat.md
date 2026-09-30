# T-002 — entregable de `chat`

**Rama:** `chat/t-002-disena-el-contrato-de-la-api-del-servici`  
**Recogido:** 2026-09-30 17:22  
**Vía:** stdin

---

# Contrato

## GET /board

Devuelve el tablero completo y el ledger leyendo .team/.

### Respuesta 200

```json
{
  "project": "duo-desktop",
  "tasks": [{"id": "T-002", "owner": "chat", "state": "abierta"}],
  "ledger": [{"agent": "chat", "points": 2}]
}
```

### Errores

- 404 si el proyecto no existe
- 500 si .team/ es ilegible
