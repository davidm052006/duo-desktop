using DuoDesktop.Service.Duo;
using Xunit;

namespace DuoDesktop.Service.Tests;

public sealed class GitHubReaderTests
{
    [Theory]
    [InlineData("https://github.com/octo/example.git", "octo", "example")]
    [InlineData("git@github.com:octo/example.git", "octo", "example")]
    [InlineData("ssh://git@github.com/octo/example", "octo", "example")]
    public void TryParseGitHubRemote_accepts_supported_origin_urls(string url, string owner, string name)
    {
        var parsed = GitHubReader.TryParseGitHubRemote(url, out var actualOwner, out var actualName);

        Assert.True(parsed);
        Assert.Equal(owner, actualOwner);
        Assert.Equal(name, actualName);
    }

    [Theory]
    [InlineData("https://gitlab.com/octo/example.git")]
    [InlineData("https://github.com/octo")]
    [InlineData("")]
    public void TryParseGitHubRemote_rejects_non_repository_urls(string url)
    {
        var parsed = GitHubReader.TryParseGitHubRemote(url, out _, out _);

        Assert.False(parsed);
    }
}
