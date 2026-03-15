using Microsoft.EntityFrameworkCore.Migrations;

namespace Crispy.Infrastructure.Data.Migrations.AppDb;

/// <inheritdoc />
public partial class PlayerDataSchema : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // -------------------------------------------------------------------------
        // PlayerWatchHistory — SHA-256-keyed player watch history (PLR-47/48)
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "PlayerWatchHistory",
            columns: table => new
            {
                Id = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false),
                MediaType = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                Name = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                StreamUrl = table.Column<string>(type: "TEXT", maxLength: 2000, nullable: false),
                PosterUrl = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: true),
                SeriesPosterUrl = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: true),
                PositionMs = table.Column<long>(type: "INTEGER", nullable: false),
                DurationMs = table.Column<long>(type: "INTEGER", nullable: false),
                LastWatched = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                SeriesId = table.Column<string>(type: "TEXT", maxLength: 200, nullable: true),
                SeasonNumber = table.Column<int>(type: "INTEGER", nullable: true),
                EpisodeNumber = table.Column<int>(type: "INTEGER", nullable: true),
                DeviceId = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                DeviceName = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                ProfileId = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                SourceId = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PlayerWatchHistory", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_PlayerWatchHistory_ProfileId_LastWatched",
            table: "PlayerWatchHistory",
            columns: new[] { "ProfileId", "LastWatched" });

        migrationBuilder.CreateIndex(
            name: "IX_PlayerWatchHistory_SeriesId_ProfileId",
            table: "PlayerWatchHistory",
            columns: new[] { "SeriesId", "ProfileId" });

        // -------------------------------------------------------------------------
        // PlayerBookmarks — named playback bookmarks (PLR-41)
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "PlayerBookmarks",
            columns: table => new
            {
                Id = table.Column<string>(type: "TEXT", maxLength: 36, nullable: false),
                ContentId = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                ContentType = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                PositionMs = table.Column<long>(type: "INTEGER", nullable: false),
                Label = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                ProfileId = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PlayerBookmarks", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_PlayerBookmarks_ContentId_ContentType_ProfileId",
            table: "PlayerBookmarks",
            columns: new[] { "ContentId", "ContentType", "ProfileId" });

        // -------------------------------------------------------------------------
        // PlayerSavedLayouts — multiview layout presets (PLR-42)
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "PlayerSavedLayouts",
            columns: table => new
            {
                Id = table.Column<string>(type: "TEXT", maxLength: 36, nullable: false),
                Name = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                Layout = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                StreamsJson = table.Column<string>(type: "TEXT", nullable: false),
                CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                ProfileId = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PlayerSavedLayouts", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_PlayerSavedLayouts_ProfileId_CreatedAt",
            table: "PlayerSavedLayouts",
            columns: new[] { "ProfileId", "CreatedAt" });

        // -------------------------------------------------------------------------
        // PlayerReminders — programme notification reminders (PLR-43)
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "PlayerReminders",
            columns: table => new
            {
                Id = table.Column<string>(type: "TEXT", maxLength: 36, nullable: false),
                ProgramName = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                ChannelName = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                StartTime = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                NotifyAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                Fired = table.Column<bool>(type: "INTEGER", nullable: false),
                ProfileId = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PlayerReminders", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_PlayerReminders_ProfileId_NotifyAt_Fired",
            table: "PlayerReminders",
            columns: new[] { "ProfileId", "NotifyAt", "Fired" });

        // -------------------------------------------------------------------------
        // PlayerStreamHealth — stream health telemetry (PLR-40)
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "PlayerStreamHealth",
            columns: table => new
            {
                UrlHash = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false),
                StallCount = table.Column<int>(type: "INTEGER", nullable: false),
                BufferSum = table.Column<long>(type: "INTEGER", nullable: false),
                BufferSamples = table.Column<int>(type: "INTEGER", nullable: false),
                TtffMs = table.Column<long>(type: "INTEGER", nullable: false),
                LastSeen = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PlayerStreamHealth", x => x.UrlHash);
            });
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "PlayerWatchHistory");
        migrationBuilder.DropTable(name: "PlayerBookmarks");
        migrationBuilder.DropTable(name: "PlayerSavedLayouts");
        migrationBuilder.DropTable(name: "PlayerReminders");
        migrationBuilder.DropTable(name: "PlayerStreamHealth");
    }
}
