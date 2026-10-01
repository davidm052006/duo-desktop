using LibGit2Sharp;

namespace DuoDesktop.Service.Duo;

/// Lee los commits del repositorio de trabajo; nunca invoca el ejecutable git.
public sealed class HistoryReader(DuoProjectLocator locator, ILogger<HistoryReader> log)
{
    private const int RecentCommitLimit = 50;

    public HistoryResponse Read()
    {
        var project = locator.Active();
        if (string.IsNullOrWhiteSpace(project.RepoDir) || !Repository.IsValid(project.RepoDir))
            throw BoardException.NotFound($"{project.RepoDir} no es un repositorio Git válido");

        try
        {
            using var repository = new Repository(project.RepoDir);
            var commits = repository.Commits
                .Take(RecentCommitLimit)
                .Select(commit => new CommitDto(
                    commit.Sha,
                    commit.MessageShort,
                    commit.Author.Name,
                    commit.Author.When))
                .ToList();

            return new HistoryResponse(commits);
        }
        catch (Exception e) when (e is LibGit2SharpException or IOException or UnauthorizedAccessException)
        {
            log.LogError(e, "no pude leer el historial Git de {Project}", project.Name);
            throw BoardException.ReadFailed(e.Message);
        }
    }
}
