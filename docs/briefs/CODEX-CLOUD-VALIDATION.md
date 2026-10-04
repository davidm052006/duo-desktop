# Codex — validación de Duo Cloud

## Rol

Validar la infraestructura cloud. No rediseñar autenticación, permisos,
entidades ni contratos.

Rama:

```text
feature/cloud-auth-collaboration
```

## Trabajo permitido

- añadir tests bajo `cloud/tests/**`;
- crear la migración EF inicial;
- ejecutar PostgreSQL local con Docker;
- ejecutar builds, tests y comandos de diagnóstico;
- proponer correcciones mínimas con evidencia.

No añadir credenciales reales al repo.

## Comandos base

```bash
git switch feature/cloud-auth-collaboration
git pull

dotnet restore cloud/DuoDesktop.Cloud.csproj
dotnet build cloud/DuoDesktop.Cloud.csproj
```

Levantar PostgreSQL:

```bash
docker compose -f cloud/docker-compose.yml up -d
```

Usar en desarrollo:

```bash
export ConnectionStrings__DuoCloud='Host=127.0.0.1;Port=54329;Database=duo_cloud;Username=duo;Password=duo-dev-only'
```

## Migración inicial

Instalar/usar `dotnet-ef` compatible con .NET 10 y crear una migración inicial
dentro de `cloud/Data/Migrations`.

Validar:

```bash
dotnet ef database update --project cloud
```

No usar `EnsureCreated()`.

## Tests requeridos

Cubrir al menos:

- project owner queda como miembro `owner`;
- viewer no puede escribir;
- editor sí puede escribir;
- usuario fuera del proyecto recibe 403/404 según contrato;
- invitación guarda hash y no token plano;
- invitación expirada no se acepta;
- email distinto no puede aceptar invitación;
- aceptación crea membresía;
- upsert de tarea es único por `projectId + externalId`;
- task event es append-only y conserva orden;
- hub rechaza suscripción de no-miembro.

Para autenticación en tests usa un esquema falso de autenticación. No dependas
de Supabase, Google, GitHub ni Internet.

## Entrega

```text
Build:
Migración:
PostgreSQL:
Tests:
Autorización:
Invitaciones:
Tasks:
Task events:
SignalR:
Fallos:
Correcciones mínimas:
¿Base cloud lista para integrar?: sí/no + motivo
```

No hagas merge.
