using System.Security.Cryptography;
using System.Text;
using DuoDesktop.Service.Duo;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<DuoProjectLocator>();
builder.Services.AddSingleton<BoardReader>();

var app = builder.Build();

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

app.Run();

// El contrato (T-002 §2) fija `Authorization: Bearer`. `scripts/dev.fish` ya
// enseñaba `X-Duo-Token`, y codex lo marcó como incompatibilidad en T-003.
// Se aceptan los dos: así ni el script ni el contrato quedan mintiendo, y la
// decisión de cuál es *el* canónico sigue siendo de David.
static bool Authorized(HttpContext ctx, string? expected)
{
    if (string.IsNullOrWhiteSpace(expected)) return false;

    var presented = Bearer(ctx) ?? ctx.Request.Headers["X-Duo-Token"].FirstOrDefault();
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
