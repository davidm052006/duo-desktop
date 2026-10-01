using DuoDesktop.Service.Duo;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DuoDesktop.Service.Tests;

[Collection("environment")]
public sealed class DuoCommandRunnerTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"duo-command-{Guid.NewGuid():N}");
    private readonly string? _oldConf = Environment.GetEnvironmentVariable("DUO_CONF");
    private readonly string? _oldProject = Environment.GetEnvironmentVariable("DUO_P");
    private readonly string? _oldExecutable = Environment.GetEnvironmentVariable("DUO_EXECUTABLE");

    [Fact]
    public async Task CreateTaskAsync_passes_text_as_one_argument_and_returns_cli_id()
    {
        var capture = ConfigureProject("printf 'T-042 → codex\\n'; printf '%s' \"$1\" > \"$CAPTURE\"");
        var runner = NewRunner();

        var id = await runner.CreateTaskAsync("texto con espacios; y $caracteres", CancellationToken.None);

        Assert.Equal("T-042", id);
        Assert.Equal("texto con espacios; y $caracteres", await File.ReadAllTextAsync(capture));
    }

    [Fact]
    public async Task AnswerQuestionAsync_invokes_duo_answer_with_id_and_text()
    {
        var capture = ConfigureProject("printf '%s|%s|%s' \"$1\" \"$2\" \"$3\" > \"$CAPTURE\"");
        var runner = NewRunner();

        await runner.AnswerQuestionAsync("T-007", "sí, continúa", CancellationToken.None);

        Assert.Equal("answer|T-007|sí, continúa", await File.ReadAllTextAsync(capture));
    }

    [Fact]
    public async Task CreateTaskAsync_returns_404_when_project_directory_is_missing()
    {
        ConfigureProject("exit 0", createDirectories: false);
        var runner = NewRunner();

        var error = await Assert.ThrowsAsync<DuoCommandException>(() =>
            runner.CreateTaskAsync("una tarea válida", CancellationToken.None));

        Assert.Equal(404, error.Status);
        Assert.Equal("project_not_found", error.Code);
    }

    public void Dispose()
    {
        Environment.SetEnvironmentVariable("DUO_CONF", _oldConf);
        Environment.SetEnvironmentVariable("DUO_P", _oldProject);
        Environment.SetEnvironmentVariable("DUO_EXECUTABLE", _oldExecutable);
        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
    }

    private DuoCommandRunner NewRunner() => new(
        new DuoProjectLocator(NullLogger<DuoProjectLocator>.Instance),
        NullLogger<DuoCommandRunner>.Instance);

    private string ConfigureProject(string scriptBody, bool createDirectories = true)
    {
        var repo = Path.Combine(_root, "repo");
        var board = Path.Combine(_root, "board");
        var conf = Path.Combine(_root, "conf");
        var capture = Path.Combine(_root, "arguments.txt");
        Directory.CreateDirectory(conf);
        if (createDirectories)
        {
            Directory.CreateDirectory(repo);
            Directory.CreateDirectory(board);
        }
        var executable = Path.Combine(_root, "fake-duo.sh");
        File.WriteAllText(executable, "#!/bin/sh\n" + scriptBody + "\n");
        File.SetUnixFileMode(executable, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        File.WriteAllText(Path.Combine(conf, "test.conf"),
            $"set -g DUO_PROJECT test\nset -g REPO_DIR {repo}\nset -g BOARD {board}\n");
        Environment.SetEnvironmentVariable("DUO_CONF", conf);
        Environment.SetEnvironmentVariable("DUO_P", "test");
        Environment.SetEnvironmentVariable("DUO_EXECUTABLE", executable);
        Environment.SetEnvironmentVariable("CAPTURE", capture);
        return capture;
    }
}
