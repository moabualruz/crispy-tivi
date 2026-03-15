using Crispy.Domain.Entities;
using FluentAssertions;
using Xunit;

namespace Crispy.Domain.Tests.Entities;

[Trait("Category", "Unit")]
public class ContentEntityTests
{
    // --- Movie ---

    [Fact]
    public void Movie_Title_IsSet()
    {
        var movie = new Movie { Title = "Inception", SourceId = 1 };

        movie.Title.Should().Be("Inception");
    }

    [Fact]
    public void Movie_SourceId_IsSet()
    {
        var movie = new Movie { Title = "Inception", SourceId = 42 };

        movie.SourceId.Should().Be(42);
    }

    [Fact]
    public void Movie_OptionalProperties_DefaultToNull()
    {
        var movie = new Movie { Title = "Inception", SourceId = 1 };

        movie.Thumbnail.Should().BeNull();
        movie.StreamUrl.Should().BeNull();
        movie.TmdbId.Should().BeNull();
        movie.Overview.Should().BeNull();
        movie.Year.Should().BeNull();
        movie.RuntimeMinutes.Should().BeNull();
        movie.Genres.Should().BeNull();
        movie.Rating.Should().BeNull();
        movie.BackdropUrl.Should().BeNull();
    }

    // --- Series ---

    [Fact]
    public void Series_Title_IsSet()
    {
        var series = new Series { Title = "Breaking Bad", SourceId = 1 };

        series.Title.Should().Be("Breaking Bad");
    }

    [Fact]
    public void Series_Episodes_DefaultsToEmpty()
    {
        var series = new Series { Title = "Breaking Bad", SourceId = 1 };

        series.Episodes.Should().NotBeNull();
        series.Episodes.Should().BeEmpty();
    }

    [Fact]
    public void Series_OptionalProperties_DefaultToNull()
    {
        var series = new Series { Title = "Breaking Bad", SourceId = 1 };

        series.TmdbId.Should().BeNull();
        series.Overview.Should().BeNull();
        series.FirstAiredYear.Should().BeNull();
        series.Genres.Should().BeNull();
        series.Rating.Should().BeNull();
        series.BackdropUrl.Should().BeNull();
    }

    // --- Episode ---

    [Fact]
    public void Episode_Title_IsSet()
    {
        var episode = new Episode { Title = "Pilot", SourceId = 1, SeriesId = 10 };

        episode.Title.Should().Be("Pilot");
    }

    [Fact]
    public void Episode_SeriesId_LinksToParentSeries()
    {
        var episode = new Episode { Title = "Pilot", SourceId = 1, SeriesId = 99 };

        episode.SeriesId.Should().Be(99);
    }

    [Fact]
    public void Episode_SeasonAndEpisodeNumbers_DefaultToZero()
    {
        var episode = new Episode { Title = "Pilot", SourceId = 1, SeriesId = 10 };

        episode.SeasonNumber.Should().Be(0);
        episode.EpisodeNumber.Should().Be(0);
    }

    [Fact]
    public void Episode_SeasonAndEpisodeNumbers_CanBeSet()
    {
        var episode = new Episode
        {
            Title = "Pilot",
            SourceId = 1,
            SeriesId = 10,
            SeasonNumber = 2,
            EpisodeNumber = 5,
        };

        episode.SeasonNumber.Should().Be(2);
        episode.EpisodeNumber.Should().Be(5);
    }

    // --- EpgProgramme ---

    [Fact]
    public void EpgProgramme_Title_IsSet()
    {
        var prog = new EpgProgramme
        {
            ChannelId = "ch1",
            Title = "Evening News",
            StartUtc = DateTime.UtcNow,
            StopUtc = DateTime.UtcNow.AddHours(1),
        };

        prog.Title.Should().Be("Evening News");
    }

    [Fact]
    public void EpgProgramme_Duration_EqualsDifferenceBetweenStopAndStart()
    {
        var start = new DateTime(2026, 1, 1, 20, 0, 0, DateTimeKind.Utc);
        var stop = new DateTime(2026, 1, 1, 21, 30, 0, DateTimeKind.Utc);

        var prog = new EpgProgramme
        {
            ChannelId = "ch1",
            Title = "Movie Night",
            StartUtc = start,
            StopUtc = stop,
        };

        var duration = prog.StopUtc - prog.StartUtc;
        duration.Should().Be(TimeSpan.FromMinutes(90));
    }

