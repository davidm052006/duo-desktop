using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace DuoDesktop.Service.Duo;

public sealed class GitWorkspaceService(IExecutableLocator executables, ILogger<GitWorkspaceService> log)
{
    private static readonly Regex SafeSegment = new("[^a-z0-9-]+", RegexOptions.Compiled);
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly string _stateFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "duo-desktop",
        "git-workspaces.json");

    public async Task<RepositoryMapping> ConfigureRepositoryAsync(
        string projectId,
        string projectSlug,
        string repositoryFullName,
        string repositoryPath,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(projectId) ||
            string.IsNullOrWhiteSpace(repositoryFullName) ||
            string.IsNullOrWhiteSpace(repositoryPath))
            throw GitWorkspaceException.Invalid("Faltan datos para configurar el repositorio.");

        var root = await GitAsync(repositoryPath, ["rev-parse", "--show-toplevel"], ct);
        var canonicalRoot = CanonicalDirectory(root.Stdout.Trim());
        var requested = CanonicalDirectory(repositoryPath);
        if (!IsSameOrChild(requested, canonicalRoot) && !IsSameOrChild(canonicalRoot, requested))
            throw GitWorkspaceException.Invalid("La carpeta no pertenece al repositorio Git detectado.");

        var remote = await GitAsync(canonicalRoot, ["remote", "get-url", "origin"], ct);
        if (!RemoteMatches(remote.Stdout.Trim(), repositoryFullName))
            throw GitWorkspaceException.RemoteMismatch(repositoryFullName);

        var state = await LoadAsync(ct);
        state.Repositories[projectId] = new RepositoryMapping(
            projectId,
            Slug(projectSlug),
            repositoryFullName,
            canonicalRoot);
        await SaveAsync(state, ct);
        return state.Repositories[projectId];
    }

    public async Task<WorkspaceInfo> PrepareAsync(
        string projectId,
        string externalId,
        string taskTitle,
        string targetBranch,
        string provider,
        CancellationToken ct)
    {
        var state = await LoadAsync(ct);
        if (!state.Repositories.TryGetValue(projectId, out var repo))
            throw GitWorkspaceException.NotConfigured();

        var key = WorkspaceKey(projectId, externalId);
        if (state.Workspaces.TryGetValue(key, out var existing) &&
            Directory.Exists(existing.WorktreePath))
            return existing;

        var safeTask = Slug(externalId);
        if (string.IsNullOrWhiteSpace(safeTask))
            throw GitWorkspaceException.Invalid("El identificador de tarea no produce una rama segura.");

        var safeTitle = Slug(taskTitle);
        if (safeTitle.Length > 42) safeTitle = safeTitle[..42].Trim('-');
        var branch = $"feature/{safeTask}{(safeTitle.Length == 0 ? "" : "-" + safeTitle)}";
        var safeTarget = BranchName(targetBranch);

        await GitAsync(repo.RepositoryPath, ["fetch", "origin"], ct);

        var worktreeBase = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "dev", "wt");
        Directory.CreateDirectory(worktreeBase);
        var worktree = CanonicalDirectory(Path.Combine(
            worktreeBase, $"duo-{repo.ProjectSlug}-{safeTask}"));

        var branchExists = (await GitExitAsync(
            repo.RepositoryPath,
            ["show-ref", "--verify", "--quiet", $"refs/heads/{branch}"],
            ct)) == 0;

        if (Directory.Exists(worktree))
        {
            var detected = await GitAsync(worktree, ["branch", "--show-current"], ct);
            if (!string.Equals(detected.Stdout.Trim(), branch, StringComparison.Ordinal))
                throw GitWorkspaceException.Conflict("La ruta de worktree ya existe y pertenece a otra rama.");
        }
        else if (branchExists)
        {
            await GitAsync(repo.RepositoryPath, ["worktree", "add", worktree, branch], ct);
        }
        else
        {
            await GitAsync(
                repo.RepositoryPath,
                ["worktree", "add", "-b", branch, worktree, $"origin/{safeTarget}"],
                ct);
        }

        var info = new WorkspaceInfo(
            key,
            projectId,
            externalId,
            repo.RepositoryPath,
            worktree,
            branch,
            safeTarget,
            provider);
        state.Workspaces[key] = info;
        await SaveAsync(state, ct);
        return info;
    }

    public async Task<WorkspaceStatus> StatusAsync(string workspaceId, CancellationToken ct)
    {
        var ws = await RequireWorkspaceAsync(workspaceId, ct);
        var branch = (await GitAsync(ws.WorktreePath, ["branch", "--show-current"], ct)).Stdout.Trim();
        if (!string.Equals(branch, ws.Branch, StringComparison.Ordinal))
            throw GitWorkspaceException.Conflict("El worktree ya no está en la rama registrada.");

        var porcelain = await GitAsync(
            ws.WorktreePath,
            ["status", "--porcelain=v1", "--untracked-files=all"],
            ct);
        var changed = ParseChangedFiles(porcelain.Stdout);

        var ahead = 0;
        var behind = 0;
        var trackingExit = await GitExitAsync(
            ws.WorktreePath,
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            ct);
        if (trackingExit == 0)
        {
            var counts = await GitAsync(
                ws.WorktreePath,
                ["rev-list", "--left-right", "--count", "HEAD...@{u}"],
                ct);
            var parts = counts.Stdout.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length >= 2)
            {
                _ = int.TryParse(parts[0], out ahead);
                _ = int.TryParse(parts[1], out behind);
            }
        }

        return new WorkspaceStatus(
            ws.WorkspaceId,
            branch,
            changed.Count > 0,
            changed,
            ahead,
            behind);
    }

    public async Task<CommitResult> CommitAsync(
        string workspaceId,
        IReadOnlyList<string> files,
        string message,
        CancellationToken ct)
    {
        if (files.Count == 0)
            throw GitWorkspaceException.Invalid("Selecciona al menos un archivo.");
        if (string.IsNullOrWhiteSpace(message))
            throw GitWorkspaceException.Invalid("El mensaje de commit es obligatorio.");

        var ws = await RequireWorkspaceAsync(workspaceId, ct);
        var status = await StatusAsync(workspaceId, ct);
        var allowed = status.ChangedFiles.ToHashSet(StringComparer.Ordinal);

        foreach (var file in files.Distinct(StringComparer.Ordinal))
        {
            ValidateRelativeFile(ws.WorktreePath, file);
            if (!allowed.Contains(file))
                throw GitWorkspaceException.Invalid($"El archivo no está entre los cambios actuales: {file}");
        }

        var addArgs = new List<string> { "add", "--" };
        addArgs.AddRange(files.Distinct(StringComparer.Ordinal));
        await GitAsync(ws.WorktreePath, addArgs, ct);
        await GitAsync(ws.WorktreePath, ["commit", "-m", message.Trim()], ct);
        var sha = (await GitAsync(ws.WorktreePath, ["rev-parse", "HEAD"], ct)).Stdout.Trim();
        return new CommitResult(sha);
    }

    public async Task PushAsync(string workspaceId, CancellationToken ct)
    {
        var ws = await RequireWorkspaceAsync(workspaceId, ct);
        await GitAsync(ws.WorktreePath, ["push", "-u", "origin", ws.Branch], ct);
    }

    public async Task<PullRequestInfo> FindOrCreatePullRequestAsync(
        string workspaceId,
        string title,
        string body,
        CancellationToken ct)
    {
        var ws = await RequireWorkspaceAsync(workspaceId, ct);
        var state = await LoadAsync(ct);
        var repo = state.Repositories[ws.ProjectId];

        var existing = await GhJsonAsync(
            ws.WorktreePath,
            ["pr", "list", "--repo", repo.RepositoryFullName, "--head", ws.Branch,
             "--state", "all", "--json", "number,url,state,headRefName,baseRefName,mergedAt"],
            ct);

        if (existing.RootElement.ValueKind == JsonValueKind.Array &&
            existing.RootElement.GetArrayLength() > 0)
            return ParsePullRequest(existing.RootElement[0]);

        await RunAsync(
            RequireExecutable("gh"),
            ws.WorktreePath,
            ["pr", "create",
             "--repo", repo.RepositoryFullName,
             "--head", ws.Branch,
             "--base", ws.TargetBranch,
             "--title", title.Trim(),
             "--body", body.Trim()],
            ct);

        var created = await GhJsonAsync(
            ws.WorktreePath,
            ["pr", "view", "--repo", repo.RepositoryFullName, ws.Branch,
             "--json", "number,url,state,headRefName,baseRefName,mergedAt"],
            ct);
        return ParsePullRequest(created.RootElement);
    }

    public async Task<PullRequestInfo> PullRequestStatusAsync(
        string workspaceId,
        int number,
        CancellationToken ct)
    {
        if (number <= 0) throw GitWorkspaceException.Invalid("Número de PR inválido.");
        var ws = await RequireWorkspaceAsync(workspaceId, ct);
        var state = await LoadAsync(ct);
        var repo = state.Repositories[ws.ProjectId];

        var json = await GhJsonAsync(
            ws.WorktreePath,
            ["pr", "view", number.ToString(), "--repo", repo.RepositoryFullName,
             "--json", "number,url,state,headRefName,baseRefName,mergedAt"],
            ct);
        return ParsePullRequest(json.RootElement);
    }

    public async Task LaunchAgentAsync(string workspaceId, string provider, CancellationToken ct)
    {
        if (provider is not ("codex" or "claude" or "gemini"))
            throw GitWorkspaceException.Invalid("Provider local no soportado.");

        var ws = await RequireWorkspaceAsync(workspaceId, ct);
        var executable = RequireExecutable(provider);

        // Lanza el CLI sin shell y sin interpolar contenido de la tarea.
        var start = new ProcessStartInfo(executable)
        {
            WorkingDirectory = ws.WorktreePath,
            UseShellExecute = true,
        };
        try
        {
            _ = Process.Start(start)
                ?? throw GitWorkspaceException.CommandFailed($"No se pudo iniciar {provider}.");
        }
        catch (System.ComponentModel.Win32Exception e)
        {
            log.LogWarning(e, "No se pudo iniciar {Provider}", provider);
            throw GitWorkspaceException.CommandFailed($"No se pudo iniciar {provider}.");
        }
    }

    private async Task<WorkspaceInfo> RequireWorkspaceAsync(string workspaceId, CancellationToken ct)
    {
        var state = await LoadAsync(ct);
        if (!state.Workspaces.TryGetValue(workspaceId, out var ws))
            throw GitWorkspaceException.NotConfigured("Workspace no registrado.");
        if (!Directory.Exists(ws.WorktreePath))
            throw GitWorkspaceException.NotConfigured("El worktree registrado ya no existe.");
        return ws;
    }

    private string RequireExecutable(string name) =>
        executables.Find(name) ?? throw GitWorkspaceException.NotConfigured($"{name} no está disponible en PATH.");

    private static void ValidateRelativeFile(string root, string relative)
    {
        if (string.IsNullOrWhiteSpace(relative) || Path.IsPathRooted(relative))
            throw GitWorkspaceException.Invalid("Ruta de archivo inválida.");

        var full = Path.GetFullPath(Path.Combine(root, relative));
        if (!IsSameOrChild(full, root))
            throw GitWorkspaceException.Invalid("El archivo sale del worktree.");
    }

    private static List<string> ParseChangedFiles(string output)
    {
        var result = new List<string>();
        foreach (var raw in output.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            if (raw.Length < 4) continue;
            var path = raw[3..].Trim();
            var arrow = path.IndexOf(" -> ", StringComparison.Ordinal);
            if (arrow >= 0) path = path[(arrow + 4)..];
            if (path.Length > 0) result.Add(path);
        }
        return result.Distinct(StringComparer.Ordinal).Order().ToList();
    }

    private async Task<CommandOutput> GitAsync(string workingDirectory, IReadOnlyList<string> args, CancellationToken ct)
    {
        var output = await RunAsync(RequireExecutable("git"), workingDirectory, args, ct);
        if (output.ExitCode != 0)
            throw GitWorkspaceException.CommandFailed(output.Stderr.Trim().Length == 0
                ? "Git terminó con error."
                : output.Stderr.Trim());
        return output;
    }

    private async Task<int> GitExitAsync(string workingDirectory, IReadOnlyList<string> args, CancellationToken ct) =>
        (await RunAsync(RequireExecutable("git"), workingDirectory, args, ct)).ExitCode;

    private async Task<JsonDocument> GhJsonAsync(string workingDirectory, IReadOnlyList<string> args, CancellationToken ct)
    {
        var output = await RunAsync(RequireExecutable("gh"), workingDirectory, args, ct);
        if (output.ExitCode != 0)
            throw GitWorkspaceException.CommandFailed(output.Stderr.Trim().Length == 0
                ? "GitHub CLI terminó con error."
                : output.Stderr.Trim());
        try
        {
            return JsonDocument.Parse(output.Stdout);
        }
        catch (JsonException)
        {
            throw GitWorkspaceException.CommandFailed("GitHub CLI devolvió JSON inválido.");
        }
    }

    private static async Task<CommandOutput> RunAsync(
        string executable,
        string workingDirectory,
        IReadOnlyList<string> args,
        CancellationToken ct)
    {
        var start = new ProcessStartInfo(executable)
        {
            WorkingDirectory = workingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };
        foreach (var arg in args) start.ArgumentList.Add(arg);

        using var process = Process.Start(start)
            ?? throw GitWorkspaceException.CommandFailed("No se pudo iniciar el proceso.");
        var stdout = process.StandardOutput.ReadToEndAsync(ct);
        var stderr = process.StandardError.ReadToEndAsync(ct);
        await process.WaitForExitAsync(ct);
        return new CommandOutput(process.ExitCode, await stdout, await stderr);
    }

    private async Task<WorkspaceState> LoadAsync(CancellationToken ct)
    {
        await _gate.WaitAsync(ct);
        try
        {
            if (!File.Exists(_stateFile)) return new();
            var json = await File.ReadAllTextAsync(_stateFile, ct);
            return JsonSerializer.Deserialize<WorkspaceState>(json) ?? new();
        }
        catch (JsonException)
        {
            throw GitWorkspaceException.Conflict("La configuración local de workspaces está dañada.");
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task SaveAsync(WorkspaceState state, CancellationToken ct)
    {
        await _gate.WaitAsync(ct);
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_stateFile)!);
            var tmp = _stateFile + ".tmp";
            await File.WriteAllTextAsync(tmp, JsonSerializer.Serialize(state), ct);
            File.Move(tmp, _stateFile, true);
        }
        finally
        {
            _gate.Release();
        }
    }

    private static string CanonicalDirectory(string path) =>
        Path.TrimEndingDirectorySeparator(Path.GetFullPath(path));

    private static bool IsSameOrChild(string candidate, string root)
    {
        candidate = CanonicalDirectory(candidate);
        root = CanonicalDirectory(root);
        if (string.Equals(candidate, root, StringComparison.Ordinal)) return true;
        return candidate.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.Ordinal);
    }

    private static string Slug(string value)
    {
        var lower = value.Trim().ToLowerInvariant().Replace('_', '-').Replace(' ', '-');
        lower = SafeSegment.Replace(lower, "-");
        return lower.Trim('-');
    }

    private static string BranchName(string value)
    {
        var branch = value.Trim();
        if (string.IsNullOrWhiteSpace(branch) ||
            branch.StartsWith('-') ||
            branch.Contains("..", StringComparison.Ordinal) ||
            branch.Any(char.IsWhiteSpace) ||
            branch.IndexOfAny(['~', '^', ':', '?', '*', '[', '\\']) >= 0)
            throw GitWorkspaceException.Invalid("Rama objetivo inválida.");
        return branch;
    }

    private static string NormalizeRemote(string remote)
    {
        var value = remote.Trim();
        const string sshPrefix = "git@github.com:";
        if (value.StartsWith(sshPrefix, StringComparison.OrdinalIgnoreCase))
            value = value[sshPrefix.Length..];
        else if (Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
                 string.Equals(uri.Host, "github.com", StringComparison.OrdinalIgnoreCase))
            value = uri.AbsolutePath.TrimStart('/');
        value = value.Trim('/');
        if (value.EndsWith(".git", StringComparison.OrdinalIgnoreCase))
            value = value[..^4];
        return value.ToLowerInvariant();
    }

    private static bool RemoteMatches(string remote, string expected) =>
        string.Equals(NormalizeRemote(remote), NormalizeRemote(expected), StringComparison.Ordinal);

    private static string WorkspaceKey(string projectId, string externalId)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes($"{projectId}\n{externalId}"));
        return Convert.ToHexString(bytes[..12]).ToLowerInvariant();
    }

    private static PullRequestInfo ParsePullRequest(JsonElement e) => new(
        e.GetProperty("number").GetInt32(),
        e.GetProperty("url").GetString() ?? "",
        e.GetProperty("state").GetString() ?? "",
        e.GetProperty("headRefName").GetString() ?? "",
        e.GetProperty("baseRefName").GetString() ?? "",
        e.TryGetProperty("mergedAt", out var merged) && merged.ValueKind == JsonValueKind.String
            ? merged.GetDateTimeOffset()
            : null);

    private sealed record CommandOutput(int ExitCode, string Stdout, string Stderr);
}

