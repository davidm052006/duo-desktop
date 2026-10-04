using DuoDesktop.Cloud.Domain;
using Microsoft.EntityFrameworkCore;

namespace DuoDesktop.Cloud.Data;

public sealed class DuoCloudDbContext(DbContextOptions<DuoCloudDbContext> options)
    : DbContext(options)
{
    public DbSet<UserProfile> Users => Set<UserProfile>();
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<ProjectMember> ProjectMembers => Set<ProjectMember>();
    public DbSet<ProjectInvitation> ProjectInvitations => Set<ProjectInvitation>();
    public DbSet<CloudTask> Tasks => Set<CloudTask>();
    public DbSet<TaskEvent> TaskEvents => Set<TaskEvent>();
    public DbSet<PullRequest> PullRequests => Set<PullRequest>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<UserProfile>(entity =>
        {
            entity.ToTable("users");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.AuthSubject).IsUnique();
            entity.HasIndex(x => x.Email);
            entity.Property(x => x.AuthSubject).HasMaxLength(256);
            entity.Property(x => x.Email).HasMaxLength(320);
            entity.Property(x => x.DisplayName).HasMaxLength(160);
        });

        model.Entity<Project>(entity =>
        {
            entity.ToTable("projects");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.Slug).IsUnique();
            entity.Property(x => x.Name).HasMaxLength(160);
            entity.Property(x => x.Slug).HasMaxLength(100);
            entity.Property(x => x.RepositoryFullName).HasMaxLength(300);
            entity.Property(x => x.TargetBranch).HasMaxLength(200);
            entity.HasOne(x => x.Owner)
                .WithMany()
                .HasForeignKey(x => x.OwnerUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        model.Entity<ProjectMember>(entity =>
        {
            entity.ToTable("project_members");
            entity.HasKey(x => new { x.ProjectId, x.UserId });
            entity.Property(x => x.Role).HasMaxLength(16);
            entity.HasOne(x => x.Project)
                .WithMany(x => x.Members)
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.User)
                .WithMany(x => x.Memberships)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        model.Entity<ProjectInvitation>(entity =>
        {
            entity.ToTable("project_invitations");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasIndex(x => new { x.ProjectId, x.EmailNormalized });
            entity.Property(x => x.EmailNormalized).HasMaxLength(320);
            entity.Property(x => x.Role).HasMaxLength(16);
            entity.Property(x => x.TokenHash).HasMaxLength(64);
            entity.HasOne(x => x.Project)
                .WithMany()
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.InvitedByUser)
                .WithMany()
                .HasForeignKey(x => x.InvitedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        model.Entity<CloudTask>(entity =>
        {
            entity.ToTable("tasks");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.ProjectId, x.ExternalId }).IsUnique();
            entity.Property(x => x.ExternalId).HasMaxLength(64);
            entity.Property(x => x.Title).HasMaxLength(500);
            entity.Property(x => x.OwnerAgent).HasMaxLength(64);
            entity.Property(x => x.Status).HasMaxLength(64);
            entity.Property(x => x.Branch).HasMaxLength(300);
            entity.Property(x => x.WorkProvider).HasMaxLength(32);
            entity.HasOne(x => x.Project)
                .WithMany(x => x.Tasks)
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.CreatedByUser)
                .WithMany()
                .HasForeignKey(x => x.CreatedByUserId)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.AssignedUser)
                .WithMany()
                .HasForeignKey(x => x.AssignedUserId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        model.Entity<PullRequest>(entity =>
        {
            entity.ToTable("pull_requests");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.TaskId).IsUnique();
            entity.HasIndex(x => new { x.ProjectId, x.GitHubNumber }).IsUnique();
            entity.Property(x => x.Url).HasMaxLength(1000);
            entity.Property(x => x.SourceBranch).HasMaxLength(300);
            entity.Property(x => x.TargetBranch).HasMaxLength(300);
            entity.Property(x => x.State).HasMaxLength(32);
            entity.Property(x => x.ReviewState).HasMaxLength(32);
            entity.Property(x => x.MergedByLogin).HasMaxLength(160);
            entity.HasOne(x => x.Project)
                .WithMany()
                .HasForeignKey(x => x.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.Task)
                .WithOne(x => x.PullRequest)
                .HasForeignKey<PullRequest>(x => x.TaskId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        model.Entity<TaskEvent>(entity =>
        {
            entity.ToTable("task_events");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.ProjectId, x.Id });
            entity.Property(x => x.Type).HasMaxLength(80);
            entity.Property(x => x.Agent).HasMaxLength(64);
            entity.Property(x => x.PayloadJson).HasColumnType("jsonb");
            entity.HasOne(x => x.Task)
                .WithMany(x => x.Events)
                .HasForeignKey(x => x.TaskId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.ActorUser)
                .WithMany()
                .HasForeignKey(x => x.ActorUserId)
                .OnDelete(DeleteBehavior.SetNull);
        });
    }
}
