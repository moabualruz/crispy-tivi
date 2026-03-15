using Avalonia.Headless.XUnit;

using Crispy.Application.Search;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

[Trait("Category", "UI")]
public class SearchViewTests
{
    [AvaloniaFact]
    public void SearchView_RendersWithoutException()
    {
        var searchService = Substitute.For<ISearchService>();

        var vm = new SearchViewModel(searchService);
        var window = HeadlessTestHelpers.CreateWindow<SearchView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }
}
