using System.Security.Cryptography;
using System.Text;
using DuoDesktop.Service.Duo;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<DuoProjectLocator>();
builder.Services.AddSingleton<BoardReader>();
builder.Services.AddSingleton<QuestionReader>();
builder.Services.AddSingleton<TaskOwnerHistoryReader>();
builder.Services.AddSingleton<LiveEventStream>();
builder.Services.AddSingleton<HistoryReader>();
builder.Services.AddSingleton<GitHubReader>();
builder.Services.AddSingleton<DuoCommandRunner>();
builder.Services.AddSingleton<IExecutableLocator, PathExecutableLocator>();
builder.Services.AddSingleton<AgentCapabilitiesReader>();
builder.Services.AddSingleton<GitWorkspaceService>();

var app = builder.Build();
app.UseWebSockets();

// El token lo pasa quien arranca el servicio (scripts/dev.fish, o Flutter
// cuando lo lance como proceso hijo). Sin él, cualquier proceso de la máquina
// podría mandarle órdenes a los agentes, así que sin él no se sirve nada.
var token = Environment.GetEnvironmentVariable("DUO_TOKEN");
if (string.IsNullOrWhiteSpace(token))
{
    app.Logger.LogWarning(
        "DUO_TOKEN no está definido: /board responderá 401. Arranca con scripts/dev.fish.");
}

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "duo-desktop" }));

app.MapGet("/agents/capabilities", (HttpContext ctx, AgentCapabilitiesReader reader) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    // No se inspeccionan credenciales, variables de proveedor ni archivos de
    // configuración. La ruta resuelta es metadato local permitido por contrato.
    return Results.Ok(new { agents = reader.Read() });
});

app.MapGet("/board", (HttpContext ctx, BoardReader reader, ILogger<Program> log) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        return Results.Ok(reader.Read());
    }
    catch (BoardException e)
    {
        log.LogWarning("GET /board → {Status} {Code}: {Detail}", e.Status, e.Code, e.Detail);
        return Error(e.Status, e.Code, e.Message);
    }
    catch (Exception e)
    {
        log.LogError(e, "GET /board → 500 inesperado");
        return Error(500, "board_read_failed", "No se pudo leer la pizarra del proyecto activo.");
    }
});

app.MapGet("/history", (HttpContext ctx, HistoryReader reader, ILogger<Program> log) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        return Results.Ok(reader.Read());
    }
    catch (BoardException e)
    {
        log.LogWarning("GET /history → {Status} {Code}: {Detail}", e.Status, e.Code, e.Detail);
        return Error(e.Status, e.Code, e.Message);
    }
    catch (Exception e)
    {
        log.LogError(e, "GET /history → 500 inesperado");
        return Error(500, "board_read_failed", "No se pudo leer el historial del proyecto activo.");
    }
});

app.MapGet("/questions", (HttpContext ctx, QuestionReader reader, ILogger<Program> log) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        return Results.Ok(reader.Read());
    }
    catch (BoardException e)
    {
        log.LogWarning("GET /questions → {Status} {Code}: {Detail}", e.Status, e.Code, e.Detail);
        return Error(e.Status, e.Code, e.Message);
    }
    catch (Exception e)
    {
        log.LogError(e, "GET /questions → 500 inesperado");
        return Error(500, "questions_read_failed", "No se pudieron leer las preguntas del proyecto activo.");
    }
});

app.Map("/events", async (HttpContext ctx, LiveEventStream events, ILogger<Program> log) =>
{
    if (!Authorized(ctx, token))
    {
        await Error(401, "unauthorized", "Token local ausente o inválido.").ExecuteAsync(ctx);
        return;
    }
    if (!ctx.WebSockets.IsWebSocketRequest)
    {
        await Error(400, "websocket_required", "Este endpoint requiere una conexión WebSocket.").ExecuteAsync(ctx);
        return;
    }

    using var socket = await ctx.WebSockets.AcceptWebSocketAsync();
    try
    {
        await events.SendAsync(socket, ctx.RequestAborted);
    }
    catch (Exception e) when (e is BoardException or IOException or UnauthorizedAccessException)
    {
        log.LogWarning(e, "WebSocket /events terminó con un error de lectura");
        if (socket.State == System.Net.WebSockets.WebSocketState.Open)
            await socket.CloseAsync(System.Net.WebSockets.WebSocketCloseStatus.InternalServerError,
                "No se pudo leer el proyecto activo.", CancellationToken.None);
    }
});

app.MapGet("/github", async (HttpContext ctx, GitHubReader reader, ILogger<Program> log) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        return Results.Ok(await reader.ReadAsync(ctx.RequestAborted));
    }
    catch (BoardException e)
    {
        log.LogWarning("GET /github → {Status} {Code}: {Detail}", e.Status, e.Code, e.Detail);
        return Error(e.Status, e.Code, e.Message);
    }
    catch (Exception e)
    {
        log.LogError(e, "GET /github → 500 inesperado");
        return Error(500, "board_read_failed", "No se pudo leer GitHub del proyecto activo.");
    }
});

app.MapPost("/tasks", async (HttpContext ctx, CreateTaskRequest? request, DuoCommandRunner runner, ILogger<Program> log) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");
    if (string.IsNullOrWhiteSpace(request?.Text))
        return Error(422, "invalid_request", "El texto de la tarea es obligatorio.");

    try
    {
        var id = await runner.CreateTaskAsync(request.Text, ctx.RequestAborted);
        return Results.Ok(new CreateTaskResponse(id));
    }
    catch (DuoCommandException e)
    {
        log.LogWarning("POST /tasks → {Status} {Code}: {Detail}", e.Status, e.Code, e.Detail);
        return Error(e.Status, e.Code, e.Message);
    }
    catch (Exception e)
    {
        log.LogError(e, "POST /tasks → 500 inesperado");
        return Error(500, "duo_command_failed", "No se pudo crear la tarea.");
    }
});

