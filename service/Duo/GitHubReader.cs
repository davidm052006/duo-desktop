using LibGit2Sharp;
using Octokit;

namespace DuoDesktop.Service.Duo;

/// Obtiene ramas y pull requests del remoto origin en GitHub mediante Octokit.
public sealed class GitHubReader(DuoProjectLocator locator, ILogger<GitHubReader> log)
{
    public async Task<GitHubResponse> ReadAsync(CancellationToken cancellationToken = default)
    {
        var project = locator.Active();
        var (owner, name) = GitHubRepository(project);
        var client = CreateClient();

        try
        {
            // Las dos consultas son independientes y no modifican el repositorio.
            var branchesTask = client.Repository.Branch.GetAll(owner, name);
            var pullRequestsTask = client.PullRequest.GetAllForRepository(owner, name,
                new PullRequestRequest { State = ItemStateFilter.All });
            await Task.WhenAll(branchesTask, pullRequestsTask).WaitAsync(cancellationToken);

            var branches = branchesTask.Result
                .Select(branch => new BranchDto(branch.Name, branch.Commit.Sha, branch.Protected))
                .ToList();
            var pullRequests = pullRequestsTask.Result
                .Select(pullRequest => new PullRequestDto(
                    pullRequest.Number,
                    pullRequest.Title,
                    pullRequest.State.StringValue,
                    pullRequest.User.Login,
                    pullRequest.Head.Ref,
                    pullRequest.Base.Ref,
                    pullRequest.HtmlUrl,
                    pullRequest.UpdatedAt))
                .ToList();

            return new GitHubResponse(branches, pullRequests);
        }
        catch (Octokit.NotFoundException e)
        {
            throw BoardException.NotFound($"GitHub no encontró {owner}/{name}: {e.Message}");
        }
        catch (Exception e) when (e is ApiException or HttpRequestException or TaskCanceledException)
        {
            log.LogError(e, "no pude consultar GitHub para {Repository}", $"{owner}/{name}");
            throw BoardException.ReadFailed(e.Message);
        }
    }

    private static GitHubClient CreateClient()
    {
        var client = new GitHubClient(new ProductHeaderValue("duo-desktop"));
        var token = Environment.GetEnvironmentVariable("GITHUB_TOKEN")
            ?? Environment.GetEnvironmentVariable("GH_TOKEN");
        if (!string.IsNullOrWhiteSpace(token))
            client.Credentials = new Octokit.Credentials(token);
        return client;
    }

    private static (string Owner, string Name) GitHubRepository(DuoProject project)
    {
        if (string.IsNullOrWhiteSpace(project.RepoDir) || !LibGit2Sharp.Repository.IsValid(project.RepoDir))
            throw BoardException.NotFound($"{project.RepoDir} no es un repositorio Git válido");

        try
        {
            using var repository = new LibGit2Sharp.Repository(project.RepoDir);
            var url = repository.Network.Remotes["origin"]?.Url;
            if (!TryParseGitHubRemote(url, out var owner, out var name))
                throw BoardException.NotFound("origin no apunta a un repositorio de github.com");
            return (owner, name);
        }
        catch (BoardException)
        {
            throw;
        }
        catch (Exception e) when (e is LibGit2SharpException or IOException or UnauthorizedAccessException)
        {
            throw BoardException.ReadFailed(e.Message);
        }
    }

    internal static bool TryParseGitHubRemote(string? url, out string owner, out string name)
    {
        owner = name = string.Empty;
        if (string.IsNullOrWhiteSpace(url)) return false;

        var normalized = url.Trim();
        const string sshPrefix = "git@github.com:";
        if (normalized.StartsWith(sshPrefix, StringComparison.OrdinalIgnoreCase))
            normalized = normalized[sshPrefix.Length..];
        else if (Uri.TryCreate(normalized, UriKind.Absolute, out var uri) &&
                 string.Equals(uri.Host, "github.com", StringComparison.OrdinalIgnoreCase))
            normalized = uri.AbsolutePath.TrimStart('/');
        else
            return false;

        var parts = normalized.TrimEnd('/').Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length != 2 || string.IsNullOrWhiteSpace(parts[0])) return false;

        owner = parts[0];
        name = parts[1].EndsWith(".git", StringComparison.OrdinalIgnoreCase)
            ? parts[1][..^4]
            : parts[1];
        return !string.IsNullOrWhiteSpace(name);
    }
}
