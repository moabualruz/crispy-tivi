using CommunityToolkit.Mvvm.Messaging;

using Crispy.Application.Security;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class AddSourceViewModelTests
{
    private static AddSourceViewModel Build()
    {
        var repo = Substitute.For<ISourceRepository>();
        var enc = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var nav = Substitute.For<INavigationService>();
        return new AddSourceViewModel(repo, enc, messenger, nav);
    }

    [Fact]
    public void Title_IsAddSource()
    {
        Build().Title.Should().Be("Add Source");
    }

    [Fact]
    public void SelectedSourceType_DefaultsToM3U()
    {
        Build().SelectedSourceType.Should().Be(SourceType.M3U);
    }

    [Fact]
    public void CanSave_IsFalse_WhenNameIsEmpty()
    {
        var vm = Build();
        vm.Name = string.Empty;
        vm.Url = "http://example.com/playlist.m3u";
        vm.SaveCommand.CanExecute(null).Should().BeFalse();
    }

    [Fact]
    public void CanSave_IsFalse_WhenUrlIsEmpty()
    {
        var vm = Build();
        vm.Name = "My Source";
        vm.Url = string.Empty;
        vm.SaveCommand.CanExecute(null).Should().BeFalse();
    }

    [Fact]
    public void CanSave_IsTrue_WhenNameAndUrlAreProvided()
    {
        var vm = Build();
        vm.Name = "My Source";
        vm.Url = "http://example.com/playlist.m3u";
        vm.SaveCommand.CanExecute(null).Should().BeTrue();
    }

    [Fact]
    public void AreCredentialsVisible_IsFalse_ForM3U()
    {
        var vm = Build();
        vm.SelectedSourceType = SourceType.M3U;
        vm.AreCredentialsVisible.Should().BeFalse();
    }

    [Fact]
    public void AreCredentialsVisible_IsTrue_ForXtreamCodes()
    {
        var vm = Build();
        vm.SelectedSourceType = SourceType.XtreamCodes;
        vm.AreCredentialsVisible.Should().BeTrue();
    }

    [Fact]
    public void AreCredentialsVisible_IsTrue_ForStalkerPortal()
    {
        var vm = Build();
        vm.SelectedSourceType = SourceType.StalkerPortal;
        vm.AreCredentialsVisible.Should().BeTrue();
    }

    [Fact]
    public void AreCredentialsVisible_IsTrue_ForJellyfin()
    {
        var vm = Build();
        vm.SelectedSourceType = SourceType.Jellyfin;
        vm.AreCredentialsVisible.Should().BeTrue();
    }

    [Fact]
    public void AvailableSourceTypes_ContainsAllFourTypes()
    {
        var vm = Build();
        vm.AvailableSourceTypes.Should().BeEquivalentTo(
            [SourceType.M3U, SourceType.XtreamCodes, SourceType.StalkerPortal, SourceType.Jellyfin]);
    }

    [Fact]
    public void ErrorMessage_IsNullInitially()
    {
        Build().ErrorMessage.Should().BeNull();
    }
}
