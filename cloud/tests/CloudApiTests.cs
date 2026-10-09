using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using DuoDesktop.Cloud.Data;
using DuoDesktop.Cloud.Domain;
using DuoDesktop.Cloud.Email;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Xunit;

namespace DuoDesktop.Cloud.Tests;

public sealed class CloudApiTests : IClassFixture<CloudApiFactory>
{
    private readonly CloudApiFactory _factory;

    public CloudApiTests(CloudApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Authenticated_user_can_get_me_and_create_project_as_owner()
    {
        var client = _factory.Client("user-001", "david@example.test");
        var me = await client.GetAsync("/api/me");
        Assert.Equal(HttpStatusCode.OK, me.StatusCode);

        var created = await client.PostAsJsonAsync("/api/projects", new { name = "Demo", slug = "demo", repositoryFullName = "duo/demo", targetBranch = "develop" });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var project = await created.Content.ReadFromJsonAsync<ProjectDto>();
        Assert.NotNull(project);
        Assert.Equal("owner", project!.role);

        await using var db = _factory.Db();
        var member = await db.ProjectMembers.SingleAsync(x => x.ProjectId == project.id);
        Assert.Equal(ProjectRoles.Owner, member.Role);
    }

    [Fact]
    public async Task External_user_cannot_read_project()
    {
        var project = await CreateProjectAsync("owner-1", "owner@example.test", "private-project");
        var response = await _factory.Client("outside-1", "outside@example.test")
            .GetAsync($"/api/projects/{project.id}/tasks");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Theory]
    [InlineData("owner", true, true)]
    [InlineData("editor", true, false)]
    [InlineData("viewer", false, false)]
    public async Task Roles_enforce_write_and_invite(string role, bool canWrite, bool canInvite)
    {
        var project = await CreateProjectAsync("owner-role", "owner-role@example.test", $"roles-{role}");
        await AddMemberAsync(project.id, $"{role}-user", $"{role}@example.test", role);
        var client = _factory.Client($"{role}-user", $"{role}@example.test");

        var read = await client.GetAsync($"/api/projects/{project.id}/tasks");
        Assert.Equal(HttpStatusCode.OK, read.StatusCode);
        var upsert = await client.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert", TaskRequest("T-1"));
        Assert.Equal(canWrite ? HttpStatusCode.OK : HttpStatusCode.Forbidden, upsert.StatusCode);

        var invite = await client.PostAsJsonAsync($"/api/projects/{project.id}/invitations", new { email = "new@example.test", role = "viewer" });
        Assert.Equal(canInvite ? HttpStatusCode.Created : HttpStatusCode.Forbidden, invite.StatusCode);
    }

    [Fact]
    public async Task Invitations_hash_token_reject_owner_and_accept_once_for_matching_email()
    {
        var project = await CreateProjectAsync("invite-owner", "owner-invite@example.test", "invites");
        var owner = _factory.Client("invite-owner", "owner-invite@example.test");
        var invalid = await owner.PostAsJsonAsync($"/api/projects/{project.id}/invitations", new { email = "invitee@example.test", role = "owner" });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, invalid.StatusCode);

        var invitation = await owner.PostAsJsonAsync($"/api/projects/{project.id}/invitations", new { email = "invitee@example.test", role = "editor" });
        Assert.Equal(HttpStatusCode.Created, invitation.StatusCode);
        var body = await invitation.Content.ReadFromJsonAsync<InvitationDto>();
        Assert.NotNull(body);
        Assert.True(body!.emailSent);

        var sender = _factory.Services.GetRequiredService<TestInvitationEmailSender>();
        var inviteToken = sender.TokenFor("invitee@example.test");
        Assert.False(string.IsNullOrWhiteSpace(inviteToken));
        Assert.DoesNotContain(
            "inviteToken",
            await invitation.Content.ReadAsStringAsync(),
            StringComparison.OrdinalIgnoreCase);

        await using (var db = _factory.Db())
        {
            var stored = await db.ProjectInvitations.SingleAsync(x => x.Id == body.id);
            Assert.Equal(Hash(inviteToken), stored.TokenHash);
            Assert.NotEqual(inviteToken, stored.TokenHash);
        }

        var mismatch = await _factory.Client("other", "other@example.test")
            .PostAsync($"/api/invitations/{inviteToken}/accept", null);
        Assert.Equal(HttpStatusCode.Forbidden, mismatch.StatusCode);

        var accepted = await _factory.Client("invitee", "invitee@example.test")
            .PostAsync($"/api/invitations/{inviteToken}/accept", null);
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        var again = await _factory.Client("invitee", "invitee@example.test")
            .PostAsync($"/api/invitations/{inviteToken}/accept", null);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);

