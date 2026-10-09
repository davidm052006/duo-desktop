using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using DuoDesktop.Cloud.Api;
using DuoDesktop.Cloud.Auth;
using DuoDesktop.Cloud.Data;
using DuoDesktop.Cloud.Domain;
using DuoDesktop.Cloud.Email;
using DuoDesktop.Cloud.Realtime;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

if (int.TryParse(Environment.GetEnvironmentVariable("PORT"), out var publicPort))
    builder.WebHost.UseUrls($"http://0.0.0.0:{publicPort}");

var connectionString = builder.Configuration.GetConnectionString("DuoCloud")
    ?? throw new InvalidOperationException(
        "Falta ConnectionStrings:DuoCloud. No pongas credenciales en appsettings.json.");

builder.Services.AddDbContext<DuoCloudDbContext>(options =>
    options.UseNpgsql(connectionString));

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<CurrentUser>();
builder.Services.AddSingleton<IInvitationEmailSender, SmtpInvitationEmailSender>();
builder.Services.AddSignalR();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Auth:Authority"];
        options.Audience = builder.Configuration["Auth:Audience"] ?? "authenticated";
        options.MapInboundClaims = false;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

await using (var scope = app.Services.CreateAsyncScope())
{
    var db = scope.ServiceProvider.GetRequiredService<DuoCloudDbContext>();
    if (db.Database.IsRelational())
        await db.Database.MigrateAsync();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/auth/confirmed", () => Results.Content(
    """
    <!doctype html>
    <html lang="es">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Duo Desktop · correo confirmado</title>
        <style>
          body { font-family: system-ui, sans-serif; background:#0f1020; color:#f4f1ff; display:grid; place-items:center; min-height:100vh; margin:0; }
          main { max-width:560px; padding:32px; border:1px solid #343555; border-radius:16px; background:#17182a; }
          h1 { margin-top:0; }
          p { color:#c9c6da; line-height:1.5; }
        </style>
      </head>
      <body>
        <main>
          <h1>Correo confirmado</h1>
          <p>Tu cuenta de Duo Desktop ya puede iniciar sesión.</p>
          <p>Vuelve a Duo Desktop e ingresa con tu correo y contraseña.</p>
        </main>
      </body>
    </html>
    """,
    "text/html; charset=utf-8"));

app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    service = "duo-cloud",
}));

app.MapGet("/api/me", async (
    DuoCloudDbContext db,
    CurrentUser currentUser,
    CancellationToken ct) =>
{
    var user = await currentUser.GetOrCreateAsync(db, ct);
    return Results.Ok(new
    {
        user.Id,
        user.Email,
        user.DisplayName,
    });
}).RequireAuthorization();

app.MapGet("/api/projects", async (
    DuoCloudDbContext db,
    CurrentUser currentUser,
    CancellationToken ct) =>
{
    var user = await currentUser.GetOrCreateAsync(db, ct);

    var projects = await db.ProjectMembers
        .AsNoTracking()
        .Where(x => x.UserId == user.Id)
        .OrderBy(x => x.Project!.Name)
        .Select(x => new
        {
            x.ProjectId,
            x.Project!.Name,
            x.Project.Slug,
            x.Project.RepositoryFullName,
            x.Project.TargetBranch,
            x.Role,
            x.Project.CreatedAt,
        })
        .ToListAsync(ct);

    return Results.Ok(projects);
}).RequireAuthorization();

