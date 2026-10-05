using DuoDesktop.Service.Duo;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DuoDesktop.Service.Tests;

[Collection("environment")]
public sealed class DuoProjectLocatorTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"duo-locator-{Guid.NewGuid():N}");
    private readonly string? _oldConf = Environment.GetEnvironmentVariable("DUO_CONF");
    private readonly string? _oldProject = Environment.GetEnvironmentVariable("DUO_P");

    [Fact]
    public void Active_uses_desktop_default_for_legacy_launchers_without_duo_p()
    {
        WriteProject("another-project");
        WriteProject("duo-desktop");
        Environment.SetEnvironmentVariable("DUO_P", null);

        var active = new DuoProjectLocator(NullLogger<DuoProjectLocator>.Instance).Active();

        Assert.Equal("duo-desktop", active.Name);
    }

    public void Dispose()
    {
        Environment.SetEnvironmentVariable("DUO_CONF", _oldConf);
        Environment.SetEnvironmentVariable("DUO_P", _oldProject);
        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
    }

    private void WriteProject(string name)
    {
        var conf = Path.Combine(_root, "conf");
        var board = Path.Combine(_root, name, "board");
        Directory.CreateDirectory(conf);
        Directory.CreateDirectory(board);
        File.WriteAllText(Path.Combine(conf, $"{name}.conf"),
            $"set -g DUO_PROJECT {name}\nset -g REPO_DIR {_root}\nset -g BOARD {board}\n");
        Environment.SetEnvironmentVariable("DUO_CONF", conf);
    }
}
