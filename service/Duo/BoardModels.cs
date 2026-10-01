namespace DuoDesktop.Service.Duo;

// Los nombres JSON del contrato (docs/api/CONTRATO_BOARD.md, T-002) están en
// inglés aunque los archivos de `duo` estén en español. La traducción vive
// aquí y en ningún otro sitio.

public sealed record TaskDto(
    string Id,
    string Title,
    string Owner,
    string Branch,
    string Status,
    string Opened);

public sealed record AgentDto(
    string Agent,
    int Points,
    int Tasks,
    string? Last);

public sealed record BoardDto(IReadOnlyList<TaskDto> Tasks);

public sealed record LedgerDto(IReadOnlyList<AgentDto> Agents);

public sealed record ProjectDto(string Name, string Repo, string Board);

/// Respuesta de `GET /board`. `project` es una extensión compatible: el
/// contrato v1 (§17) la admite sin cambiar la semántica de board/ledger.
public sealed record BoardResponse(ProjectDto Project, BoardDto Board, LedgerDto Ledger);

public sealed record ErrorBody(string Code, string Message);

public sealed record ErrorResponse(ErrorBody Error);