        await using var verify = _factory.Db();
        Assert.Equal(2, await verify.ProjectMembers.CountAsync(x => x.ProjectId == project.id));
        Assert.Single(await verify.ProjectMembers.Where(x => x.ProjectId == project.id && x.Role == "editor").ToListAsync());
    }

    [Fact]
    public async Task Expired_invitation_fails()
    {
        var project = await CreateProjectAsync("expire-owner", "expire-owner@example.test", "expired");
        var token = "expired-token";
        await using (var db = _factory.Db())
        {
            var owner = await db.Users.SingleAsync(x => x.AuthSubject == "expire-owner");
            db.ProjectInvitations.Add(new ProjectInvitation { Id = Guid.NewGuid(), ProjectId = project.id, InvitedByUserId = owner.Id, EmailNormalized = "invitee@example.test", Role = "viewer", TokenHash = Hash(token), CreatedAt = DateTimeOffset.UtcNow.AddDays(-8), ExpiresAt = DateTimeOffset.UtcNow.AddDays(-1) });
            await db.SaveChangesAsync();
        }
        var response = await _factory.Client("invitee-expired", "invitee@example.test").PostAsync($"/api/invitations/{token}/accept", null);
        Assert.Equal(HttpStatusCode.Gone, response.StatusCode);
    }

    [Fact]
    public async Task Task_upsert_is_unique_and_editor_can_update_but_foreign_project_cannot()
    {
        var project = await CreateProjectAsync("task-owner", "task-owner@example.test", "tasks-a");
        var editor = "task-editor";
        await AddMemberAsync(project.id, editor, "editor-task@example.test", "editor");
        var client = _factory.Client(editor, "editor-task@example.test");
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert", TaskRequest("T-1", "first"))).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert", TaskRequest("T-1", "updated"))).StatusCode);
        await using var db = _factory.Db();
        Assert.Single(await db.Tasks.Where(x => x.ProjectId == project.id && x.ExternalId == "T-1").ToListAsync());
        Assert.Equal("updated", (await db.Tasks.SingleAsync(x => x.ProjectId == project.id)).Title);

        var other = await CreateProjectAsync("other-owner", "other-owner@example.test", "tasks-b");
        Assert.Equal(HttpStatusCode.NotFound, (await client.PostAsJsonAsync($"/api/projects/{other.id}/tasks/upsert", TaskRequest("T-2"))).StatusCode);
    }

    [Fact]
    public async Task Task_events_are_ordered_filtered_validated_and_require_writer()
    {
        var project = await CreateProjectAsync("event-owner", "event-owner@example.test", "events");
        var owner = _factory.Client("event-owner", "event-owner@example.test");
        await owner.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert", TaskRequest("T-1"));
        var invalid = await owner.PostAsJsonAsync($"/api/projects/{project.id}/events", new { externalTaskId = "T-1", type = "log", payloadJson = "{" });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, invalid.StatusCode);
        var first = await owner.PostAsJsonAsync($"/api/projects/{project.id}/events", new { externalTaskId = "T-1", type = "log", agent = "codex", payloadJson = "{}" });
        var second = await owner.PostAsJsonAsync($"/api/projects/{project.id}/events", new { externalTaskId = "T-1", type = "done", agent = "codex", payloadJson = "{}" });
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        Assert.Equal(HttpStatusCode.Created, second.StatusCode);
        var firstDto = await first.Content.ReadFromJsonAsync<EventDto>();
        var later = await owner.GetFromJsonAsync<List<EventDto>>($"/api/projects/{project.id}/events?afterId={firstDto!.id}");
        Assert.Single(later!);
        Assert.True(later![0].id > firstDto.id);

        await AddMemberAsync(project.id, "event-viewer", "viewer-event@example.test", "viewer");
        var forbidden = await _factory.Client("event-viewer", "viewer-event@example.test")
            .PostAsJsonAsync($"/api/projects/{project.id}/events", new { externalTaskId = "T-1", type = "log" });
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
    }

    [Fact]
    public async Task Collaboration_workflow_requires_owner_merge_to_develop_and_finalizes_task()
    {
        var project = await CreateProjectAsync("workflow-owner", "owner-workflow@example.test", "workflow");
        await AddMemberAsync(project.id, "workflow-editor", "editor-workflow@example.test", "editor");
        var editorId = await UserIdAsync("workflow-editor");
        var owner = _factory.Client("workflow-owner", "owner-workflow@example.test");
        var editor = _factory.Client("workflow-editor", "editor-workflow@example.test");

        var assigned = await owner.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert",
            new { externalId = "T-9", title = "workflow", ownerAgent = "codex", status = "pending", branch = "codex/t-9", assignedUserId = editorId, workProvider = "codex" });
        Assert.Equal(HttpStatusCode.OK, assigned.StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await editor.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert", TaskRequest("T-9", "working"))).StatusCode);

        var review = new { gitHubNumber = 9, url = "https://github.test/duo/workflow/pull/9", sourceBranch = "codex/t-9", targetBranch = "develop", state = "open", reviewState = "approved", mergedAt = (DateTimeOffset?)null, mergedByLogin = (string?)null };
        Assert.Equal(HttpStatusCode.OK, (await editor.PostAsJsonAsync($"/api/projects/{project.id}/tasks/T-9/pull-request", review)).StatusCode);
        Assert.Equal("in_review", await TaskStatusAsync(project.id, "T-9"));

        var mergedByEditor = new { gitHubNumber = 9, url = review.url, sourceBranch = review.sourceBranch, targetBranch = "develop", state = "merged", reviewState = "approved", mergedAt = DateTimeOffset.UtcNow, mergedByLogin = "editor" };
        Assert.Equal(HttpStatusCode.Forbidden, (await editor.PostAsJsonAsync($"/api/projects/{project.id}/tasks/T-9/pull-request", mergedByEditor)).StatusCode);

        var wrongTarget = new { gitHubNumber = 9, url = review.url, sourceBranch = review.sourceBranch, targetBranch = "main", state = "merged", reviewState = "approved", mergedAt = DateTimeOffset.UtcNow, mergedByLogin = "owner" };
        Assert.Equal(HttpStatusCode.OK, (await owner.PostAsJsonAsync($"/api/projects/{project.id}/tasks/T-9/pull-request", wrongTarget)).StatusCode);
        Assert.Equal("in_review", await TaskStatusAsync(project.id, "T-9"));

        var merged = new { gitHubNumber = 9, url = review.url, sourceBranch = review.sourceBranch, targetBranch = "develop", state = "merged", reviewState = "approved", mergedAt = DateTimeOffset.UtcNow, mergedByLogin = "owner" };
        Assert.Equal(HttpStatusCode.OK, (await owner.PostAsJsonAsync($"/api/projects/{project.id}/tasks/T-9/pull-request", merged)).StatusCode);
        Assert.Equal("finalized", await TaskStatusAsync(project.id, "T-9"));
        await using var db = _factory.Db();
        Assert.Contains(await db.TaskEvents.Where(x => x.ProjectId == project.id).Select(x => x.Type).ToListAsync(), type => type == "pull_request_merged");
    }

    [Fact]
    public async Task Task_rejects_invalid_provider_status_and_non_member_assignee()
    {
        var project = await CreateProjectAsync("validation-owner", "validation@example.test", "validation");
        var client = _factory.Client("validation-owner", "validation@example.test");
        var invalidProvider = await client.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert", new { externalId = "T-1", title = "x", ownerAgent = "x", status = "pending", branch = "x", workProvider = "invalid" });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, invalidProvider.StatusCode);
        var invalidStatus = await client.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert", new { externalId = "T-1", title = "x", ownerAgent = "x", status = "invalid", branch = "x", workProvider = "codex" });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, invalidStatus.StatusCode);
        var nonMember = await client.PostAsJsonAsync($"/api/projects/{project.id}/tasks/upsert", new { externalId = "T-1", title = "x", ownerAgent = "x", status = "pending", branch = "x", assignedUserId = Guid.NewGuid(), workProvider = "codex" });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, nonMember.StatusCode);
    }

    private async Task<ProjectDto> CreateProjectAsync(string sub, string email, string slug)
    {
        var response = await _factory.Client(sub, email).PostAsJsonAsync("/api/projects", new { name = slug, slug, repositoryFullName = $"duo/{slug}", targetBranch = "develop" });
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException($"Crear proyecto devolvió {(int)response.StatusCode}: {await response.Content.ReadAsStringAsync()}");
        return (await response.Content.ReadFromJsonAsync<ProjectDto>())!;
    }

    private async Task AddMemberAsync(Guid projectId, string sub, string email, string role)
    {
        await using var db = _factory.Db();
        var user = new UserProfile { Id = Guid.NewGuid(), AuthSubject = sub, Email = email, CreatedAt = DateTimeOffset.UtcNow, LastSeenAt = DateTimeOffset.UtcNow };
        db.Users.Add(user);
        db.ProjectMembers.Add(new ProjectMember { ProjectId = projectId, UserId = user.Id, Role = role, JoinedAt = DateTimeOffset.UtcNow });
        await db.SaveChangesAsync();
    }

    private async Task<Guid> UserIdAsync(string sub)
    {
        await using var db = _factory.Db();
        return await db.Users.Where(x => x.AuthSubject == sub).Select(x => x.Id).SingleAsync();
    }

    private async Task<string> TaskStatusAsync(Guid projectId, string externalId)
    {
        await using var db = _factory.Db();
        return await db.Tasks.Where(x => x.ProjectId == projectId && x.ExternalId == externalId).Select(x => x.Status).SingleAsync();
    }

    private static object TaskRequest(string externalId, string title = "task") => new { externalId, title, ownerAgent = "codex", status = "in_progress", branch = "codex/task", assignedUserId = (Guid?)null, workProvider = "codex" };
    private static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token))).ToLowerInvariant();
    private sealed record ProjectDto(Guid id, string role);
    private sealed record InvitationDto(Guid id, bool emailSent);
    private sealed record EventDto(long id);
}

