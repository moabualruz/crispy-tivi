using Crispy.UI.ViewModels;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

/// <summary>
/// Unit tests for OsdViewModel — verifies observable property notifications
/// for LIVE badge, timeshift badge, and GO LIVE button visibility.
/// </summary>
[Trait("Category", "Unit")]
public class OsdViewModelTests
{
    [Fact]
    public void IsLive_DefaultFalse()
    {
        var sut = new OsdViewModel();
        sut.IsLive.Should().BeFalse("IsLive defaults to false");
    }

    [Fact]
    public void IsLive_SetTrue_RaisesPropertyChanged()
    {
        var sut = new OsdViewModel();
        var raised = false;
        sut.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(OsdViewModel.IsLive))
                raised = true;
        };

        sut.IsLive = true;

        raised.Should().BeTrue("setting IsLive must raise PropertyChanged");
        sut.IsLive.Should().BeTrue();
    }

    [Fact]
    public void IsTimeshifted_SetTrue_RaisesPropertyChanged()
    {
        var sut = new OsdViewModel();
        var raised = false;
        sut.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(OsdViewModel.IsTimeshifted))
                raised = true;
        };

        sut.IsTimeshifted = true;

        raised.Should().BeTrue("setting IsTimeshifted must raise PropertyChanged");
        sut.IsTimeshifted.Should().BeTrue();
    }

    [Fact]
    public void ShowGoLive_SetTrue_RaisesPropertyChanged()
    {
        var sut = new OsdViewModel();
        var raised = false;
        sut.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(OsdViewModel.ShowGoLive))
                raised = true;
        };

        sut.ShowGoLive = true;

        raised.Should().BeTrue("setting ShowGoLive must raise PropertyChanged");
        sut.ShowGoLive.Should().BeTrue();
    }

    [Fact]
    public void TimeshiftOffset_SetValue_RaisesPropertyChanged()
    {
        var sut = new OsdViewModel();
        var raised = false;
        sut.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(OsdViewModel.TimeshiftOffset))
                raised = true;
        };

        sut.TimeshiftOffset = "-00:30";

        raised.Should().BeTrue("setting TimeshiftOffset must raise PropertyChanged");
        sut.TimeshiftOffset.Should().Be("-00:30");
    }

    [Fact]
    public void LiveBadgeVisible_WhenIsLiveTrue_AndNotTimeshifted()
    {
        // Simulates the AXAML MultiBinding: IsLive AND !IsTimeshifted
        var sut = new OsdViewModel();

        sut.IsLive = true;
        sut.IsTimeshifted = false;

        var liveBadgeVisible = sut.IsLive && !sut.IsTimeshifted;
        liveBadgeVisible.Should().BeTrue("LIVE badge shows when live and not timeshifted");
    }

    [Fact]
    public void LiveBadgeHidden_WhenTimeshifted()
    {
        var sut = new OsdViewModel();

        sut.IsLive = true;
        sut.IsTimeshifted = true;

        var liveBadgeVisible = sut.IsLive && !sut.IsTimeshifted;
        liveBadgeVisible.Should().BeFalse("LIVE badge hides when timeshifted");
    }

    [Fact]
    public void ShowOsd_SetsIsOsdVisibleTrue()
    {
        var sut = new OsdViewModel();
        sut.IsOsdVisible = false;

        sut.ShowOsd();

        sut.IsOsdVisible.Should().BeTrue("ShowOsd must make OSD visible");
    }
}
