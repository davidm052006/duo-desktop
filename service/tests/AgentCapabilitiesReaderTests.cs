using DuoDesktop.Service.Duo;
using Xunit;

namespace DuoDesktop.Service.Tests;

public sealed class AgentCapabilitiesReaderTests
{
    [Fact]
    public void ReportsOnlyTheSupportedLocalProviders()
    {
        var reader = new AgentCapabilitiesReader(new FakeLocator(
            ("codex", "/usr/local/bin/codex"),
            ("claude", "/usr/local/bin/claude")));

        var capabilities = reader.Read();

        Assert.Collection(capabilities,
            codex =>
            {
                Assert.Equal("codex", codex.Provider);
                Assert.True(codex.Available);
                Assert.Equal("/usr/local/bin/codex", codex.Executable);
            },
            claude =>
            {
                Assert.Equal("claude", claude.Provider);
                Assert.True(claude.Available);
            },
            gemini =>
            {
                Assert.Equal("gemini", gemini.Provider);
                Assert.False(gemini.Available);
                Assert.Null(gemini.Executable);
            });
    }

    [Fact]
    public void DoesNotProbeWebProviders()
    {
        var locator = new FakeLocator();
        var reader = new AgentCapabilitiesReader(locator);

        _ = reader.Read();

        Assert.DoesNotContain("chatgpt", locator.Requested);
        Assert.DoesNotContain("grok", locator.Requested);
    }

    private sealed class FakeLocator(params (string Provider, string Path)[] available) : IExecutableLocator
    {
        private readonly Dictionary<string, string> _available = available.ToDictionary(x => x.Provider, x => x.Path);
        public List<string> Requested { get; } = [];

        public string? Find(string executable)
        {
            Requested.Add(executable);
            return _available.GetValueOrDefault(executable);
        }
    }
}
