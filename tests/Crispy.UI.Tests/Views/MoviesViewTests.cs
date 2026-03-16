using Avalonia.Headless.XUnit;

using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

[Trait("Category", "UI")]
public class MoviesViewTests
{
    [AvaloniaFact]
    public void MoviesView_RendersWithoutException()
    {
        var movieRepo = Substitute.For<IMovieRepository>();
        movieRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns([]);

        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns([]);

        var vm = new MoviesViewModel(movieRepo, sourceRepo, Substitute.For<INavigationService>(), Substitute.For<IPlayerController>());
        var window = HeadlessTestHelpers.CreateWindow<MoviesView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }
}
