using DuoDesktop.Service.Duo;
using LibGit2Sharp;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DuoDesktop.Service.Tests;

[Collection("environment")]
public sealed class HistoryReaderTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"duo-history-{Guid.NewGuid():N}");
    private readonly string? _oldConf = Environment.GetEnvironmentVariable("DUO_CONF");
    private readonly string? _oldProject = Environment.GetEnvironmentVariable("DUO_P");

    [Fact]
    public void Read_returns_recent_commits_from_newest_to_oldest()
    {
        var repoDir = Path.Combine(_root, "repo");
        Directory.CreateDirectory(repoDir);
        Repository.Init(repoDir);
        using (var repo = new Repository(repoDir))
        {
            Commit(repo, "first", 1);
            Commit(repo, "second", 2);
        }
        ConfigureProject(repoDir);

        var reader = new HistoryReader(
            new DuoProjectLocator(NullLogger<DuoProjectLocator>.Instance),
            NullLogger<HistoryReader>.Instance);

        var history = reader.Read();

        Assert.Collection(history.Commits,
            commit => Assert.Equal("second", commit.Message),
            commit => Assert.Equal("first", commit.Message));
    }

    [Fact]
    public void Read_limits_the_response_to_fifty_commits()
    {
        var repoDir = Path.Combine(_root, "repo");
        Directory.CreateDirectory(repoDir);
        Repository.Init(repoDir);
        using (var repo = new Repository(repoDir))
        {
            for (var i = 0; i < 51; i++) Commit(repo, $"commit {i}", i);
        }
        ConfigureProject(repoDir);

        var reader = new HistoryReader(
            new DuoProjectLocator(NullLogger<DuoProjectLocator>.Instance),
            NullLogger<HistoryReader>.Instance);

        var history = reader.Read();

        Assert.Equal(50, history.Commits.Count);
        Assert.Equal("commit 50", history.Commits[0].Message);
        Assert.Equal("commit 1", history.Commits[^1].Message);
    }

    public void Dispose()
    {
        Environment.SetEnvironmentVariable("DUO_CONF", _oldConf);
        Environment.SetEnvironmentVariable("DUO_P", _oldProject);
        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
    }

    private void ConfigureProject(string repoDir)
    {
        var confDir = Path.Combine(_root, "conf");
        Directory.CreateDirectory(confDir);
        File.WriteAllText(Path.Combine(confDir, "test.conf"),
            $"set -g DUO_PROJECT test\nset -g REPO_DIR {repoDir}\nset -g BOARD {_root}\n");
        Environment.SetEnvironmentVariable("DUO_CONF", confDir);
        Environment.SetEnvironmentVariable("DUO_P", "test");
    }

    private static void Commit(Repository repo, string message, int sequence)
    {
        var path = Path.Combine(repo.Info.WorkingDirectory, "commits.txt");
        File.AppendAllText(path, message + Environment.NewLine);
        Commands.Stage(repo, "commits.txt");
        // LibGit2Sharp ordena los commits por la fecha de autor. Una fecha
        // distinta por commit evita que el orden topológico empate y vuelva
        // esta prueba no determinista en máquinas rápidas.
        var when = DateTimeOffset.UnixEpoch.AddMinutes(sequence);
        var author = new Signature("Test", "test@example.test", when);
        repo.Commit(message, author, author);
    }
}

[CollectionDefinition("environment", DisableParallelization = true)]
public sealed class EnvironmentCollection;
