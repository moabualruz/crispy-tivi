using System.Collections.Generic;

using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class EpgViewModelTests
{
    private readonly IEpgRepository _epgRepo;
    private readonly IChannelRepository _channelRepo;
    private readonly ISourceRepository _sourceRepo;
    private readonly EpgViewModel _sut;

    public EpgViewModelTests()
    {
        _epgRepo = Substitute.For<IEpgRepository>();
        _channelRepo = Substitute.For<IChannelRepository>();
        _sourceRepo = Substitute.For<ISourceRepository>();

        _sourceRepo.GetAllAsync().Returns(new List<Source>());
        _channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(new List<Channel>());
        _epgRepo.GetProgrammesAsync(
                Arg.Any<string>(), Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<CancellationToken>())
            .Returns(new List<EpgProgramme>());

        _sut = new EpgViewModel(_epgRepo, _channelRepo, _sourceRepo);
    }

    [Fact]
    public void Title_IsTvGuide()
    {
        _sut.Title.Should().Be("TV Guide");
    }

    [Fact]
    public void Channels_IsEmpty_Initially()
    {
        _sut.Channels.Should().BeEmpty("no channels are loaded before the async operation completes");
    }

    [Fact]
    public void SelectedChannel_IsNull_Initially()
    {
        _sut.SelectedChannel.Should().BeNull("no channel is selected on construction");
    }

    [Fact]
    public void ProgrammeItems_IsEmpty_Initially()
    {
        _sut.ProgrammeItems.Should().BeEmpty("no programmes are loaded before a channel is selected");
    }
}
