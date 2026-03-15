using System.Collections.Generic;

using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class MoviesViewModelTests
{
    private readonly IMovieRepository _movieRepo;
    private readonly ISourceRepository _sourceRepo;
    private readonly MoviesViewModel _sut;

    public MoviesViewModelTests()
    {
        _movieRepo = Substitute.For<IMovieRepository>();
        _sourceRepo = Substitute.For<ISourceRepository>();

        _movieRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(new List<Movie>());
        _sourceRepo.GetAllAsync()
            .Returns(new List<Source>());

        _sut = new MoviesViewModel(_movieRepo, _sourceRepo);
    }

    [Fact]
    public void Title_IsMovies()
    {
        _sut.Title.Should().Be("Movies");
    }

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
    public void Movies_IsEmpty_Initially()
    {
        _sut.Movies.Should().BeEmpty("no movies are loaded before the async operation completes");
    }

    [Fact]
    public void IsLoading_IsFalse_Initially()
    {
        // IsLoading starts false; the ctor fires LoadAsync but it may have flipped it
        // We verify the initial state (before async completes) or final state (after)
        // Either false initially or false after completing with empty source list
        _sut.IsLoading.Should().BeFalse();
    }
}
