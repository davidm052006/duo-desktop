using DuoDesktop.Service.Duo;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DuoDesktop.Service.Tests;

[Collection("environment")]
public sealed class QuestionReaderTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"duo-questions-{Guid.NewGuid():N}");
    private readonly string? _oldConf = Environment.GetEnvironmentVariable("DUO_CONF");
    private readonly string? _oldProject = Environment.GetEnvironmentVariable("DUO_P");

    [Fact]
    public void Read_returns_the_unmodified_markdown_with_its_task_and_owner()
    {
        var board = ConfigureProject();
        var questions = Path.Combine(board, ".team", "preguntas");
        Directory.CreateDirectory(questions);
        const string markdown = "## PREGUNTA\n\n¿Publicamos hoy?\n\n- opción A\n";
        File.WriteAllText(Path.Combine(questions, "T-019.md"), markdown);

        var response = NewReader().Read();

        var question = Assert.Single(response.Questions);
        Assert.Equal("T-019", question.Id);
        Assert.Equal("codex", question.Agent);
        Assert.Equal("Implementar streaming", question.Task.Title);
        Assert.Equal(markdown, question.Content);
    }

    [Fact]
    public void Read_returns_an_empty_list_when_the_questions_directory_does_not_exist()
    {
        ConfigureProject();

        var response = NewReader().Read();

        Assert.Empty(response.Questions);
    }

    [Fact]
    public void Read_accepts_a_legacy_project_path_in_duo_p()
    {
        var board = ConfigureProject();
        Environment.SetEnvironmentVariable("DUO_P", board);

        var response = NewReader().Read();

        Assert.Empty(response.Questions);
    }

    [Fact]
    public void Read_rejects_a_question_without_a_board_task()
    {
        var board = ConfigureProject();
        var questions = Path.Combine(board, ".team", "preguntas");
        Directory.CreateDirectory(questions);
        File.WriteAllText(Path.Combine(questions, "T-999.md"), "## PREGUNTA\n\n¿Sigo?\n");

        var error = Assert.Throws<BoardException>(() => NewReader().Read());

        Assert.Equal(422, error.Status);
        Assert.Equal("invalid_board", error.Code);
    }

    public void Dispose()
    {
        Environment.SetEnvironmentVariable("DUO_CONF", _oldConf);
        Environment.SetEnvironmentVariable("DUO_P", _oldProject);
        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
    }

    private QuestionReader NewReader()
    {
        var locator = new DuoProjectLocator(NullLogger<DuoProjectLocator>.Instance);
        return new QuestionReader(locator, new BoardReader(locator, NullLogger<BoardReader>.Instance),
            NullLogger<QuestionReader>.Instance);
    }

    private string ConfigureProject()
    {
        var repo = Path.Combine(_root, "repo");
        var board = Path.Combine(_root, "board");
        var conf = Path.Combine(_root, "conf");
        Directory.CreateDirectory(repo);
        Directory.CreateDirectory(Path.Combine(board, ".team"));
        Directory.CreateDirectory(conf);
        File.WriteAllText(Path.Combine(board, ".team", "BOARD.md"), """
            | Tarea | Título | Dueño | Rama | Estado | Abierta |
            | --- | --- | --- | --- | --- | --- |
            | T-019 | Implementar streaming | codex | codex/t-019 | haciendo | 2026-10-01 |
            """);
        File.WriteAllText(Path.Combine(board, ".team", "ledger.tsv"), """
            agente	puntos	tareas	ultima
            codex	1	1	2026-10-01
            """);
        File.WriteAllText(Path.Combine(conf, "test.conf"),
            $"set -g DUO_PROJECT test\nset -g REPO_DIR {repo}\nset -g BOARD {board}\n");
        Environment.SetEnvironmentVariable("DUO_CONF", conf);
        Environment.SetEnvironmentVariable("DUO_P", "test");
        return board;
    }
}
