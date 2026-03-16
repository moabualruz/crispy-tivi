using System.Collections.Generic;

using Crispy.Application.Player.Models;
using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;
using NSubstitute.ExceptionExtensions;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class SeriesViewModelTests
{
    private readonly ISeriesRepository _seriesRepo;
    private readonly ISourceRepository _sourceRepo;
    private readonly INavigationService _navigationService;
    private readonly SeriesViewModel _sut;

    public SeriesViewModelTests()
    {
        _seriesRepo = Substitute.For<ISeriesRepository>();
        _sourceRepo = Substitute.For<ISourceRepository>();
        _navigationService = Substitute.For<INavigationService>();

        _seriesRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(new List<Series>());
        _sourceRepo.GetAllAsync()
            .Returns(new List<Source>());

        _sut = new SeriesViewModel(_seriesRepo, _sourceRepo, _navigationService);
    }

    private static Source MakeSource(int id, string name, bool enabled = true) =>
        new() { Id = id, Name = name, Url = "http://test", IsEnabled = enabled };

    private static Series MakeSeries(int id, int sourceId) =>
        new() { Id = id, Title = $"Series{id}", SourceId = sourceId };

    // ── Constructor / defaults ─────────────────────────────────────────────────

    [Fact]
    public void Title_IsSeries()
    {
        _sut.Title.Should().Be("Series");
    }

    [Fact]
    public void Series_IsEmpty_Initially()
    {
        _sut.Series.Should().BeEmpty("no series are loaded before the async operation completes");
    }

    [Fact]
    public void Series_IsNotNull()
    {
        _sut.Series.Should().NotBeNull();
    }

    [Fact]
    public void IsLoading_IsFalse_Initially()
    {
        _sut.IsLoading.Should().BeFalse();
    }

    [Fact]
    public void SourceFilters_IsNotNull()
    {
        _sut.SourceFilters.Should().NotBeNull();
    }

    // ── LoadAsync builds filters ───────────────────────────────────────────────

    [Fact]
    public async Task SourceFilters_ContainsAllSourcesItem_WithNullSourceId()
    {
        await Task.Yield();
        await Task.Delay(50);

        _sut.SourceFilters.Should().ContainSingle(
            f => f.SourceId == null && f.Name == "All Sources",
            "the 'All Sources' sentinel filter must always be the first entry");
    }

    [Fact]
    public async Task LoadAsync_BuildsSourceFilters_OnePerEnabledSource()
    {
        var seriesRepo = Substitute.For<ISeriesRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>(
            [
                MakeSource(1, "IPTV1"),
                MakeSource(2, "IPTV2"),
            ]));
        seriesRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Series>>([]));

        var sut = new SeriesViewModel(seriesRepo, sourceRepo, Substitute.For<INavigationService>());
        await Task.Delay(100);

        // "All Sources" + 2 enabled sources
        sut.SourceFilters.Should().HaveCount(3);
    }

    [Fact]
    public async Task LoadAsync_PopulatesSeries_WhenSourceHasSeries()
    {
        var seriesRepo = Substitute.For<ISeriesRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([MakeSource(1, "IPTV1")]));
        seriesRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Series>>([MakeSeries(1, 1), MakeSeries(2, 1)]));

        var sut = new SeriesViewModel(seriesRepo, sourceRepo, Substitute.For<INavigationService>());
        await Task.Delay(100);

        sut.Series.Should().HaveCount(2);
    }

    [Fact]
    public async Task LoadAsync_SetsIsLoadingFalse_AfterCompletion()
    {
        var seriesRepo = Substitute.For<ISeriesRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        seriesRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Series>>([]));

        var sut = new SeriesViewModel(seriesRepo, sourceRepo, Substitute.For<INavigationService>());
        await Task.Delay(100);

        sut.IsLoading.Should().BeFalse();
    }

    [Fact]
    public async Task LoadAsync_SetsIsLoadingFalse_WhenRepositoryThrows()
    {
        var seriesRepo = Substitute.For<ISeriesRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().ThrowsAsync(new InvalidOperationException("DB error"));

        var sut = new SeriesViewModel(seriesRepo, sourceRepo, Substitute.For<INavigationService>());
        await Task.Delay(100);

        sut.IsLoading.Should().BeFalse();
    }

    [Fact]
    public async Task LoadAsync_AllSourcesFilter_AggregatesSeriesFromAllSources()
    {
        var seriesRepo = Substitute.For<ISeriesRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>(
            [
                MakeSource(1, "IPTV1"),
                MakeSource(2, "IPTV2"),
            ]));
        seriesRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Series>>([MakeSeries(1, 1)]));
        seriesRepo.GetBySourceAsync(2, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Series>>([MakeSeries(2, 2)]));

        var sut = new SeriesViewModel(seriesRepo, sourceRepo, Substitute.For<INavigationService>());
        await Task.Delay(100);

        // Default is "All Sources" so both series should be present
        sut.Series.Should().HaveCount(2);
    }

    // ── Filter selection ───────────────────────────────────────────────────────

    [Fact]
    public async Task SelectedSourceFilter_WhenChanged_LoadsSeriesForThatSource()
    {
        var seriesRepo = Substitute.For<ISeriesRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>(
            [
                MakeSource(1, "IPTV1"),
                MakeSource(2, "IPTV2"),
            ]));
        seriesRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Series>>([MakeSeries(10, 1)]));
        seriesRepo.GetBySourceAsync(2, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Series>>([MakeSeries(20, 2), MakeSeries(21, 2)]));

        var sut = new SeriesViewModel(seriesRepo, sourceRepo, Substitute.For<INavigationService>());
        await Task.Delay(100);

        var source2Filter = sut.SourceFilters.First(f => f.SourceId == 2);
        sut.SelectedSourceFilter = source2Filter;
        await Task.Delay(100);

        sut.Series.Should().HaveCount(2);
    }

    // ── Explicit LoadCommand ───────────────────────────────────────────────────

    [Fact]
    public async Task LoadCommand_CanBeExecutedExplicitly()
    {
        await Task.Delay(50);
        var act = async () => await _sut.LoadCommand.ExecuteAsync(default(CancellationToken));
        await act.Should().NotThrowAsync();
    }

    // ── SelectSeriesAsync — episode loading ────────────────────────────────────

    [Fact]
    public async Task SelectSeriesAsync_LoadsEpisodes_ForSelectedSeries()
    {
        var series = MakeSeries(1, 1);
        var episodes = new List<Episode>
        {
            new() { Id = 10, Title = "Pilot",     SourceId = 1, SeriesId = 1, SeasonNumber = 1, EpisodeNumber = 1 },
            new() { Id = 11, Title = "Second Ep",  SourceId = 1, SeriesId = 1, SeasonNumber = 1, EpisodeNumber = 2 },
        };
        series.Episodes = episodes;

        _seriesRepo.GetByIdAsync(1, includeEpisodes: true, Arg.Any<CancellationToken>())
            .Returns(series);

        await _sut.SelectSeriesAsync(series);

        _sut.SelectedSeries.Should().Be(series);
        _sut.Episodes.Should().HaveCount(2);
        _sut.IsEpisodesLoading.Should().BeFalse();
    }

    // ── SelectEpisodeCommand — navigation ──────────────────────────────────────

    [Fact]
    public void SelectEpisodeCommand_NavigatesToPlayer_WhenStreamUrlExists()
    {
        var series = MakeSeries(5, 1);
        _sut.SelectedSeries = series;

        var episode = new Episode
        {
            Id = 99,
            Title = "The One",
            SourceId = 1,
            SeriesId = 5,
            SeasonNumber = 2,
            EpisodeNumber = 3,
            StreamUrl = "http://stream/ep99.m3u8",
        };

        _sut.SelectEpisodeCommand.Execute(episode);

        _navigationService.Received(1).NavigateTo<PlayerViewModel>(
            Arg.Is<PlaybackRequest>(r =>
                r.Url == "http://stream/ep99.m3u8" &&
                r.ContentType == PlaybackContentType.Vod));
    }

    [Fact]
    public void SelectEpisodeCommand_DoesNotNavigate_WhenStreamUrlIsEmpty()
    {
        var episode = new Episode
        {
            Id = 100,
            Title = "No Stream",
            SourceId = 1,
            SeriesId = 1,
            SeasonNumber = 1,
            EpisodeNumber = 1,
            StreamUrl = null,
        };

        _sut.SelectEpisodeCommand.Execute(episode);

        _navigationService.DidNotReceive().NavigateTo<PlayerViewModel>(Arg.Any<object>());
    }
}