app.MapPost("/api/projects", async (
    CreateProjectRequest request,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    CancellationToken ct) =>
{
    var name = request.Name?.Trim();
    var slug = request.Slug?.Trim().ToLowerInvariant();
    var repository = request.RepositoryFullName?.Trim();
    var targetBranch = request.TargetBranch?.Trim();

    if (string.IsNullOrWhiteSpace(name))
        return ApiError(422, "invalid_name", "El nombre del proyecto es obligatorio.");

    if (string.IsNullOrWhiteSpace(slug) ||
        !Regex.IsMatch(slug, "^[a-z0-9]+(?:-[a-z0-9]+)*$"))
        return ApiError(422, "invalid_slug", "El slug solo admite minúsculas, números y guiones.");

    if (string.IsNullOrWhiteSpace(repository) ||
        !Regex.IsMatch(repository, "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))
        return ApiError(422, "invalid_repository", "Usa owner/repositorio para GitHub.");

    if (string.IsNullOrWhiteSpace(targetBranch))
        targetBranch = "develop";

    if (await db.Projects.AnyAsync(x => x.Slug == slug, ct))
        return ApiError(409, "slug_taken", "Ya existe un proyecto con ese slug.");

    var user = await currentUser.GetOrCreateAsync(db, ct);
    var now = DateTimeOffset.UtcNow;

    var project = new Project
    {
        Id = Guid.NewGuid(),
        Name = name,
        Slug = slug,
        OwnerUserId = user.Id,
        RepositoryFullName = repository,
        TargetBranch = targetBranch,
        CreatedAt = now,
    };

    db.Projects.Add(project);
    db.ProjectMembers.Add(new ProjectMember
    {
        ProjectId = project.Id,
        UserId = user.Id,
        Role = ProjectRoles.Owner,
        JoinedAt = now,
    });

    await db.SaveChangesAsync(ct);

    return Results.Created($"/api/projects/{project.Id}", new
    {
        project.Id,
        project.Name,
        project.Slug,
        project.RepositoryFullName,
        project.TargetBranch,
        role = ProjectRoles.Owner,
        project.CreatedAt,
    });
}).RequireAuthorization();

app.MapGet("/api/projects/{projectId:guid}/members", async (
    Guid projectId,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");

    var members = await db.ProjectMembers
        .AsNoTracking()
        .Where(x => x.ProjectId == projectId)
        .OrderBy(x => x.JoinedAt)
        .Select(x => new
        {
            x.UserId,
            x.User!.Email,
            x.User.DisplayName,
            x.Role,
            x.JoinedAt,
        })
        .ToListAsync(ct);

    return Results.Ok(members);
}).RequireAuthorization();

app.MapPost("/api/projects/{projectId:guid}/invitations", async (
    Guid projectId,
    InviteMemberRequest request,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    IInvitationEmailSender emailSender,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");
    if (access.Value.Role != ProjectRoles.Owner)
        return ApiError(403, "owner_required", "Solo el owner puede invitar miembros.");

    var email = request.Email?.Trim().ToLowerInvariant();
    var role = request.Role?.Trim().ToLowerInvariant();

    if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
        return ApiError(422, "invalid_email", "Email inválido.");
    if (role is null || !ProjectRoles.IsValid(role) || role == ProjectRoles.Owner)
        return ApiError(422, "invalid_role", "Una invitación admite role editor o viewer.");

    var now = DateTimeOffset.UtcNow;
    var rawToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
    var tokenHash = Sha256(rawToken);

    var invitation = new ProjectInvitation
    {
        Id = Guid.NewGuid(),
        ProjectId = projectId,
        EmailNormalized = email,
        Role = role,
        TokenHash = tokenHash,
        InvitedByUserId = access.Value.User.Id,
        CreatedAt = now,
        ExpiresAt = now.AddDays(7),
    };

    db.ProjectInvitations.Add(invitation);
    await db.SaveChangesAsync(ct);

    var projectName = await db.Projects
        .Where(x => x.Id == projectId)
        .Select(x => x.Name)
        .SingleAsync(ct);

    try
    {
        await emailSender.SendAsync(
            email!,
            rawToken,
            projectName,
            role!,
            invitation.ExpiresAt,
            ct);
    }
    catch (InvitationEmailException e)
    {
        db.ProjectInvitations.Remove(invitation);
        await db.SaveChangesAsync(ct);
        return ApiError(503, e.Code, e.Message);
    }

    // El token crudo viaja únicamente por correo. La API y la DB no lo exponen.
    return Results.Created($"/api/invitations/{invitation.Id}", new
    {
        invitation.Id,
        invitation.ProjectId,
        email,
        role,
        invitation.ExpiresAt,
        emailSent = true,
    });
}).RequireAuthorization();

app.MapPost("/api/invitations/{token}/accept", async (
    string token,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    IHubContext<ProjectHub> hub,
    CancellationToken ct) =>
{
    var user = await currentUser.GetOrCreateAsync(db, ct);
    var hash = Sha256(token);
    var now = DateTimeOffset.UtcNow;

    var invitation = await db.ProjectInvitations
        .SingleOrDefaultAsync(x => x.TokenHash == hash, ct);

    if (invitation is null)
        return ApiError(404, "invitation_not_found", "Invitación no encontrada.");
    if (invitation.AcceptedAt is not null)
        return ApiError(409, "invitation_used", "La invitación ya fue utilizada.");
    if (invitation.ExpiresAt <= now)
        return ApiError(410, "invitation_expired", "La invitación expiró.");
    if (!string.Equals(invitation.EmailNormalized, user.Email, StringComparison.OrdinalIgnoreCase))
        return ApiError(403, "invitation_email_mismatch", "La invitación pertenece a otro email.");

    var exists = await db.ProjectMembers.AnyAsync(
        x => x.ProjectId == invitation.ProjectId && x.UserId == user.Id,
        ct);

    if (!exists)
    {
        db.ProjectMembers.Add(new ProjectMember
        {
            ProjectId = invitation.ProjectId,
            UserId = user.Id,
            Role = invitation.Role,
            JoinedAt = now,
        });
    }

    invitation.AcceptedAt = now;
    await db.SaveChangesAsync(ct);

    await hub.Clients
        .Group(ProjectHub.GroupName(invitation.ProjectId))
        .SendAsync("member_joined", new
        {
            invitation.ProjectId,
            user.Id,
            user.Email,
            user.DisplayName,
            invitation.Role,
            joinedAt = now,
        }, ct);

    return Results.Ok(new
    {
        invitation.ProjectId,
        invitation.Role,
    });
}).RequireAuthorization();

app.MapGet("/api/projects/{projectId:guid}/tasks", async (
    Guid projectId,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");

    var tasks = await db.Tasks
        .AsNoTracking()
        .Where(x => x.ProjectId == projectId)
        .OrderBy(x => x.ExternalId)
        .Select(x => new
        {
            x.Id,
            x.ExternalId,
            x.Title,
            x.OwnerAgent,
            x.Status,
            x.Branch,
            x.AssignedUserId,
            assignedEmail = x.AssignedUser != null ? x.AssignedUser.Email : null,
            x.WorkProvider,
            pullRequest = x.PullRequest == null ? null : new
            {
                x.PullRequest.GitHubNumber,
                x.PullRequest.Url,
                x.PullRequest.SourceBranch,
                x.PullRequest.TargetBranch,
                x.PullRequest.State,
                x.PullRequest.ReviewState,
                x.PullRequest.MergedAt,
            },
            x.CreatedAt,
            x.UpdatedAt,
        })
        .ToListAsync(ct);

    return Results.Ok(tasks);
}).RequireAuthorization();

app.MapPost("/api/projects/{projectId:guid}/tasks/upsert", async (
    Guid projectId,
    UpsertTaskRequest request,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    IHubContext<ProjectHub> hub,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");
    if (access.Value.Role != ProjectRoles.Owner)
        return ApiError(403, "owner_required", "Solo el owner puede crear, editar o reasignar tareas.");

    var externalId = request.ExternalId?.Trim();
    var title = request.Title?.Trim();
    var owner = request.OwnerAgent?.Trim();
    var status = request.Status?.Trim().ToLowerInvariant();
    var branch = request.Branch?.Trim();
    var workProvider = request.WorkProvider?.Trim().ToLowerInvariant();

    if (new[] { externalId, title, owner, status, branch, workProvider }.Any(string.IsNullOrWhiteSpace))
        return ApiError(422, "invalid_task", "Los campos base de la tarea son obligatorios.");

    if (!TaskStatuses.IsValid(status!))
        return ApiError(422, "invalid_status", "Estado de tarea no soportado.");

    if (!WorkProviders.IsValid(workProvider!))
        return ApiError(422, "invalid_provider", "Proveedor de trabajo no soportado.");

    if (request.AssignedUserId is not null)
    {
        var assignedIsMember = await db.ProjectMembers.AnyAsync(
            x => x.ProjectId == projectId && x.UserId == request.AssignedUserId,
            ct);
        if (!assignedIsMember)
            return ApiError(422, "assignee_not_member", "El usuario asignado no pertenece al proyecto.");
    }

    var now = DateTimeOffset.UtcNow;
    var task = await db.Tasks.SingleOrDefaultAsync(
        x => x.ProjectId == projectId && x.ExternalId == externalId,
        ct);

    if (task is null)
    {
        task = new CloudTask
        {
            Id = Guid.NewGuid(),
            ProjectId = projectId,
            ExternalId = externalId!,
            Title = title!,
            OwnerAgent = owner!,
            Status = status!,
            Branch = branch!,
            AssignedUserId = request.AssignedUserId,
            WorkProvider = workProvider!,
            CreatedByUserId = access.Value.User.Id,
            CreatedAt = now,
            UpdatedAt = now,
        };
        db.Tasks.Add(task);
    }
    else
    {
        task.Title = title!;
        task.OwnerAgent = owner!;
        task.Status = status!;
        task.Branch = branch!;
        task.AssignedUserId = request.AssignedUserId;
        task.WorkProvider = workProvider!;
        task.UpdatedAt = now;
    }

    await db.SaveChangesAsync(ct);

    var dto = new
    {
        task.Id,
        task.ProjectId,
        task.ExternalId,
        task.Title,
        task.OwnerAgent,
        task.Status,
        task.Branch,
        task.AssignedUserId,
        task.WorkProvider,
        task.CreatedAt,
        task.UpdatedAt,
    };

    await hub.Clients
        .Group(ProjectHub.GroupName(projectId))
        .SendAsync("task_changed", dto, ct);

    return Results.Ok(dto);
}).RequireAuthorization();


app.MapPost("/api/projects/{projectId:guid}/tasks/{externalId}/start", async (
    Guid projectId,
    string externalId,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    IHubContext<ProjectHub> hub,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");

    var task = await db.Tasks.SingleOrDefaultAsync(
        x => x.ProjectId == projectId && x.ExternalId == externalId,
        ct);
    if (task is null)
        return ApiError(404, "task_not_found", "La tarea no existe en el proyecto.");

    var canWork = access.Value.Role == ProjectRoles.Owner ||
        task.AssignedUserId == access.Value.User.Id;
    if (!canWork)
        return ApiError(403, "assignee_required", "Solo el usuario asignado o el owner puede iniciar esta tarea.");

    task.Status = TaskStatuses.InProgress;
    task.UpdatedAt = DateTimeOffset.UtcNow;

    db.TaskEvents.Add(new TaskEvent
    {
        ProjectId = projectId,
        TaskId = task.Id,
        Type = "task_started",
        Agent = task.WorkProvider,
        ActorUserId = access.Value.User.Id,
        CreatedAt = task.UpdatedAt,
    });

    await db.SaveChangesAsync(ct);

    await hub.Clients.Group(ProjectHub.GroupName(projectId)).SendAsync(
        "task_changed",
        new
        {
            task.Id,
            task.ProjectId,
            task.ExternalId,
            task.Title,
            task.OwnerAgent,
            task.Status,
            task.Branch,
            task.AssignedUserId,
            task.WorkProvider,
            task.CreatedAt,
            task.UpdatedAt,
        },
        ct);

    return Results.Ok();
}).RequireAuthorization();

app.MapPost("/api/projects/{projectId:guid}/tasks/{externalId}/submit", async (
    Guid projectId,
    string externalId,
    SubmitTaskRequest request,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    IHubContext<ProjectHub> hub,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");

    var task = await db.Tasks.SingleOrDefaultAsync(
        x => x.ProjectId == projectId && x.ExternalId == externalId,
        ct);
    if (task is null)
        return ApiError(404, "task_not_found", "La tarea no existe en el proyecto.");

    var canSubmit = access.Value.Role == ProjectRoles.Owner ||
        task.AssignedUserId == access.Value.User.Id;
    if (!canSubmit)
        return ApiError(403, "assignee_required", "Solo el usuario asignado o el owner puede entregar esta tarea.");

    var result = request.Result?.Trim();
    if (string.IsNullOrWhiteSpace(result))
        return ApiError(422, "empty_submission", "El resultado no puede estar vacío.");
    if (result.Length > 500_000)
        return ApiError(413, "submission_too_large", "El resultado supera el límite permitido.");

    var now = DateTimeOffset.UtcNow;
    task.Status = TaskStatuses.InReview;
    task.UpdatedAt = now;

    db.TaskEvents.Add(new TaskEvent
    {
        ProjectId = projectId,
        TaskId = task.Id,
        Type = "submission_collected",
        Agent = task.WorkProvider,
        PayloadJson = JsonSerializer.Serialize(new { result }),
        ActorUserId = access.Value.User.Id,
        CreatedAt = now,
    });

    await db.SaveChangesAsync(ct);

    await hub.Clients.Group(ProjectHub.GroupName(projectId)).SendAsync(
        "task_changed",
        new
        {
            task.Id,
            task.ProjectId,
            task.ExternalId,
            task.Title,
            task.OwnerAgent,
            task.Status,
            task.Branch,
            task.AssignedUserId,
            task.WorkProvider,
            task.CreatedAt,
            task.UpdatedAt,
        },
        ct);

    return Results.Ok(new { task.ExternalId, task.Status });
}).RequireAuthorization();


app.MapPost("/api/projects/{projectId:guid}/tasks/{externalId}/pull-request", async (
    Guid projectId,
    string externalId,
    UpsertPullRequestRequest request,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    IHubContext<ProjectHub> hub,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");
    var project = await db.Projects.SingleAsync(x => x.Id == projectId, ct);
    var task = await db.Tasks
        .Include(x => x.PullRequest)
        .SingleOrDefaultAsync(
            x => x.ProjectId == projectId && x.ExternalId == externalId,
            ct);

    if (task is null)
        return ApiError(404, "task_not_found", "La tarea no existe en el proyecto.");

    var canUpdatePr = access.Value.Role == ProjectRoles.Owner ||
        task.AssignedUserId == access.Value.User.Id;
    if (!canUpdatePr)
        return ApiError(403, "assignee_required", "Solo el usuario asignado o el owner puede actualizar el PR de esta tarea.");

    var url = request.Url?.Trim();
    var sourceBranch = request.SourceBranch?.Trim();
    var targetBranch = request.TargetBranch?.Trim();
    var state = request.State?.Trim().ToLowerInvariant();
    var reviewState = request.ReviewState?.Trim().ToLowerInvariant();

    if (request.GitHubNumber <= 0 ||
        string.IsNullOrWhiteSpace(url) ||
        string.IsNullOrWhiteSpace(sourceBranch) ||
        string.IsNullOrWhiteSpace(targetBranch) ||
        string.IsNullOrWhiteSpace(state))
        return ApiError(422, "invalid_pull_request", "Datos de pull request incompletos.");

    if (request.MergedAt is not null && access.Value.Role != ProjectRoles.Owner)
        return ApiError(403, "owner_required_for_merge", "Solo el owner puede confirmar un merge desde Duo.");

    var now = DateTimeOffset.UtcNow;
    var pullRequest = task.PullRequest ?? new PullRequest
    {
        Id = Guid.NewGuid(),
        ProjectId = projectId,
        TaskId = task.Id,
        GitHubNumber = request.GitHubNumber,
        Url = url!,
        SourceBranch = sourceBranch!,
        TargetBranch = targetBranch!,
        State = state!,
        UpdatedAt = now,
    };

    pullRequest.GitHubNumber = request.GitHubNumber;
    pullRequest.Url = url!;
    pullRequest.SourceBranch = sourceBranch!;
    pullRequest.TargetBranch = targetBranch!;
    pullRequest.State = state!;
    pullRequest.ReviewState = string.IsNullOrWhiteSpace(reviewState) ? null : reviewState;
    pullRequest.MergedAt = request.MergedAt;
    pullRequest.MergedByLogin = request.MergedByLogin?.Trim();
    pullRequest.UpdatedAt = now;

    if (task.PullRequest is null)
        db.PullRequests.Add(pullRequest);

    var mergedToTarget = request.MergedAt is not null &&
        string.Equals(targetBranch, project.TargetBranch, StringComparison.Ordinal);

    task.Status = mergedToTarget
        ? TaskStatuses.Finalized
        : TaskStatuses.InReview;
    task.UpdatedAt = now;

    db.TaskEvents.Add(new TaskEvent
    {
        ProjectId = projectId,
        TaskId = task.Id,
        Type = mergedToTarget ? "pull_request_merged" : "pull_request_updated",
        Agent = task.WorkProvider,
        PayloadJson = JsonSerializer.Serialize(new
        {
            request.GitHubNumber,
            Url = url,
            SourceBranch = sourceBranch,
            TargetBranch = targetBranch,
            State = state,
            ReviewState = reviewState,
            request.MergedAt,
            request.MergedByLogin,
        }),
        ActorUserId = access.Value.User.Id,
        CreatedAt = now,
    });

    await db.SaveChangesAsync(ct);

    var dto = new
    {
        task.ExternalId,
        task.Status,
        pullRequest.GitHubNumber,
        pullRequest.Url,
        pullRequest.SourceBranch,
        pullRequest.TargetBranch,
        pullRequest.State,
        pullRequest.ReviewState,
        pullRequest.MergedAt,
        pullRequest.MergedByLogin,
    };

    await hub.Clients
        .Group(ProjectHub.GroupName(projectId))
        .SendAsync("pull_request_changed", dto, ct);

    await hub.Clients
        .Group(ProjectHub.GroupName(projectId))
        .SendAsync("task_changed", new
        {
            task.Id,
            task.ProjectId,
            task.ExternalId,
            task.Title,
            task.OwnerAgent,
            task.Status,
            task.Branch,
            task.AssignedUserId,
            task.WorkProvider,
            task.CreatedAt,
            task.UpdatedAt,
        }, ct);

    return Results.Ok(dto);
}).RequireAuthorization();

app.MapGet("/api/projects/{projectId:guid}/events", async (
    Guid projectId,
    long? afterId,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");

    var minId = afterId.GetValueOrDefault();
    var events = await db.TaskEvents
        .AsNoTracking()
        .Where(x => x.ProjectId == projectId && x.Id > minId)
        .OrderBy(x => x.Id)
        .Take(500)
        .Select(x => new
        {
            x.Id,
            x.TaskId,
            x.Type,
            x.Agent,
            x.PayloadJson,
            x.ActorUserId,
            x.CreatedAt,
        })
        .ToListAsync(ct);

    return Results.Ok(events);
}).RequireAuthorization();

app.MapPost("/api/projects/{projectId:guid}/events", async (
    Guid projectId,
    AppendTaskEventRequest request,
    DuoCloudDbContext db,
    CurrentUser currentUser,
    IHubContext<ProjectHub> hub,
    CancellationToken ct) =>
{
    var access = await ProjectAccessAsync(db, currentUser, projectId, ct);
    if (access is null) return ApiError(404, "project_not_found", "Proyecto no encontrado.");
    if (!ProjectRoles.CanWrite(access.Value.Role))
        return ApiError(403, "write_forbidden", "Tu rol no permite publicar eventos.");

    var externalTaskId = request.ExternalTaskId?.Trim();
    var type = request.Type?.Trim();
    var agent = request.Agent?.Trim();
    var payload = request.PayloadJson?.Trim();

    if (string.IsNullOrWhiteSpace(externalTaskId) || string.IsNullOrWhiteSpace(type))
        return ApiError(422, "invalid_event", "externalTaskId y type son obligatorios.");

    if (!string.IsNullOrEmpty(payload))
    {
        try
        {
            using var _ = JsonDocument.Parse(payload);
        }
        catch (JsonException)
        {
            return ApiError(422, "invalid_payload", "payloadJson debe ser JSON válido.");
        }
    }

    var task = await db.Tasks.SingleOrDefaultAsync(
        x => x.ProjectId == projectId && x.ExternalId == externalTaskId,
        ct);

    if (task is null)
        return ApiError(404, "task_not_found", "La tarea no existe en el proyecto.");

    var taskEvent = new TaskEvent
    {
        ProjectId = projectId,
        TaskId = task.Id,
        Type = type,
        Agent = string.IsNullOrEmpty(agent) ? null : agent,
        PayloadJson = string.IsNullOrEmpty(payload) ? null : payload,
        ActorUserId = access.Value.User.Id,
        CreatedAt = DateTimeOffset.UtcNow,
    };

    db.TaskEvents.Add(taskEvent);
    await db.SaveChangesAsync(ct);

    var dto = new
    {
        taskEvent.Id,
        taskEvent.ProjectId,
        taskEvent.TaskId,
        externalTaskId = task.ExternalId,
        taskEvent.Type,
        taskEvent.Agent,
        taskEvent.PayloadJson,
        taskEvent.ActorUserId,
        taskEvent.CreatedAt,
    };

    await hub.Clients
        .Group(ProjectHub.GroupName(projectId))
        .SendAsync("task_event", dto, ct);

    return Results.Created($"/api/projects/{projectId}/events/{taskEvent.Id}", dto);
}).RequireAuthorization();

app.MapHub<ProjectHub>("/hubs/projects");

app.Run();

static async Task<(UserProfile User, string Role)?> ProjectAccessAsync(
    DuoCloudDbContext db,
    CurrentUser currentUser,
    Guid projectId,
    CancellationToken ct)
{
    var user = await currentUser.GetOrCreateAsync(db, ct);
    var role = await db.ProjectMembers
        .Where(x => x.ProjectId == projectId && x.UserId == user.Id)
        .Select(x => x.Role)
        .SingleOrDefaultAsync(ct);

    return role is null ? null : (user, role);
}

static string Sha256(string value) =>
    Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)))
        .ToLowerInvariant();

static IResult ApiError(int status, string code, string message) =>
    Results.Json(new
    {
        error = new { code, message },
    }, statusCode: status);

public partial class Program;
