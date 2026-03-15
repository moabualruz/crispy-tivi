using Avalonia.Headless.XUnit;

using Crispy.Domain.Interfaces;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

[Trait("Category", "UI")]
public class SeriesViewTests
{
    [AvaloniaFact]
    public void SeriesView_RendersWithoutException()
    {
        var seriesRepo = Substitute.For<ISeriesRepository>();
        seriesRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns([]);

        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns([]);

        var vm = new SeriesViewModel(seriesRepo, sourceRepo);
        var window = HeadlessTestHelpers.CreateWindow<SeriesView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }
}
