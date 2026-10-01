namespace DuoDesktop.Service.Duo;

/// Un fallo con el código HTTP y el `error.code` del contrato ya decididos.
/// Así el endpoint no tiene que adivinar si algo es 404, 422 o 500.
public sealed class BoardException(int status, string code, string message, string? detail = null)
    : Exception(message)
{
    public int Status { get; } = status;
    public string Code { get; } = code;

    /// Detalle técnico para el log local. Nunca viaja en la respuesta:
    /// el contrato (§10) prohíbe exponer la línea que provocó el error.
    public string? Detail { get; } = detail;

    public static BoardException NotFound(string detail) => new(
        404, "board_not_found",
        "No se encontró una pizarra de duo en el proyecto activo.", detail);

    public static BoardException Invalid(string detail) => new(
        422, "invalid_board",
        "La pizarra de duo tiene un formato inválido.", detail);

    public static BoardException ReadFailed(string detail) => new(
        500, "board_read_failed",
        "No se pudo leer la pizarra del proyecto activo.", detail);
}
