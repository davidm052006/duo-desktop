using DuoDesktop.Cloud.Auth;
using DuoDesktop.Cloud.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace DuoDesktop.Cloud.Realtime;

[Authorize]
public sealed class ProjectHub(
    DuoCloudDbContext db,
    CurrentUser currentUser) : Hub
{
    public async Task SubscribeProject(Guid projectId)
    {
        var principal = Context.User
            ?? throw new HubException("Conexión sin identidad autenticada.");
        var user = await currentUser.GetOrCreateAsync(
            principal,
            db,
            Context.ConnectionAborted);
        var allowed = await db.ProjectMembers.AnyAsync(
            x => x.ProjectId == projectId && x.UserId == user.Id,
            Context.ConnectionAborted);

        if (!allowed)
            throw new HubException("No perteneces a este proyecto.");

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            GroupName(projectId),
            Context.ConnectionAborted);
    }

    public Task UnsubscribeProject(Guid projectId) =>
        Groups.RemoveFromGroupAsync(
            Context.ConnectionId,
            GroupName(projectId),
            Context.ConnectionAborted);

    public static string GroupName(Guid projectId) => $"project:{projectId:N}";
}
