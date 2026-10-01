using System.Diagnostics;
using System.Text.RegularExpressions;

namespace DuoDesktop.Service.Duo;

/// Ejecuta el CLI oficial en el proyecto activo. El servicio no reproduce la
/// lógica de asignación ni de reanudación: esa lógica sigue siendo de `duo`.
public sealed class DuoCommandRunner(DuoProjectLocator locator, ILogger<DuoCommandRunner> log)
{
    private static readonly Regex CreatedTask = new(@"(?m)^\s*(?<id>T-\d+)\s+→", RegexOptions.Compiled);
    private static readonly Regex AnsiEscape = new(@"\x1B\[[0-?]*[ -/]*[@-~]", RegexOptions.Compiled);

    public async Task<string> CreateTaskAsync(string text, CancellationToken cancellationToken)
    {
        var result = await RunAsync([text], cancellationToken);
        var match = CreatedTask.Match(AnsiEscape.Replace(result.Output, ""));
        if (!match.Success)
            throw DuoCommandException.Failed("duo terminó sin informar el identificador de la tarea", result.Output);

        return match.Groups["id"].Value;
    }

    public async Task AnswerQuestionAsync(string id, string text, CancellationToken cancellationToken)
    {
        await RunAsync(["answer", id, text], cancellationToken);
    }

    private async Task<CommandResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken)
    {
        DuoProject project;
        try
        {
            project = locator.Active();
        }
        catch (BoardException e) when (e.Status == 404)
        {
            throw DuoCommandException.ProjectNotFound(e.Detail ?? e.Message);
        }
        if (!Directory.Exists(project.RepoDir) || !Directory.Exists(project.BoardDir))
            throw DuoCommandException.ProjectNotFound($"repo={project.RepoDir}; board={project.BoardDir}");

        var executable = Environment.GetEnvironmentVariable("DUO_EXECUTABLE");
        if (string.IsNullOrWhiteSpace(executable)) executable = "duo";

        var start = new ProcessStartInfo(executable)
        {
            WorkingDirectory = project.RepoDir,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };
        foreach (var argument in arguments) start.ArgumentList.Add(argument);
        // El proceso puede no heredar el directorio desde el que se inició el
        // servicio. DUO_P hace que el CLI elija exactamente este proyecto.
        start.Environment["DUO_P"] = project.Name;

        try
        {
            using var process = Process.Start(start)
                ?? throw DuoCommandException.Failed("no se pudo iniciar el proceso duo", null);
            var stdout = process.StandardOutput.ReadToEndAsync(cancellationToken);
            var stderr = process.StandardError.ReadToEndAsync(cancellationToken);
            await process.WaitForExitAsync(cancellationToken);
            var output = (await stdout) + (await stderr);

            if (process.ExitCode != 0)
                throw DuoCommandException.Failed($"duo terminó con código {process.ExitCode}", output);

            return new CommandResult(output);
        }
        catch (DuoCommandException) { throw; }
        catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException)
        {
            log.LogError(e, "no se pudo ejecutar duo");
            throw DuoCommandException.Failed("no se pudo ejecutar duo", e.Message);
        }
    }

    private sealed record CommandResult(string Output);
}

public sealed class DuoCommandException(int status, string code, string message, string? detail = null)
    : Exception(message)
{
    public int Status { get; } = status;
    public string Code { get; } = code;
    public string? Detail { get; } = detail;

    public static DuoCommandException ProjectNotFound(string detail) => new(
        404, "project_not_found", "No se encontró el proyecto activo de duo.", detail);

    public static DuoCommandException Failed(string detail, string? output) => new(
        500, "duo_command_failed", "No se pudo ejecutar duo.",
        output is null ? detail : $"{detail}: {output}");
}
