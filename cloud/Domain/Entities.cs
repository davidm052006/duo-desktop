namespace DuoDesktop.Cloud.Domain;

public static class ProjectRoles
{
    public const string Owner = "owner";
    public const string Editor = "editor";
    public const string Viewer = "viewer";

    public static bool IsValid(string value) =>
        value is Owner or Editor or Viewer;

    public static bool CanWrite(string value) =>
        value is Owner or Editor;
}

public static class TaskStatuses
{
    public const string Pending = "pending";
    public const string InProgress = "in_progress";
    public const string Waiting = "waiting";
    public const string InReview = "in_review";
    public const string Finalized = "finalized";
    public const string Cancelled = "cancelled";

    public static bool IsValid(string value) =>
        value is Pending or InProgress or Waiting or InReview or Finalized or Cancelled;
}

public static class WorkProviders
{
    public const string ChatGpt = "chatgpt";
    public const string Grok = "grok";
    public const string Codex = "codex";
    public const string Claude = "claude";
    public const string Gemini = "gemini";

    public static bool IsValid(string value) =>
        value is ChatGpt or Grok or Codex or Claude or Gemini;
}

public sealed class UserProfile
{
    public Guid Id { get; set; }
    public required string AuthSubject { get; set; }
    public required string Email { get; set; }
    public string? DisplayName { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset LastSeenAt { get; set; }

    public List<ProjectMember> Memberships { get; set; } = [];
}

public sealed class Project
{
    public Guid Id { get; set; }
    public required string Name { get; set; }
    public required string Slug { get; set; }
    public Guid OwnerUserId { get; set; }
    public UserProfile? Owner { get; set; }
    public required string RepositoryFullName { get; set; }
    public string TargetBranch { get; set; } = "develop";
    public DateTimeOffset CreatedAt { get; set; }

    public List<ProjectMember> Members { get; set; } = [];
    public List<CloudTask> Tasks { get; set; } = [];
}

public sealed class ProjectMember
{
    public Guid ProjectId { get; set; }
    public Project? Project { get; set; }
    public Guid UserId { get; set; }
    public UserProfile? User { get; set; }
    public required string Role { get; set; }
    public DateTimeOffset JoinedAt { get; set; }
}

public sealed class ProjectInvitation
{
    public Guid Id { get; set; }
    public Guid ProjectId { get; set; }
    public Project? Project { get; set; }
    public required string EmailNormalized { get; set; }
    public required string Role { get; set; }
    public required string TokenHash { get; set; }
    public Guid InvitedByUserId { get; set; }
    public UserProfile? InvitedByUser { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? AcceptedAt { get; set; }
}

public sealed class CloudTask
{
    public Guid Id { get; set; }
    public Guid ProjectId { get; set; }
    public Project? Project { get; set; }
    public required string ExternalId { get; set; }
    public required string Title { get; set; }
    public required string OwnerAgent { get; set; }
    public required string Status { get; set; }
    public required string Branch { get; set; }
    public Guid? AssignedUserId { get; set; }
    public UserProfile? AssignedUser { get; set; }
    public required string WorkProvider { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public UserProfile? CreatedByUser { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    public List<TaskEvent> Events { get; set; } = [];
    public PullRequest? PullRequest { get; set; }
}

public sealed class PullRequest
{
    public Guid Id { get; set; }
    public Guid ProjectId { get; set; }
    public Project? Project { get; set; }
    public Guid TaskId { get; set; }
    public CloudTask? Task { get; set; }
    public int GitHubNumber { get; set; }
    public required string Url { get; set; }
    public required string SourceBranch { get; set; }
    public required string TargetBranch { get; set; }
    public required string State { get; set; }
    public string? ReviewState { get; set; }
    public DateTimeOffset? MergedAt { get; set; }
    public string? MergedByLogin { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class TaskEvent
{
    public long Id { get; set; }
    public Guid ProjectId { get; set; }
    public Guid TaskId { get; set; }
    public CloudTask? Task { get; set; }
    public required string Type { get; set; }
    public string? Agent { get; set; }
    public string? PayloadJson { get; set; }
    public Guid? ActorUserId { get; set; }
    public UserProfile? ActorUser { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