public sealed class CloudApiFactory : WebApplicationFactory<Program>
{
    private readonly string _databaseName = $"cloud-tests-{Guid.NewGuid():N}";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ConnectionStrings:DuoCloud", "Host=localhost;Database=test");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<DuoCloudDbContext>>();
            services.RemoveAll<DbContextOptions>();
            services.RemoveAll<IDbContextOptionsConfiguration<DuoCloudDbContext>>();
            services.AddDbContext<DuoCloudDbContext>(options => options.UseInMemoryDatabase(_databaseName));
            services.RemoveAll<IInvitationEmailSender>();
            services.AddSingleton<TestInvitationEmailSender>();
            services.AddSingleton<IInvitationEmailSender>(sp => sp.GetRequiredService<TestInvitationEmailSender>());
            services.AddAuthentication("test").AddScheme<AuthenticationSchemeOptions, TestAuthHandler>("test", _ => { });
        });
    }

    public HttpClient Client(string sub, string email)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-Sub", sub);
        client.DefaultRequestHeaders.Add("X-Test-Email", email);
        client.DefaultRequestHeaders.Add("X-Test-Name", sub);
        return client;
    }

    public DuoCloudDbContext Db() => Services.CreateScope().ServiceProvider.GetRequiredService<DuoCloudDbContext>();
}

public sealed class TestAuthHandler(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, System.Text.Encodings.Web.UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var sub = Request.Headers["X-Test-Sub"].ToString();
        var email = Request.Headers["X-Test-Email"].ToString();
        if (string.IsNullOrWhiteSpace(sub) || string.IsNullOrWhiteSpace(email)) return Task.FromResult(AuthenticateResult.Fail("missing test identity"));
        var identity = new ClaimsIdentity([new Claim("sub", sub), new Claim("email", email), new Claim("name", Request.Headers["X-Test-Name"].ToString())], Scheme.Name);
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name)));
    }
}


public sealed class TestInvitationEmailSender : IInvitationEmailSender
{
    private readonly Dictionary<string, string> _tokens =
        new(StringComparer.OrdinalIgnoreCase);

    public Task SendAsync(
        string email,
        string token,
        string projectName,
        string role,
        DateTimeOffset expiresAt,
        CancellationToken ct)
    {
        _tokens[email] = token;
        return Task.CompletedTask;
    }

    public string TokenFor(string email) =>
        _tokens.TryGetValue(email, out var token) ? token : "";
}
