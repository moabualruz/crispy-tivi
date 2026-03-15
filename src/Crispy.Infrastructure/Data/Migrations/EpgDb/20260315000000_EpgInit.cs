using System;

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Crispy.Infrastructure.Data.Migrations.EpgDb;

/// <inheritdoc />
public partial class EpgInit : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "Programmes",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                ChannelId = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                StartUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                StopUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                Title = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                SubTitle = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                Description = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: true),
                Credits = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: true),
                EpisodeNumXmltvNs = table.Column<string>(type: "TEXT", maxLength: 100, nullable: true),
                EpisodeNumOnScreen = table.Column<string>(type: "TEXT", maxLength: 100, nullable: true),
                Rating = table.Column<string>(type: "TEXT", maxLength: 50, nullable: true),
                StarRating = table.Column<string>(type: "TEXT", maxLength: 50, nullable: true),
                IconUrl = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                PreviouslyShown = table.Column<bool>(type: "INTEGER", nullable: false),
                MultiLangTitles = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: true),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Programmes", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_Programmes_ChannelId_StartUtc_StopUtc",
            table: "Programmes",
            columns: new[] { "ChannelId", "StartUtc", "StopUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_Programmes_StartUtc",
            table: "Programmes",
            column: "StartUtc");

        migrationBuilder.CreateTable(
            name: "Reminders",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                ProfileId = table.Column<int>(type: "INTEGER", nullable: false),
                EpgProgrammeId = table.Column<int>(type: "INTEGER", nullable: false),
                ReminderMinutesBefore = table.Column<int>(type: "INTEGER", nullable: false),
                IsFired = table.Column<bool>(type: "INTEGER", nullable: false),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Reminders", x => x.Id);
                table.ForeignKey(
                    name: "FK_Reminders_Programmes_EpgProgrammeId",
                    column: x => x.EpgProgrammeId,
                    principalTable: "Programmes",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_Reminders_ProfileId_EpgProgrammeId",
            table: "Reminders",
            columns: new[] { "ProfileId", "EpgProgrammeId" },
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_Reminders_IsFired",
            table: "Reminders",
            column: "IsFired");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "Reminders");
        migrationBuilder.DropTable(name: "Programmes");
    }
}
