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
