using Avalonia.Headless.XUnit;

using CommunityToolkit.Mvvm.Messaging;

using Crispy.Application.Security;
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
public class AddSourceViewTests
{
    [AvaloniaFact]
    public void AddSourceView_RendersWithoutException()
    {
        var sourceRepo = Substitute.For<ISourceRepository>();
        var credentialEncryption = Substitute.For<ICredentialEncryption>();
        var messenger = Substitute.For<IMessenger>();
        var navigationService = Substitute.For<INavigationService>();

        var vm = new AddSourceViewModel(sourceRepo, credentialEncryption, messenger, navigationService);
        var window = HeadlessTestHelpers.CreateWindow<AddSourceView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }
}
