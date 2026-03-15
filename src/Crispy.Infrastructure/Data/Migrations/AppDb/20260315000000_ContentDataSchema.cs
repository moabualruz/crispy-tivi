using System;

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Crispy.Infrastructure.Data.Migrations.AppDb;

/// <inheritdoc />
public partial class ContentDataSchema : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // -------------------------------------------------------------------------
        // Add encrypted credential columns to Sources (backward-compatible)
        // -------------------------------------------------------------------------
        migrationBuilder.AddColumn<string>(
            name: "EncryptedUsername",
            table: "Sources",
            type: "TEXT",
            maxLength: 1024,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "EncryptedPassword",
            table: "Sources",
            type: "TEXT",
            maxLength: 1024,
            nullable: true);

        // -------------------------------------------------------------------------
        // DeduplicationGroups
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "DeduplicationGroups",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                CanonicalTitle = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                CanonicalTvgId = table.Column<string>(type: "TEXT", maxLength: 200, nullable: true),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_DeduplicationGroups", x => x.Id);
            });

        // -------------------------------------------------------------------------
        // ChannelGroups
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "ChannelGroups",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                Name = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                SourceId = table.Column<int>(type: "INTEGER", nullable: true),
                SortOrder = table.Column<int>(type: "INTEGER", nullable: false),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_ChannelGroups", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_ChannelGroups_SourceId",
            table: "ChannelGroups",
            column: "SourceId");

        migrationBuilder.CreateIndex(
            name: "IX_ChannelGroups_SortOrder",
            table: "ChannelGroups",
            column: "SortOrder");

        // -------------------------------------------------------------------------
        // Channels
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "Channels",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                Title = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                TvgId = table.Column<string>(type: "TEXT", maxLength: 200, nullable: true),
                TvgName = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                TvgLogo = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                TvgChno = table.Column<int>(type: "INTEGER", nullable: true),
                GroupName = table.Column<string>(type: "TEXT", maxLength: 200, nullable: true),
                SourceId = table.Column<int>(type: "INTEGER", nullable: false),
                IsRadio = table.Column<bool>(type: "INTEGER", nullable: false),
                CatchupType = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                CatchupSource = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                CatchupDays = table.Column<int>(type: "INTEGER", nullable: false),
                MissedSyncCount = table.Column<int>(type: "INTEGER", nullable: false),
                UnifiedNumber = table.Column<int>(type: "INTEGER", nullable: true),
                UserAssignedNumber = table.Column<int>(type: "INTEGER", nullable: true),
                CustomSortOrder = table.Column<int>(type: "INTEGER", nullable: true),
                IsFavorite = table.Column<bool>(type: "INTEGER", nullable: false),
                IsHidden = table.Column<bool>(type: "INTEGER", nullable: false),
                DeduplicationGroupId = table.Column<int>(type: "INTEGER", nullable: true),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Channels", x => x.Id);
                table.ForeignKey(
                    name: "FK_Channels_DeduplicationGroups_DeduplicationGroupId",
                    column: x => x.DeduplicationGroupId,
                    principalTable: "DeduplicationGroups",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.SetNull);
                table.ForeignKey(
                    name: "FK_Channels_Sources_SourceId",
                    column: x => x.SourceId,
                    principalTable: "Sources",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_Channels_TvgId_SourceId",
            table: "Channels",
            columns: new[] { "TvgId", "SourceId" },
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_Channels_SourceId",
            table: "Channels",
            column: "SourceId");

        migrationBuilder.CreateIndex(
            name: "IX_Channels_DeduplicationGroupId",
            table: "Channels",
            column: "DeduplicationGroupId");

        // -------------------------------------------------------------------------
        // ChannelGroupMemberships
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "ChannelGroupMemberships",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                ChannelId = table.Column<int>(type: "INTEGER", nullable: false),
                ChannelGroupId = table.Column<int>(type: "INTEGER", nullable: false),
                SortOrder = table.Column<int>(type: "INTEGER", nullable: false),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_ChannelGroupMemberships", x => x.Id);
                table.ForeignKey(
                    name: "FK_ChannelGroupMemberships_Channels_ChannelId",
                    column: x => x.ChannelId,
                    principalTable: "Channels",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_ChannelGroupMemberships_ChannelGroups_ChannelGroupId",
                    column: x => x.ChannelGroupId,
                    principalTable: "ChannelGroups",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_ChannelGroupMemberships_ChannelId_ChannelGroupId",
            table: "ChannelGroupMemberships",
            columns: new[] { "ChannelId", "ChannelGroupId" },
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_ChannelGroupMemberships_ChannelGroupId",
            table: "ChannelGroupMemberships",
            column: "ChannelGroupId");

        // -------------------------------------------------------------------------
        // StreamEndpoints
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "StreamEndpoints",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                ChannelId = table.Column<int>(type: "INTEGER", nullable: false),
                SourceId = table.Column<int>(type: "INTEGER", nullable: false),
                Url = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: false),
                Format = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                HttpHeaders = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: true),
                Priority = table.Column<int>(type: "INTEGER", nullable: false),
                LastSuccessAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: true),
                FailureCount = table.Column<int>(type: "INTEGER", nullable: false),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_StreamEndpoints", x => x.Id);
                table.ForeignKey(
                    name: "FK_StreamEndpoints_Channels_ChannelId",
                    column: x => x.ChannelId,
                    principalTable: "Channels",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_StreamEndpoints_Sources_SourceId",
                    column: x => x.SourceId,
                    principalTable: "Sources",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_StreamEndpoints_ChannelId_SourceId",
            table: "StreamEndpoints",
            columns: new[] { "ChannelId", "SourceId" });

        migrationBuilder.CreateIndex(
            name: "IX_StreamEndpoints_Priority",
            table: "StreamEndpoints",
            column: "Priority");

        // -------------------------------------------------------------------------
        // Movies
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "Movies",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                Title = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                Thumbnail = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                SourceId = table.Column<int>(type: "INTEGER", nullable: false),
                StreamUrl = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                TmdbId = table.Column<int>(type: "INTEGER", nullable: true),
                Overview = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: true),
                Year = table.Column<int>(type: "INTEGER", nullable: true),
                RuntimeMinutes = table.Column<int>(type: "INTEGER", nullable: true),
                Genres = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                Rating = table.Column<double>(type: "REAL", nullable: true),
                BackdropUrl = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Movies", x => x.Id);
                table.ForeignKey(
                    name: "FK_Movies_Sources_SourceId",
                    column: x => x.SourceId,
                    principalTable: "Sources",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_Movies_TmdbId",
            table: "Movies",
            column: "TmdbId");

        migrationBuilder.CreateIndex(
            name: "IX_Movies_SourceId",
            table: "Movies",
            column: "SourceId");

        // -------------------------------------------------------------------------
        // SeriesItems
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "SeriesItems",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                Title = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                Thumbnail = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                SourceId = table.Column<int>(type: "INTEGER", nullable: false),
                TmdbId = table.Column<int>(type: "INTEGER", nullable: true),
                Overview = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: true),
                FirstAiredYear = table.Column<int>(type: "INTEGER", nullable: true),
                Genres = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                Rating = table.Column<double>(type: "REAL", nullable: true),
                BackdropUrl = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SeriesItems", x => x.Id);
                table.ForeignKey(
                    name: "FK_SeriesItems_Sources_SourceId",
                    column: x => x.SourceId,
                    principalTable: "Sources",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_SeriesItems_TmdbId",
            table: "SeriesItems",
            column: "TmdbId");

        migrationBuilder.CreateIndex(
            name: "IX_SeriesItems_SourceId",
            table: "SeriesItems",
            column: "SourceId");

        // -------------------------------------------------------------------------
        // Episodes
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "Episodes",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                Title = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                Thumbnail = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                SourceId = table.Column<int>(type: "INTEGER", nullable: false),
                SeriesId = table.Column<int>(type: "INTEGER", nullable: false),
                SeasonNumber = table.Column<int>(type: "INTEGER", nullable: false),
                EpisodeNumber = table.Column<int>(type: "INTEGER", nullable: false),
                StreamUrl = table.Column<string>(type: "TEXT", maxLength: 2048, nullable: true),
                RuntimeMinutes = table.Column<int>(type: "INTEGER", nullable: true),
                Overview = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: true),
                AiredAt = table.Column<DateTime>(type: "TEXT", nullable: true),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Episodes", x => x.Id);
                table.ForeignKey(
                    name: "FK_Episodes_SeriesItems_SeriesId",
                    column: x => x.SeriesId,
                    principalTable: "SeriesItems",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_Episodes_Sources_SourceId",
                    column: x => x.SourceId,
                    principalTable: "Sources",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_Episodes_SeriesId_SeasonNumber_EpisodeNumber",
            table: "Episodes",
            columns: new[] { "SeriesId", "SeasonNumber", "EpisodeNumber" });

        migrationBuilder.CreateIndex(
            name: "IX_Episodes_SourceId",
            table: "Episodes",
            column: "SourceId");

        // -------------------------------------------------------------------------
        // WatchHistory
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "WatchHistory",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                ProfileId = table.Column<int>(type: "INTEGER", nullable: false),
                ContentType = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                ContentId = table.Column<int>(type: "INTEGER", nullable: false),
                PositionMs = table.Column<long>(type: "INTEGER", nullable: false),
                DurationMs = table.Column<long>(type: "INTEGER", nullable: false),
                CompletionPct = table.Column<double>(type: "REAL", nullable: false),
                WatchedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                SourceId = table.Column<int>(type: "INTEGER", nullable: false),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_WatchHistory", x => x.Id);
                table.ForeignKey(
                    name: "FK_WatchHistory_Profiles_ProfileId",
                    column: x => x.ProfileId,
                    principalTable: "Profiles",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_WatchHistory_ProfileId_ContentType_ContentId",
            table: "WatchHistory",
            columns: new[] { "ProfileId", "ContentType", "ContentId" });

        migrationBuilder.CreateIndex(
            name: "IX_WatchHistory_WatchedAt",
            table: "WatchHistory",
            column: "WatchedAt");

        // -------------------------------------------------------------------------
        // SyncHistory
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "SyncHistory",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                SourceId = table.Column<int>(type: "INTEGER", nullable: false),
                StartedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                CompletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
                Status = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                ChannelCount = table.Column<int>(type: "INTEGER", nullable: false),
                VodCount = table.Column<int>(type: "INTEGER", nullable: false),
                EpgCount = table.Column<int>(type: "INTEGER", nullable: false),
                ErrorMessage = table.Column<string>(type: "TEXT", maxLength: 2000, nullable: true),
                DurationMs = table.Column<long>(type: "INTEGER", nullable: false),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SyncHistory", x => x.Id);
                table.ForeignKey(
                    name: "FK_SyncHistory_Sources_SourceId",
                    column: x => x.SourceId,
                    principalTable: "Sources",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_SyncHistory_SourceId_StartedAt",
            table: "SyncHistory",
            columns: new[] { "SourceId", "StartedAt" });

        // -------------------------------------------------------------------------
        // Downloads
        // -------------------------------------------------------------------------
        migrationBuilder.CreateTable(
            name: "Downloads",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                ContentType = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                ContentId = table.Column<int>(type: "INTEGER", nullable: false),
                Status = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                Progress = table.Column<double>(type: "REAL", nullable: false),
                FilePath = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: true),
                Quality = table.Column<string>(type: "TEXT", maxLength: 50, nullable: true),
                SizeBytes = table.Column<long>(type: "INTEGER", nullable: false),
                CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                DeletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Downloads", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_Downloads_ContentType_ContentId",
            table: "Downloads",
            columns: new[] { "ContentType", "ContentId" });

        migrationBuilder.CreateIndex(
            name: "IX_Downloads_Status",
            table: "Downloads",
            column: "Status");

        // -------------------------------------------------------------------------
        // FTS5 ContentSearch virtual table
        // -------------------------------------------------------------------------
        migrationBuilder.Sql(@"
CREATE VIRTUAL TABLE IF NOT EXISTS ContentSearch USING fts5(
    content_id UNINDEXED,
    content_type UNINDEXED,
    source_id UNINDEXED,
    title,
    description,
    group_name,
    tokenize = 'unicode61 remove_diacritics 1'
);");

        // -------------------------------------------------------------------------
        // FTS5 triggers on Channels to keep ContentSearch in sync
        // -------------------------------------------------------------------------
        migrationBuilder.Sql(@"
CREATE TRIGGER IF NOT EXISTS channel_ai
AFTER INSERT ON Channels
BEGIN
    INSERT INTO ContentSearch(content_id, content_type, source_id, title, description, group_name)
    VALUES (NEW.Id, 'Channel', NEW.SourceId, NEW.Title, NULL, NEW.GroupName);
END;");

        migrationBuilder.Sql(@"
CREATE TRIGGER IF NOT EXISTS channel_ad
AFTER DELETE ON Channels
BEGIN
    INSERT INTO ContentSearch(ContentSearch, content_id, content_type, source_id, title, description, group_name)
    VALUES ('delete', OLD.Id, 'Channel', OLD.SourceId, OLD.Title, NULL, OLD.GroupName);
END;");

        migrationBuilder.Sql(@"
CREATE TRIGGER IF NOT EXISTS channel_au
AFTER UPDATE ON Channels
BEGIN
    INSERT INTO ContentSearch(ContentSearch, content_id, content_type, source_id, title, description, group_name)
    VALUES ('delete', OLD.Id, 'Channel', OLD.SourceId, OLD.Title, NULL, OLD.GroupName);
    INSERT INTO ContentSearch(content_id, content_type, source_id, title, description, group_name)
    VALUES (NEW.Id, 'Channel', NEW.SourceId, NEW.Title, NULL, NEW.GroupName);
END;");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Drop FTS5 triggers first
        migrationBuilder.Sql("DROP TRIGGER IF EXISTS channel_au;");
        migrationBuilder.Sql("DROP TRIGGER IF EXISTS channel_ad;");
        migrationBuilder.Sql("DROP TRIGGER IF EXISTS channel_ai;");
        migrationBuilder.Sql("DROP TABLE IF EXISTS ContentSearch;");

        migrationBuilder.DropTable(name: "Downloads");
        migrationBuilder.DropTable(name: "SyncHistory");
        migrationBuilder.DropTable(name: "WatchHistory");
        migrationBuilder.DropTable(name: "Episodes");
        migrationBuilder.DropTable(name: "SeriesItems");
        migrationBuilder.DropTable(name: "Movies");
        migrationBuilder.DropTable(name: "StreamEndpoints");
        migrationBuilder.DropTable(name: "ChannelGroupMemberships");
        migrationBuilder.DropTable(name: "Channels");
        migrationBuilder.DropTable(name: "ChannelGroups");
        migrationBuilder.DropTable(name: "DeduplicationGroups");

        migrationBuilder.DropColumn(name: "EncryptedUsername", table: "Sources");
        migrationBuilder.DropColumn(name: "EncryptedPassword", table: "Sources");
    }
}
