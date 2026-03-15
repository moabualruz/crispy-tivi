using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class SourcesViewModelTests
{
    private static (SourcesViewModel vm, ISourceRepository repo, INavigationService nav) Build()
    {
        var repo = Substitute.For<ISourceRepository>();
        var nav = Substitute.For<INavigationService>();
        repo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        return (new SourcesViewModel(repo, nav), repo, nav);
    }

    [Fact]
    public void Title_IsSources()
    {
        var (vm, _, _) = Build();
        vm.Title.Should().Be("Sources");
    }

    [Fact]
    public void Sources_EmptyInitially_WhenRepositoryReturnsEmpty()
    {
        var (vm, _, _) = Build();
        vm.Sources.Should().BeEmpty();
    }

    [Fact]
    public void NavigateToAddSourceCommand_InvokesNavigationService()
    {
        var (vm, _, nav) = Build();
        vm.NavigateToAddSourceCommand.Execute(null);
        nav.Received(1).NavigateTo<AddSourceViewModel>();
    }

    [Fact]
    public async Task DeleteCommand_RemovesFromCollectionAndCallsRepo()
    {
        var (vm, repo, _) = Build();
        var source = new Source { Name = "Test", Url = "http://test.m3u" };
        vm.Sources.Add(source);
        repo.DeleteAsync(source.Id).Returns(Task.CompletedTask);

        await vm.DeleteCommand.ExecuteAsync(source);

        vm.Sources.Should().NotContain(source);
        await repo.Received(1).DeleteAsync(source.Id);
    }

    [Fact]
    public void HasNoSources_IsTrue_WhenSourcesIsEmpty()
    {
        var (vm, _, _) = Build();
        vm.HasNoSources.Should().BeTrue();
    }

    [Fact]
    public void HasNoSources_IsFalse_WhenSourcesHasItems()
    {
        var (vm, _, _) = Build();
        vm.Sources.Add(new Source { Name = "TV", Url = "http://tv.m3u" });
        vm.HasNoSources.Should().BeFalse();
    }
}
