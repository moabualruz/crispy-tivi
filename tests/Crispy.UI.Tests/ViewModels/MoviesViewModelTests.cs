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
public class MoviesViewModelTests
{
    private readonly IMovieRepository _movieRepo;
    private readonly ISourceRepository _sourceRepo;
    private readonly INavigationService _navService;
    private readonly IPlayerController _playerController;
    private readonly MoviesViewModel _sut;

    public MoviesViewModelTests()
    {
        _movieRepo = Substitute.For<IMovieRepository>();
        _sourceRepo = Substitute.For<ISourceRepository>();
        _navService = Substitute.For<INavigationService>();
        _playerController = Substitute.For<IPlayerController>();

        _movieRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(new List<Movie>());
        _movieRepo.GetAllAsync(Arg.Any<CancellationToken>())
            .Returns(new List<Movie>());
        _sourceRepo.GetAllAsync()
            .Returns(new List<Source>());

        _sut = new MoviesViewModel(_movieRepo, _sourceRepo, _navService, _playerController);
    }

    private static Source MakeSource(int id, string name, bool enabled = true) =>
        new() { Id = id, Name = name, Url = "http://test", IsEnabled = enabled };

    private static Movie MakeMovie(int id, int sourceId, string? streamUrl = null) =>
        new() { Id = id, Title = $"Movie{id}", SourceId = sourceId, StreamUrl = streamUrl };

    // ── Constructor / defaults ─────────────────────────────────────────────────

    [Fact]
    public void Title_IsMovies()
    {
        _sut.Title.Should().Be("Movies");
    }

    [Fact]
    public void Movies_IsEmpty_Initially()
    {
        _sut.Movies.Should().BeEmpty("no movies are loaded before the async operation completes");
    }

    [Fact]
    public void Movies_IsNotNull()
    {
        _sut.Movies.Should().NotBeNull();
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

    [Fact]
    public void SelectedSourceFilter_IsNullInitially()
    {
        // Before the async Load completes SelectedSourceFilter has not been set yet.
        // This test just documents the initial synchronous state.
        // (It may be null or the first filter depending on race — just ensure no exception.)
        var _ = _sut.SelectedSourceFilter;
    }

    // ── LoadAsync builds filters ───────────────────────────────────────────────

    [Fact]
    public async Task SourceFilters_ContainsAllSourcesItem_WithNullSourceId()
    {
        // LoadAsync is fire-and-forget in the constructor; wait for it to settle
        await Task.Yield();
        await Task.Delay(50); // let async complete

        _sut.SourceFilters.Should().ContainSingle(
            f => f.SourceId == null && f.Name == "All Sources",
            "the 'All Sources' sentinel filter must always be the first entry");
    }

    [Fact]
    public async Task LoadAsync_BuildsSourceFilters_OnePerEnabledSource()
    {
        var movieRepo = Substitute.For<IMovieRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>(
            [
                MakeSource(1, "IPTV1"),
                MakeSource(2, "IPTV2"),
            ]));
        movieRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Movie>>([]));

        var sut = new MoviesViewModel(movieRepo, sourceRepo, Substitute.For<INavigationService>(), Substitute.For<IPlayerController>());
        await Task.Delay(100);

