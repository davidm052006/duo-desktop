# Duo Cloud — identidad, proyectos y colaboración

## Principio

Los miembros del proyecto no reciben credenciales de PostgreSQL.

Duo separa tres identidades:

1. **usuario humano**: token JWT emitido por un proveedor OIDC/Auth;
2. **Duo Cloud**: único componente con credenciales de PostgreSQL;
3. **agentes**: en una fase posterior recibirán tokens de servicio limitados por proyecto.

Duo no guarda contraseñas.

## Componentes

```text
Flutter Desktop
      |
      | JWT
      v
Duo Cloud (.NET)
      |
      +---- PostgreSQL
      |
      +---- SignalR
             |
             +---- todos los miembros conectados al proyecto

Duo Local Service
      |
      +---- git / archivos / duo / Codex
      |
      +---- sincronización futura con Duo Cloud
```

El servicio local sigue siendo responsable del computador del usuario. Duo
Cloud no ejecuta comandos locales.

## Modelo de acceso

Roles iniciales:

- `owner`: administra proyecto, invitaciones y datos;
- `editor`: puede crear/actualizar tareas y publicar eventos;
- `viewer`: solo lectura.

Las autorizaciones se comprueban en el backend, no solo en Flutter.

## Datos

- `users`: perfil asociado al `sub` del proveedor de identidad;
- `projects`: proyecto colaborativo;
- `project_members`: membresía y rol;
- `project_invitations`: invitaciones con token guardado solo como hash;
- `tasks`: snapshot actual de cada tarea;
- `task_events`: historial append-only.

`task_events` es la base de la línea de tiempo compartida. El snapshot de
`tasks` evita reconstruir todo el historial para dibujar el tablero.

## Autenticación

Configuración por entorno:

```text
ConnectionStrings__DuoCloud
Auth__Authority
Auth__Audience
```

`Auth__Authority` debe apuntar al emisor OIDC/JWT elegido. La app recibe un
access token del proveedor y lo envía a Duo Cloud como Bearer.

No se debe guardar una service-role key ni una contraseña de PostgreSQL en
Flutter, en `.team`, ni en tokens de agente.

## Invitaciones

1. un owner crea una invitación por email y rol;
2. Duo Cloud genera un token aleatorio;
3. en PostgreSQL solo se guarda SHA-256 del token;
4. el token original se entrega una sola vez al owner para construir el enlace;
5. el usuario invitado inicia sesión;
6. al aceptar, el email autenticado debe coincidir con el email invitado;
7. se crea `project_members`.

El envío de email se conecta después; el contrato no depende de un proveedor
de correo específico.

## Realtime

SignalR expone `/hubs/projects`.

El cliente autenticado llama:

```text
SubscribeProject(projectId)
```

El hub comprueba la membresía antes de añadir la conexión al grupo.

Eventos iniciales:

- `task_changed`
- `task_event`
- `member_joined`

## Siguiente integración

La próxima etapa conecta el servicio local con Duo Cloud:

```text
.team/BOARD.md ----+
sesiones ----------+--> local sync --> /api/projects/{id}/...
duo events --------+
```

Durante la transición, `.team` sigue funcionando como fuente local y Duo
Cloud se usa para colaboración e historial compartido.
