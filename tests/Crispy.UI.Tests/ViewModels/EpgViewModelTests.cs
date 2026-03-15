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

    // ─── OnSelectedChannelChanged (lines 106-116) ─────────────────────────────

    [Fact]
    public async Task SelectedChannel_WhenSetToNull_ClearsProgrammeItemsAndCurrentProgramme()
    {
        var channel = new Channel { Id = 1, Title = "BBC One", TvgId = "bbc1", SourceId = 1 };

        // First select a channel so there's something to clear
        var programme = new EpgProgramme
        {
            ChannelId = "bbc1",
            Title = "News at Ten",
            StartUtc = DateTime.UtcNow.AddHours(-1),
            StopUtc = DateTime.UtcNow.AddHours(1),
        };
        _epgRepo.GetProgrammesAsync("bbc1", Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<CancellationToken>())
            .Returns(new List<EpgProgramme> { programme });

        _sut.SelectedChannel = channel;
        await Task.Delay(100);

        // Now set to null
        _sut.SelectedChannel = null;

        _sut.ProgrammeItems.Should().BeEmpty("clearing selection must empty the programme list");
        _sut.CurrentProgramme.Should().BeNull("clearing selection must clear the current programme");
    }

    [Fact]
    public async Task SelectedChannel_WhenSet_CallsGetProgrammesAsync()
    {
        var channel = new Channel { Id = 2, Title = "ITV", TvgId = "itv1", SourceId = 1 };

        _epgRepo.GetProgrammesAsync(Arg.Any<string>(), Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<CancellationToken>())
            .Returns(new List<EpgProgramme>());

        _sut.SelectedChannel = channel;
        await Task.Delay(100);

        await _epgRepo.Received(1).GetProgrammesAsync(
            "itv1",
            Arg.Any<DateTime>(),
            Arg.Any<DateTime>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task SelectedChannel_WhenSet_UsesTitleAsFallbackWhenTvgIdIsEmpty()
    {
        var channel = new Channel { Id = 3, Title = "Local TV", TvgId = string.Empty, SourceId = 1 };

        _epgRepo.GetProgrammesAsync(Arg.Any<string>(), Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<CancellationToken>())
            .Returns(new List<EpgProgramme>());

        _sut.SelectedChannel = channel;
        await Task.Delay(100);

        await _epgRepo.Received(1).GetProgrammesAsync(
            "Local TV",
            Arg.Any<DateTime>(),
            Arg.Any<DateTime>(),
            Arg.Any<CancellationToken>());
    }

    // ─── ProgrammeItems population (line 132-133) ────────────────────────────

    [Fact]
    public async Task SelectedChannel_WhenSet_PopulatesProgrammeItems()
    {
        var channel = new Channel { Id = 4, Title = "CH4", TvgId = "ch4", SourceId = 1 };
        var p1 = new EpgProgramme { ChannelId = "ch4", Title = "Prog1", StartUtc = DateTime.UtcNow.AddHours(-2), StopUtc = DateTime.UtcNow.AddHours(-1) };
        var p2 = new EpgProgramme { ChannelId = "ch4", Title = "Prog2", StartUtc = DateTime.UtcNow.AddHours(-1), StopUtc = DateTime.UtcNow.AddHours(1) };

        _epgRepo.GetProgrammesAsync("ch4", Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<CancellationToken>())
            .Returns(new List<EpgProgramme> { p1, p2 });

        _sut.SelectedChannel = channel;
        await Task.Delay(100);

        _sut.ProgrammeItems.Should().HaveCount(2, "two programmes were returned by the repository");
        _sut.ProgrammeItems[0].Programme.Title.Should().Be("Prog1");
        _sut.ProgrammeItems[1].Programme.Title.Should().Be("Prog2");
    }

    [Fact]
    public async Task SelectedChannel_WhenSet_SetsCurrentProgramme_ToCurrentlyAiring()
    {
        var channel = new Channel { Id = 5, Title = "Sky", TvgId = "sky1", SourceId = 1 };
        var past = new EpgProgramme { ChannelId = "sky1", Title = "Past Show", StartUtc = DateTime.UtcNow.AddHours(-3), StopUtc = DateTime.UtcNow.AddHours(-1) };
        var current = new EpgProgramme { ChannelId = "sky1", Title = "Live Now", StartUtc = DateTime.UtcNow.AddMinutes(-30), StopUtc = DateTime.UtcNow.AddMinutes(30) };

        _epgRepo.GetProgrammesAsync("sky1", Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<CancellationToken>())
            .Returns(new List<EpgProgramme> { past, current });

        _sut.SelectedChannel = channel;
        await Task.Delay(100);

        _sut.CurrentProgramme.Should().NotBeNull();
        _sut.CurrentProgramme!.Title.Should().Be("Live Now", "only the currently-airing programme should be current");
    }

    [Fact]
    public async Task ProgrammeItem_IsCurrent_IsTrueOnlyForCurrentlyAiringProgramme()
    {
        var channel = new Channel { Id = 6, Title = "BBC Two", TvgId = "bbc2", SourceId = 1 };
        var past = new EpgProgramme { ChannelId = "bbc2", Title = "Old Show", StartUtc = DateTime.UtcNow.AddHours(-3), StopUtc = DateTime.UtcNow.AddHours(-1) };
        var live = new EpgProgramme { ChannelId = "bbc2", Title = "On Now", StartUtc = DateTime.UtcNow.AddMinutes(-10), StopUtc = DateTime.UtcNow.AddMinutes(50) };

        _epgRepo.GetProgrammesAsync("bbc2", Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<CancellationToken>())
            .Returns(new List<EpgProgramme> { past, live });

        _sut.SelectedChannel = channel;
        await Task.Delay(100);

        _sut.ProgrammeItems[0].IsCurrent.Should().BeFalse("the past show is not currently airing");
        _sut.ProgrammeItems[1].IsCurrent.Should().BeTrue("this programme is currently airing");
    }
}
