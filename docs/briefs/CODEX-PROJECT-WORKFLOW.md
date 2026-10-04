# Codex — workflow colaborativo y DB de desarrollo

## Rama

`feature/project-collaboration-workflow`

## Autorización de trabajo

Puedes escribir en la base PostgreSQL **de desarrollo** usando la variable de
entorno `ConnectionStrings__DuoCloud`.

Está permitido:

- ejecutar migraciones EF;
- aplicar migraciones;
- insertar/limpiar datos de prueba;
- consultar tablas, índices y foreign keys;
- crear tests de integración;
- validar el flujo project/member/task/PR.

No está permitido:

- imprimir la cadena de conexión;
- guardar contraseñas/secret keys en archivos;
- añadir secretos a Git;
- meter credenciales de DB en Flutter;
- cambiar arquitectura sin reportar primero el fallo.

## Modelo que debes validar

Un único PostgreSQL contiene múltiples proyectos. Todos los datos colaborativos
se separan por `project_id`.

Un proyecto tiene:

- owner;
- `repository_full_name`;
- `target_branch` (por defecto `develop`).

Una tarea tiene:

- usuario asignado;
- proveedor `chatgpt|grok|codex|claude|gemini`;
- rama;
- estado.

Estados válidos:

- `pending`;
- `in_progress`;
- `waiting`;
- `in_review`;
- `finalized`;
- `cancelled`.

## PR

Probar:

1. editor puede registrar/actualizar PR;
2. registrar PR mueve tarea a `in_review`;
3. approve sin merge NO finaliza;
4. editor no puede confirmar `MergedAt`;
5. owner sí puede confirmar merge;
6. merge hacia rama distinta de `target_branch` NO finaliza;
7. merge hacia `target_branch` sí cambia tarea a `finalized`;
8. se crea evento `pull_request_merged`;
9. SignalR emite `pull_request_changed` y `task_changed`.

## Asignaciones

Probar:

- assigned user debe ser miembro del proyecto;
- no se puede asignar un UUID externo;
- provider inválido devuelve 422;
- status inválido devuelve 422.

## Migración

Si ya existe una migración inicial en tu rama, crea una migración incremental.
No borres migraciones aplicadas.

Ejecuta contra la DB de desarrollo configurada:

```bash
dotnet ef database update --project cloud
```

## Seguridad

La app final solo tendrá URL de Supabase + publishable key. La conexión
PostgreSQL es backend/dev-only.

## Entrega

```text
Build:
Migración:
DB aplicada:
Aislamiento por proyecto:
Asignación de miembro:
Providers:
PR abierto:
PR aprobado sin merge:
Merge por editor:
Merge owner rama incorrecta:
Merge owner a develop:
Task finalized:
Eventos:
SignalR:
Secretos expuestos:
Fallos:
¿Workflow listo?: sí/no + motivo
```

No hagas merge.
