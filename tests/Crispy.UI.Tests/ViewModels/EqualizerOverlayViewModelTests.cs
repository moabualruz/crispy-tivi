using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

/// <summary>
/// Unit tests for EqualizerOverlayViewModel — verifies band initialisation,
/// enabled/visible defaults, and preset selection state.
/// </summary>
[Trait("Category", "Unit")]
public class EqualizerOverlayViewModelTests
{
    private readonly IEqualizerService _equalizerService;
    private readonly TestSubject<float[]> _bandsSubject;
    private readonly EqualizerOverlayViewModel _sut;

    public EqualizerOverlayViewModelTests()
    {
        _bandsSubject = new TestSubject<float[]>();

        _equalizerService = Substitute.For<IEqualizerService>();
        _equalizerService.IsEnabled.Returns(false);
        _equalizerService.CurrentBands.Returns(new float[10]);
        _equalizerService.BandsChanged.Returns(_bandsSubject);
        _equalizerService.Presets.Returns([]);

        _sut = new EqualizerOverlayViewModel(_equalizerService);
    }

    [Fact]
    public void Bands_HasTenItems()
    {
        _sut.Bands.Should().HaveCount(10,
            "The equalizer always exposes exactly 10 frequency bands (PLR-33)");
    }

    [Fact]
    public void IsEnabled_FalseInitially()
    {
        _sut.IsEnabled.Should().BeFalse(
            "The equalizer is disabled by default; user must explicitly enable it");
    }

    [Fact]
    public void IsVisible_FalseInitially()
    {
        _sut.IsVisible.Should().BeFalse(
            "The equalizer overlay panel is hidden by default and shown on demand");
    }

    [Fact]
    public void SelectedPresetName_NullInitially()
    {
        _sut.SelectedPresetName.Should().BeNull(
            "No preset is selected on startup; user selects one explicitly");
    }
}
