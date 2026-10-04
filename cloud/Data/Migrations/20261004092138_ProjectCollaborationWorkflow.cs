using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DuoDesktop.Cloud.Data.Migrations
{
    /// <inheritdoc />
    public partial class ProjectCollaborationWorkflow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "AssignedUserId",
                table: "tasks",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WorkProvider",
                table: "tasks",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "RepositoryFullName",
                table: "projects",
                type: "character varying(300)",
                maxLength: 300,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "TargetBranch",
                table: "projects",
                type: "character varying(200)",
                maxLength: 200,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "pull_requests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ProjectId = table.Column<Guid>(type: "uuid", nullable: false),
                    TaskId = table.Column<Guid>(type: "uuid", nullable: false),
                    GitHubNumber = table.Column<int>(type: "integer", nullable: false),
                    Url = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    SourceBranch = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    TargetBranch = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    State = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ReviewState = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    MergedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    MergedByLogin = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_pull_requests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_pull_requests_projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "projects",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_pull_requests_tasks_TaskId",
                        column: x => x.TaskId,
                        principalTable: "tasks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_tasks_AssignedUserId",
                table: "tasks",
                column: "AssignedUserId");

            migrationBuilder.CreateIndex(
                name: "IX_pull_requests_ProjectId_GitHubNumber",
                table: "pull_requests",
                columns: new[] { "ProjectId", "GitHubNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_pull_requests_TaskId",
                table: "pull_requests",
                column: "TaskId",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_tasks_users_AssignedUserId",
                table: "tasks",
                column: "AssignedUserId",
                principalTable: "users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_tasks_users_AssignedUserId",
                table: "tasks");

            migrationBuilder.DropTable(
                name: "pull_requests");

            migrationBuilder.DropIndex(
                name: "IX_tasks_AssignedUserId",
                table: "tasks");

            migrationBuilder.DropColumn(
                name: "AssignedUserId",
                table: "tasks");

            migrationBuilder.DropColumn(
                name: "WorkProvider",
                table: "tasks");

            migrationBuilder.DropColumn(
                name: "RepositoryFullName",
                table: "projects");

            migrationBuilder.DropColumn(
                name: "TargetBranch",
                table: "projects");
        }
    }
}
