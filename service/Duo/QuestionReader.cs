using System.Text.RegularExpressions;

namespace DuoDesktop.Service.Duo;

/// Lee las preguntas que el CLI dejó en el worktree de la pizarra. No intenta
/// interpretar ni resumir Markdown: el contenido que ve el usuario es el que
/// escribió el agente.
public sealed class QuestionReader(DuoProjectLocator locator, BoardReader boardReader, ILogger<QuestionReader> log)
{
    private static readonly Regex QuestionFile = new(@"^(?<id>T-\d+)\.md$", RegexOptions.Compiled);

    public QuestionsResponse Read()
    {
        var project = locator.Active();
        var board = boardReader.Read();
        if (!Directory.Exists(project.QuestionsDir)) return new QuestionsResponse([]);

        try
        {
            var tasks = board.Board.Tasks.ToDictionary(task => task.Id, StringComparer.Ordinal);
            var questions = new List<QuestionDto>();

            foreach (var path in Directory.EnumerateFiles(project.QuestionsDir, "*.md").OrderBy(path => path))
            {
                var match = QuestionFile.Match(Path.GetFileName(path));
                if (!match.Success) continue;

                var id = match.Groups["id"].Value;
                if (!tasks.TryGetValue(id, out var task))
                    throw BoardException.Invalid($"pregunta {id} sin tarea correspondiente en BOARD.md");

                questions.Add(new QuestionDto(id, task, task.Owner, File.ReadAllText(path)));
            }

            return new QuestionsResponse(questions);
        }
        catch (BoardException) { throw; }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            log.LogError(e, "no pude leer las preguntas de {Project}", project.Name);
            throw BoardException.ReadFailed(e.Message);
        }
    }
}