    [Fact]
    public void EpgProgramme_PreviouslyShown_DefaultsToFalse()
    {
        var prog = new EpgProgramme
        {
            ChannelId = "ch1",
            Title = "Evening News",
            StartUtc = DateTime.UtcNow,
            StopUtc = DateTime.UtcNow.AddHours(1),
        };

        prog.PreviouslyShown.Should().BeFalse();
    }

    [Fact]
    public void EpgProgramme_ChannelId_IsSet()
    {
        var prog = new EpgProgramme
        {
            ChannelId = "bbc-one",
            Title = "News at Ten",
            StartUtc = DateTime.UtcNow,
            StopUtc = DateTime.UtcNow.AddMinutes(30),
        };

        prog.ChannelId.Should().Be("bbc-one");
    }

    // --- Channel ---

    [Fact]
    public void Channel_Title_IsSet()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 1 };

        channel.Title.Should().Be("BBC One");
    }

    [Fact]
    public void Channel_SourceId_IsSet()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 42 };

        channel.SourceId.Should().Be(42);
    }

    [Fact]
    public void Channel_TvgLogo_BacksThumbnail()
    {
        var channel = new Channel
        {
            Title = "BBC One",
            SourceId = 1,
            TvgLogo = "https://example.com/logo.png",
        };

        channel.Thumbnail.Should().Be("https://example.com/logo.png");
        channel.TvgLogo.Should().Be("https://example.com/logo.png");
    }

    [Fact]
    public void Channel_GroupName_CanBeSet()
    {
        var channel = new Channel { Title = "Sky Sports", SourceId = 1, GroupName = "Sports" };

        channel.GroupName.Should().Be("Sports");
    }

    [Fact]
    public void Channel_EpgChannelId_CanBeSet()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 1, TvgId = "bbc-one.uk" };

        channel.TvgId.Should().Be("bbc-one.uk");
    }

    [Fact]
    public void Channel_IsEnabled_IsFalseByDefault_ViaIsHidden()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 1 };

        // Channel has no IsEnabled; hidden defaults false (visible by default)
        channel.IsHidden.Should().BeFalse();
    }

    [Fact]
    public void Channel_IsRadio_DefaultsToFalse()
    {
        var channel = new Channel { Title = "BBC Radio 4", SourceId = 1 };

        channel.IsRadio.Should().BeFalse();
    }

    [Fact]
    public void Channel_IsFavorite_DefaultsToFalse()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 1 };

        channel.IsFavorite.Should().BeFalse();
    }

    [Fact]
    public void Channel_StreamEndpoints_DefaultsToEmpty()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 1 };

        channel.StreamEndpoints.Should().NotBeNull();
        channel.StreamEndpoints.Should().BeEmpty();
    }

    [Fact]
    public void Channel_GroupMemberships_DefaultsToEmpty()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 1 };

        channel.GroupMemberships.Should().NotBeNull();
        channel.GroupMemberships.Should().BeEmpty();
    }

    [Fact]
    public void Channel_OptionalFields_DefaultToNull()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 1 };

        channel.TvgId.Should().BeNull();
        channel.TvgName.Should().BeNull();
        channel.TvgLogo.Should().BeNull();
        channel.TvgChno.Should().BeNull();
        channel.GroupName.Should().BeNull();
        channel.CatchupSource.Should().BeNull();
        channel.UnifiedNumber.Should().BeNull();
        channel.UserAssignedNumber.Should().BeNull();
        channel.CustomSortOrder.Should().BeNull();
        channel.DeduplicationGroupId.Should().BeNull();
        channel.DeduplicationGroup.Should().BeNull();
        channel.Source.Should().BeNull();
    }

    [Fact]
    public void Channel_MissedSyncCount_DefaultsToZero()
    {
        var channel = new Channel { Title = "BBC One", SourceId = 1 };

        channel.MissedSyncCount.Should().Be(0);
    }
}