public sealed class WorkspaceState
{
    public Dictionary<string, RepositoryMapping> Repositories { get; init; } = new();
    public Dictionary<string, WorkspaceInfo> Workspaces { get; init; } = new();
}

public sealed record RepositoryMapping(
    string ProjectId,
    string ProjectSlug,
    string RepositoryFullName,
    string RepositoryPath);

public sealed record WorkspaceInfo(
    string WorkspaceId,
    string ProjectId,
    string ExternalId,
    string RepositoryPath,
    string WorktreePath,
    string Branch,
    string TargetBranch,
    string Provider);

public sealed record WorkspaceStatus(
    string WorkspaceId,
    string Branch,
    bool Dirty,
    IReadOnlyList<string> ChangedFiles,
    int Ahead,
    int Behind);

public sealed record CommitResult(string Sha);

public sealed record PullRequestInfo(
    int Number,
    string Url,
    string State,
    string HeadRefName,
    string BaseRefName,
    DateTimeOffset? MergedAt);

public sealed record ConfigureRepositoryRequest(
    string? ProjectId,
    string? ProjectSlug,
    string? RepositoryFullName,
    string? RepositoryPath);

public sealed record PrepareWorkspaceRequest(
    string? ProjectId,
    string? ExternalId,
    string? TaskTitle,
    string? TargetBranch,
    string? Provider);

public sealed record CommitWorkspaceRequest(
    string? WorkspaceId,
    string[]? Files,
    string? Message);

public sealed record PushWorkspaceRequest(string? WorkspaceId);
public sealed record LaunchAgentRequest(string? WorkspaceId, string? Provider);

public sealed record PullRequestWorkspaceRequest(
    string? WorkspaceId,
    string? Title,
    string? Body);

public sealed class GitWorkspaceException(int status, string code, string message) : Exception(message)
{
    public int Status { get; } = status;
    public string Code { get; } = code;

    public static GitWorkspaceException Invalid(string message) => new(422, "invalid_workspace_request", message);
    public static GitWorkspaceException RemoteMismatch(string expected) => new(422, "remote_mismatch", $"El remote origin no corresponde con {expected}.");
    public static GitWorkspaceException NotConfigured(string message = "Configura primero el repositorio local.") => new(409, "workspace_not_configured", message);
    public static GitWorkspaceException Conflict(string message) => new(409, "workspace_conflict", message);
    public static GitWorkspaceException CommandFailed(string message) => new(502, "workspace_command_failed", message);
}
