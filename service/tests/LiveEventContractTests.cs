using System.Text.Json;
using DuoDesktop.Service.Duo;
using Xunit;

namespace DuoDesktop.Service.Tests;

public sealed class LiveEventContractTests
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    [Fact]
    public void Agent_output_event_uses_the_documented_wire_shape()
    {
        var json = JsonSerializer.Serialize(new AgentOutputEvent(
            "agent_output", "T-019", "codex", "primera línea\n"), Json);

        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        Assert.Equal("agent_output", root.GetProperty("type").GetString());
        Assert.Equal("T-019", root.GetProperty("taskId").GetString());
        Assert.Equal("codex", root.GetProperty("agent").GetString());
        Assert.Equal("primera línea\n", root.GetProperty("text").GetString());
    }

    [Fact]
    public void Board_snapshot_event_carries_the_full_board_response()
    {
        var board = new BoardResponse(
            new ProjectDto("demo", "/repo", "/board"),
            new BoardDto([new TaskDto("T-019", "Streaming", "codex", "branch", "haciendo", "2026-10-01")]),
            new LedgerDto([]));

        var json = JsonSerializer.Serialize(new BoardEvent("board_snapshot", board), Json);

        using var document = JsonDocument.Parse(json);
        var payload = document.RootElement;
        Assert.Equal("board_snapshot", payload.GetProperty("type").GetString());
        Assert.Equal("T-019", payload.GetProperty("board").GetProperty("board")
            .GetProperty("tasks")[0].GetProperty("id").GetString());
    }
}
