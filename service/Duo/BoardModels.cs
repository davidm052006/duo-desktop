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

/// Respuesta de GET /history. El historial es local: no necesita red ni un
/// token de GitHub, y está ordenado desde el commit más reciente al más antiguo.
public sealed record CommitDto(string Sha, string Message, string Author, DateTimeOffset Date);

public sealed record HistoryResponse(IReadOnlyList<CommitDto> Commits);

/// Datos que devuelve la API de GitHub. Se conservan los SHA y las refs para
/// que el cliente pueda vincular una rama o PR con el historial local.
public sealed record BranchDto(string Name, string Sha, bool Protected);

public sealed record PullRequestDto(
    int Number,
    string Title,
    string State,
    string Author,
    string Head,
    string Base,
    string Url,
    DateTimeOffset UpdatedAt);

public sealed record GitHubResponse(
    IReadOnlyList<BranchDto> Branches,
    IReadOnlyList<PullRequestDto> PullRequests);

public sealed record ErrorBody(string Code, string Message);

public sealed record ErrorResponse(ErrorBody Error);
