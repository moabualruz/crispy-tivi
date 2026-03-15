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
public class EpgViewTests
{
    [AvaloniaFact]
    public void EpgView_RendersWithoutException()
    {
        var epgRepo = Substitute.For<IEpgRepository>();
        epgRepo.GetProgrammesAsync(
                Arg.Any<string>(),
                Arg.Any<DateTime>(),
                Arg.Any<DateTime>(),
                Arg.Any<CancellationToken>())
            .Returns([]);

        var channelRepo = Substitute.For<IChannelRepository>();
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns([]);

        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns([]);

        var vm = new EpgViewModel(epgRepo, channelRepo, sourceRepo);
        var window = HeadlessTestHelpers.CreateWindow<EpgView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }
}