// ─── EpgProgramme (boost) ─────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class EpgProgrammeEntityBoostTests
{
    private static EpgProgramme MakeProgram(string channelId = "ch1") => new()
    {
        ChannelId = channelId,
        Title = "T",
        StartUtc = new DateTime(2026, 1, 1, 20, 0, 0, DateTimeKind.Utc),
        StopUtc = new DateTime(2026, 1, 1, 21, 0, 0, DateTimeKind.Utc),
    };

    [Fact]
    public void EpgProgramme_OptionalFields_DefaultToNull()
    {
        var p = MakeProgram();

        p.SubTitle.Should().BeNull();
        p.Description.Should().BeNull();
        p.Credits.Should().BeNull();
        p.EpisodeNumXmltvNs.Should().BeNull();
        p.EpisodeNumOnScreen.Should().BeNull();
        p.Rating.Should().BeNull();
        p.StarRating.Should().BeNull();
        p.IconUrl.Should().BeNull();
        p.MultiLangTitles.Should().BeNull();
    }

    [Fact]
    public void EpgProgramme_SubTitle_CanBeSet()
    {
        var p = MakeProgram();
        p.SubTitle = "Part Two";

        p.SubTitle.Should().Be("Part Two");
    }

    [Fact]
    public void EpgProgramme_Description_CanBeSet()
    {
        var p = MakeProgram();
        p.Description = "A gripping documentary.";

        p.Description.Should().Be("A gripping documentary.");
    }

    [Fact]
    public void EpgProgramme_EpisodeNumOnScreen_CanBeSet()
    {
        var p = MakeProgram();
        p.EpisodeNumOnScreen = "S02E04";

        p.EpisodeNumOnScreen.Should().Be("S02E04");
    }

    [Fact]
    public void EpgProgramme_Rating_CanBeSet()
    {
        var p = MakeProgram();
        p.Rating = "TV-14";

        p.Rating.Should().Be("TV-14");
    }

    [Fact]
    public void EpgProgramme_StarRating_CanBeSet()
    {
        var p = MakeProgram();
        p.StarRating = "4/5";

        p.StarRating.Should().Be("4/5");
    }

    [Fact]
    public void EpgProgramme_IconUrl_CanBeSet()
    {
        var p = MakeProgram();
        p.IconUrl = "https://example.com/icon.png";

        p.IconUrl.Should().Be("https://example.com/icon.png");
    }

    [Fact]
    public void EpgProgramme_PreviouslyShown_CanBeSetToTrue()
    {
        var p = MakeProgram();
        p.PreviouslyShown = true;

        p.PreviouslyShown.Should().BeTrue();
    }
}

// ─── Episode (boost) ──────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class EpisodeEntityBoostTests
{
    private static Episode MakeEpisode() => new()
    {
        Title = "Pilot",
        SourceId = 1,
        SeriesId = 10,
    };

    [Fact]
    public void Episode_OptionalFields_DefaultToNull()
    {
        var ep = MakeEpisode();

        ep.StreamUrl.Should().BeNull();
        ep.RuntimeMinutes.Should().BeNull();
        ep.Overview.Should().BeNull();
        ep.AiredAt.Should().BeNull();
        ep.Thumbnail.Should().BeNull();
        ep.Source.Should().BeNull();
        ep.Series.Should().BeNull();
    }

    [Fact]
    public void Episode_StreamUrl_CanBeSet()
    {
        var ep = MakeEpisode();
        ep.StreamUrl = "http://stream.example.com/ep1";

        ep.StreamUrl.Should().Be("http://stream.example.com/ep1");
    }

    [Fact]
    public void Episode_RuntimeMinutes_CanBeSet()
    {
        var ep = MakeEpisode();
        ep.RuntimeMinutes = 45;

        ep.RuntimeMinutes.Should().Be(45);
    }

    [Fact]
    public void Episode_Overview_CanBeSet()
    {
        var ep = MakeEpisode();
        ep.Overview = "A chemistry teacher turns to crime.";

        ep.Overview.Should().Be("A chemistry teacher turns to crime.");
    }

    [Fact]
    public void Episode_AiredAt_CanBeSet()
    {
        var ep = MakeEpisode();
        var date = new DateTime(2008, 1, 20, 0, 0, 0, DateTimeKind.Utc);
        ep.AiredAt = date;

        ep.AiredAt.Should().Be(date);
    }
}