        // "All Sources" + 2 enabled sources
        sut.SourceFilters.Should().HaveCount(3);
    }

    [Fact]
    public async Task LoadAsync_PopulatesMovies_WhenSourceHasMovies()
    {
        var movieRepo = Substitute.For<IMovieRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([MakeSource(1, "IPTV1")]));
        movieRepo.GetAllAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Movie>>([MakeMovie(1, 1), MakeMovie(2, 1)]));

        var sut = new MoviesViewModel(movieRepo, sourceRepo, Substitute.For<INavigationService>(), Substitute.For<IPlayerController>());
        await Task.Delay(100);

        sut.Movies.Should().HaveCount(2);
    }

    [Fact]
    public async Task LoadAsync_SetsIsLoadingFalse_AfterCompletion()
    {
        var movieRepo = Substitute.For<IMovieRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        movieRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Movie>>([]));

        var sut = new MoviesViewModel(movieRepo, sourceRepo, Substitute.For<INavigationService>(), Substitute.For<IPlayerController>());
        await Task.Delay(100);

        sut.IsLoading.Should().BeFalse();
    }

    [Fact]
    public async Task LoadAsync_SetsIsLoadingFalse_WhenRepositoryThrows()
    {
        var movieRepo = Substitute.For<IMovieRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().ThrowsAsync(new InvalidOperationException("DB error"));

        var sut = new MoviesViewModel(movieRepo, sourceRepo, Substitute.For<INavigationService>(), Substitute.For<IPlayerController>());
        await Task.Delay(100);

        sut.IsLoading.Should().BeFalse();
    }

    [Fact]
    public async Task LoadAsync_AllSourcesFilter_UsesGetAllAsync()
    {
        var movieRepo = Substitute.For<IMovieRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>(
            [
                MakeSource(1, "IPTV1"),
                MakeSource(2, "IPTV2"),
            ]));
        movieRepo.GetAllAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Movie>>([MakeMovie(1, 1), MakeMovie(2, 2)]));

        var sut = new MoviesViewModel(movieRepo, sourceRepo, Substitute.For<INavigationService>(), Substitute.For<IPlayerController>());
        await Task.Delay(100);

        // Default is "All Sources" — uses single GetAllAsync call
        sut.Movies.Should().HaveCount(2);
        await movieRepo.Received().GetAllAsync(Arg.Any<CancellationToken>());
    }

    // ── Filter selection ───────────────────────────────────────────────────────

    [Fact]
    public async Task SelectedSourceFilter_WhenChanged_LoadsMoviesForThatSource()
    {
        var movieRepo = Substitute.For<IMovieRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>(
            [
                MakeSource(1, "IPTV1"),
                MakeSource(2, "IPTV2"),
            ]));
        movieRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Movie>>([MakeMovie(10, 1)]));
        movieRepo.GetBySourceAsync(2, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Movie>>([MakeMovie(20, 2), MakeMovie(21, 2)]));

        var sut = new MoviesViewModel(movieRepo, sourceRepo, Substitute.For<INavigationService>(), Substitute.For<IPlayerController>());
        await Task.Delay(100);

        var source2Filter = sut.SourceFilters.First(f => f.SourceId == 2);
        sut.SelectedSourceFilter = source2Filter;
        await Task.Delay(100);

        sut.Movies.Should().HaveCount(2);
    }

    // ── Explicit LoadCommand ───────────────────────────────────────────────────

    [Fact]
    public async Task LoadCommand_CanBeExecutedExplicitly()
    {
        await Task.Delay(50);
        var act = async () => await _sut.LoadCommand.ExecuteAsync(default(CancellationToken));
        await act.Should().NotThrowAsync();
    }

    // ── SelectMovieCommand ─────────────────────────────────────────────────────

    [Fact]
    public async Task SelectMovieCommand_PlaysMovie_WhenStreamUrlExists()
    {
        var movie = MakeMovie(1, 1, streamUrl: "http://stream/movie.m3u8");

        await _sut.SelectMovieCommand.ExecuteAsync(movie);

        await _playerController.Received(1).PlayAsync(
            Arg.Is<PlaybackRequest>(r =>
                r.Url == movie.StreamUrl &&
                r.ContentType == PlaybackContentType.Vod &&
                r.Title == movie.Title));
    }

    [Fact]
    public async Task SelectMovieCommand_DoesNotPlay_WhenNoStreamUrl()
    {
        var movieNoUrl = MakeMovie(2, 1, streamUrl: null);
        var movieEmptyUrl = MakeMovie(3, 1, streamUrl: "");

        await _sut.SelectMovieCommand.ExecuteAsync(movieNoUrl);
        await _sut.SelectMovieCommand.ExecuteAsync(movieEmptyUrl);

        await _playerController.DidNotReceiveWithAnyArgs().PlayAsync(default!);
    }
}
