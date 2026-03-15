using System.Collections.Generic;

using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class SeriesViewModelTests
{
    private readonly ISeriesRepository _seriesRepo;
    private readonly ISourceRepository _sourceRepo;
    private readonly SeriesViewModel _sut;

    public SeriesViewModelTests()
    {
        _seriesRepo = Substitute.For<ISeriesRepository>();
        _sourceRepo = Substitute.For<ISourceRepository>();

        _seriesRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(new List<Series>());
        _sourceRepo.GetAllAsync()
            .Returns(new List<Source>());

        _sut = new SeriesViewModel(_seriesRepo, _sourceRepo);
    }

    [Fact]
    public void Title_IsSeries()
    {
        _sut.Title.Should().Be("Series");
    }

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
    public void Series_IsEmpty_Initially()
    {
        _sut.Series.Should().BeEmpty("no series are loaded before the async operation completes");
    }

    [Fact]
    public void IsLoading_IsFalse_Initially()
    {
        _sut.IsLoading.Should().BeFalse();
    }
}