// ─── Movie (boost) ────────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class MovieEntityBoostTests
{
    private static Movie MakeMovie() => new() { Title = "Inception", SourceId = 1 };

    [Fact]
    public void Movie_SourceId_IsRequired()
    {
        var m = MakeMovie();

        m.SourceId.Should().Be(1);
    }

    [Fact]
    public void Movie_Genres_IsNullByDefault()
    {
        var m = MakeMovie();

        m.Genres.Should().BeNull();
    }

    [Fact]
    public void Movie_Genres_CanBeSetAsCommaSeparated()
    {
        var m = MakeMovie();
        m.Genres = "Sci-Fi,Thriller";

        m.Genres.Should().Be("Sci-Fi,Thriller");
    }

    [Fact]
    public void Movie_TmdbId_CanBeSet()
    {
        var m = MakeMovie();
        m.TmdbId = 27205;

        m.TmdbId.Should().Be(27205);
    }

    [Fact]
    public void Movie_Year_CanBeSet()
    {
        var m = MakeMovie();
        m.Year = 2010;

        m.Year.Should().Be(2010);
    }

    [Fact]
    public void Movie_RuntimeMinutes_CanBeSet()
    {
        var m = MakeMovie();
        m.RuntimeMinutes = 148;

        m.RuntimeMinutes.Should().Be(148);
    }

    [Fact]
    public void Movie_Rating_CanBeSet()
    {
        var m = MakeMovie();
        m.Rating = 8.8;

        m.Rating.Should().Be(8.8);
    }

    [Fact]
    public void Movie_BackdropUrl_CanBeSet()
    {
        var m = MakeMovie();
        m.BackdropUrl = "https://example.com/backdrop.jpg";

        m.BackdropUrl.Should().Be("https://example.com/backdrop.jpg");
    }

    [Fact]
    public void Movie_Source_DefaultsToNull()
    {
        var m = MakeMovie();

        m.Source.Should().BeNull();
    }
}

// ─── Series (boost) ───────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class SeriesEntityBoostTests
{
    private static Series MakeSeries() => new() { Title = "Breaking Bad", SourceId = 1 };

    [Fact]
    public void Series_SourceId_IsRequired()
    {
        var s = MakeSeries();

        s.SourceId.Should().Be(1);
    }

    [Fact]
    public void Series_Episodes_CanAddEpisode()
    {
        var s = MakeSeries();
        s.Episodes.Add(new Episode { SeriesId = s.Id, SeasonNumber = 1, EpisodeNumber = 1, Title = "Pilot", SourceId = 1 });

        s.Episodes.Should().HaveCount(1);
    }

    [Fact]
    public void Series_Genres_IsNullByDefault()
    {
        var s = MakeSeries();

        s.Genres.Should().BeNull();
    }

    [Fact]
    public void Series_Genres_CanBeSetAsCommaSeparated()
    {
        var s = MakeSeries();
        s.Genres = "Drama,Crime";

        s.Genres.Should().Be("Drama,Crime");
    }

    [Fact]
    public void Series_TmdbId_CanBeSet()
    {
        var s = MakeSeries();
        s.TmdbId = 1396;

        s.TmdbId.Should().Be(1396);
    }

    [Fact]
    public void Series_FirstAiredYear_CanBeSet()
    {
        var s = MakeSeries();
        s.FirstAiredYear = 2008;

        s.FirstAiredYear.Should().Be(2008);
    }

    [Fact]
    public void Series_Rating_CanBeSet()
    {
        var s = MakeSeries();
        s.Rating = 9.5;

        s.Rating.Should().Be(9.5);
    }

    [Fact]
    public void Series_BackdropUrl_CanBeSet()
    {
        var s = MakeSeries();
        s.BackdropUrl = "https://example.com/backdrop.jpg";

        s.BackdropUrl.Should().Be("https://example.com/backdrop.jpg");
    }

    [Fact]
    public void Series_Thumbnail_CanBeSet()
    {
        var s = MakeSeries();
        s.Thumbnail = "https://example.com/poster.jpg";

        s.Thumbnail.Should().Be("https://example.com/poster.jpg");
    }

    [Fact]
    public void Series_Source_DefaultsToNull()
    {
        var s = MakeSeries();

        s.Source.Should().BeNull();
    }
}