app.MapPost("/questions/{id}/answer", async (HttpContext ctx, string id, AnswerQuestionRequest? request, DuoCommandRunner runner, ILogger<Program> log) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");
    if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(request?.Text))
        return Error(422, "invalid_request", "El identificador y el texto de la respuesta son obligatorios.");

    try
    {
        await runner.AnswerQuestionAsync(id, request.Text, ctx.RequestAborted);
        return Results.Ok();
    }
    catch (DuoCommandException e)
    {
        log.LogWarning("POST /questions/{Id}/answer → {Status} {Code}: {Detail}", id, e.Status, e.Code, e.Detail);
        return Error(e.Status, e.Code, e.Message);
    }
    catch (Exception e)
    {
        log.LogError(e, "POST /questions/{Id}/answer → 500 inesperado", id);
        return Error(500, "duo_command_failed", "No se pudo enviar la respuesta al agente.");
    }
});


app.MapGet("/git/repository/{projectId}", async (
    HttpContext ctx,
    string projectId,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    var mapping = await workspaces.RepositoryAsync(projectId, ct);
    return mapping is null
        ? Error(404, "repository_not_configured", "No hay repositorio local configurado para este proyecto.")
        : Results.Ok(mapping);
});

app.MapPost("/git/repository", async (
    HttpContext ctx,
    ConfigureRepositoryRequest? request,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        var mapping = await workspaces.ConfigureRepositoryAsync(
            request?.ProjectId ?? "",
            request?.ProjectSlug ?? "",
            request?.RepositoryFullName ?? "",
            request?.RepositoryPath ?? "",
            ct);
        return Results.Ok(mapping);
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.MapPost("/git/workspaces/prepare", async (
    HttpContext ctx,
    PrepareWorkspaceRequest? request,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        var workspace = await workspaces.PrepareAsync(
            request?.ProjectId ?? "",
            request?.ExternalId ?? "",
            request?.TaskTitle ?? "",
            request?.TargetBranch ?? "",
            request?.Provider ?? "",
            ct);
        return Results.Ok(workspace);
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.MapGet("/git/workspaces/{workspaceId}/status", async (
    HttpContext ctx,
    string workspaceId,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        return Results.Ok(await workspaces.StatusAsync(workspaceId, ct));
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.MapPost("/git/workspaces/apply-patch", async (
    HttpContext ctx,
    ApplyPatchWorkspaceRequest? request,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        var status = await workspaces.ApplyPatchAsync(
            request?.WorkspaceId ?? "",
            request?.Patch ?? "",
            ct);
        return Results.Ok(status);
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.MapPost("/git/workspaces/commit", async (
    HttpContext ctx,
    CommitWorkspaceRequest? request,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        var result = await workspaces.CommitAsync(
            request?.WorkspaceId ?? "",
            request?.Files ?? [],
            request?.Message ?? "",
            ct);
        return Results.Ok(result);
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.MapPost("/git/workspaces/push", async (
    HttpContext ctx,
    PushWorkspaceRequest? request,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        await workspaces.PushAsync(request?.WorkspaceId ?? "", ct);
        return Results.Ok();
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.MapPost("/git/workspaces/agent", async (
    HttpContext ctx,
    LaunchAgentRequest? request,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        await workspaces.LaunchAgentAsync(
            request?.WorkspaceId ?? "",
            request?.Provider ?? "",
            ct);
        return Results.Ok();
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.MapPost("/git/workspaces/pr", async (
    HttpContext ctx,
    PullRequestWorkspaceRequest? request,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        var pr = await workspaces.FindOrCreatePullRequestAsync(
            request?.WorkspaceId ?? "",
            request?.Title ?? "",
            request?.Body ?? "",
            ct);
        return Results.Ok(pr);
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.MapGet("/git/workspaces/{workspaceId}/pr/{number:int}", async (
    HttpContext ctx,
    string workspaceId,
    int number,
    GitWorkspaceService workspaces,
    CancellationToken ct) =>
{
    if (!Authorized(ctx, token))
        return Error(401, "unauthorized", "Token local ausente o inválido.");

    try
    {
        return Results.Ok(await workspaces.PullRequestStatusAsync(workspaceId, number, ct));
    }
    catch (GitWorkspaceException e)
    {
        return Error(e.Status, e.Code, e.Message);
    }
});

app.Run();

// `Authorization: Bearer` es la única cabecera aceptada, como fija el contrato
// (T-002 §2). `X-Duo-Token` fue la incompatibilidad que codex marcó en T-003;
// está descartada, y `scripts/dev.fish` ya no la menciona.
static bool Authorized(HttpContext ctx, string? expected)
{
    if (string.IsNullOrWhiteSpace(expected)) return false;

    var presented = Bearer(ctx);
    if (string.IsNullOrEmpty(presented)) return false;

    return CryptographicOperations.FixedTimeEquals(
        Encoding.UTF8.GetBytes(presented),
        Encoding.UTF8.GetBytes(expected));
}

static string? Bearer(HttpContext ctx)
{
    var raw = ctx.Request.Headers.Authorization.FirstOrDefault();
    if (raw is null) return null;
    const string prefix = "Bearer ";
    return raw.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
        ? raw[prefix.Length..].Trim()
        : null;
}

static IResult Error(int status, string code, string message) =>
    Results.Json(new ErrorResponse(new ErrorBody(code, message)), statusCode: status);
