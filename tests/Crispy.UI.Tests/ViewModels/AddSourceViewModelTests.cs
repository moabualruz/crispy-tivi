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

    // ─── SaveAsync (lines 164-169) ────────────────────────────────────────────

    [Fact]
    public async Task SaveCommand_CallsCreateAsync_WithCorrectSource()
    {
        var repo = Substitute.For<ISourceRepository>();
        var enc = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var nav = Substitute.For<INavigationService>();

        var created = new Crispy.Domain.Entities.Source
        {
            Name = "Test Source",
            Url = "http://example.com/playlist.m3u",
            SourceType = SourceType.M3U,
            IsEnabled = true,
        };
        repo.CreateAsync(Arg.Any<Crispy.Domain.Entities.Source>()).Returns(created);

        var vm = new AddSourceViewModel(repo, enc, messenger, nav);
        vm.Name = "Test Source";
        vm.Url = "http://example.com/playlist.m3u";

        await vm.SaveCommand.ExecuteAsync(null);

        await repo.Received(1).CreateAsync(Arg.Is<Crispy.Domain.Entities.Source>(s =>
            s.Name == "Test Source" &&
            s.Url == "http://example.com/playlist.m3u" &&
            s.SourceType == SourceType.M3U &&
            s.IsEnabled == true));
    }

    [Fact]
    public async Task SaveCommand_NavigatesBack_WhenCanGoBack()
    {
        var repo = Substitute.For<ISourceRepository>();
        var enc = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var nav = Substitute.For<INavigationService>();

        var created = new Crispy.Domain.Entities.Source
        {
            Name = "IPTV",
            Url = "http://iptv.example/list.m3u",
            SourceType = SourceType.M3U,
            IsEnabled = true,
        };
        repo.CreateAsync(Arg.Any<Crispy.Domain.Entities.Source>()).Returns(created);
        nav.CanGoBack.Returns(true);

        var vm = new AddSourceViewModel(repo, enc, messenger, nav);
        vm.Name = "IPTV";
        vm.Url = "http://iptv.example/list.m3u";

        await vm.SaveCommand.ExecuteAsync(null);

        nav.Received(1).GoBack();
    }

    [Fact]
    public async Task SaveCommand_DoesNotCallGoBack_WhenCannotGoBack()
    {
        var repo = Substitute.For<ISourceRepository>();
        var enc = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var nav = Substitute.For<INavigationService>();

        var created = new Crispy.Domain.Entities.Source
        {
            Name = "IPTV2",
            Url = "http://iptv2.example/list.m3u",
            SourceType = SourceType.M3U,
            IsEnabled = true,
        };
        repo.CreateAsync(Arg.Any<Crispy.Domain.Entities.Source>()).Returns(created);
        nav.CanGoBack.Returns(false);

        var vm = new AddSourceViewModel(repo, enc, messenger, nav);
        vm.Name = "IPTV2";
        vm.Url = "http://iptv2.example/list.m3u";

        await vm.SaveCommand.ExecuteAsync(null);

        nav.DidNotReceive().GoBack();
    }

    [Fact]
    public async Task SaveCommand_SetsErrorMessage_WhenCreateAsyncThrows()
    {
        var repo = Substitute.For<ISourceRepository>();
        var enc = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var nav = Substitute.For<INavigationService>();

        repo.CreateAsync(Arg.Any<Crispy.Domain.Entities.Source>())
            .Returns<Crispy.Domain.Entities.Source>(_ => throw new InvalidOperationException("DB error"));

        var vm = new AddSourceViewModel(repo, enc, messenger, nav);
        vm.Name = "Bad Source";
        vm.Url = "http://bad.example/list.m3u";

        await vm.SaveCommand.ExecuteAsync(null);

        vm.ErrorMessage.Should().Contain("DB error");
    }

    // ─── CancelCommand (lines 164-169) ────────────────────────────────────────

    [Fact]
    public void CancelCommand_CallsGoBack_WhenCanGoBack()
    {
        var repo = Substitute.For<ISourceRepository>();
        var enc = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var nav = Substitute.For<INavigationService>();
        nav.CanGoBack.Returns(true);

        var vm = new AddSourceViewModel(repo, enc, messenger, nav);
        vm.CancelCommand.Execute(null);

        nav.Received(1).GoBack();
    }

    [Fact]
    public void CancelCommand_DoesNotCallGoBack_WhenCannotGoBack()
    {
        var repo = Substitute.For<ISourceRepository>();
        var enc = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var nav = Substitute.For<INavigationService>();
        nav.CanGoBack.Returns(false);

        var vm = new AddSourceViewModel(repo, enc, messenger, nav);
        vm.CancelCommand.Execute(null);

        nav.DidNotReceive().GoBack();
    }

    [Fact]
    public async Task SaveCommand_EncryptsCredentials_WhenUsernameAndPasswordProvided()
    {
        var repo = Substitute.For<ISourceRepository>();
        var enc = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var nav = Substitute.For<INavigationService>();

        enc.Encrypt("user1").Returns("enc_user");
        enc.Encrypt("pass1").Returns("enc_pass");

        var created = new Crispy.Domain.Entities.Source
        {
            Name = "Xtream",
            Url = "http://xtream.example",
            SourceType = SourceType.XtreamCodes,
            IsEnabled = true,
        };
        repo.CreateAsync(Arg.Any<Crispy.Domain.Entities.Source>()).Returns(created);

        var vm = new AddSourceViewModel(repo, enc, messenger, nav);
        vm.Name = "Xtream";
        vm.Url = "http://xtream.example";
        vm.SelectedSourceType = SourceType.XtreamCodes;
        vm.Username = "user1";
        vm.Password = "pass1";

        await vm.SaveCommand.ExecuteAsync(null);

        await repo.Received(1).CreateAsync(Arg.Is<Crispy.Domain.Entities.Source>(s =>
            s.EncryptedUsername == "enc_user" &&
            s.EncryptedPassword == "enc_pass"));
    }
}
