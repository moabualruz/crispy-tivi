using Crispy.UI.ViewModels;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

/// <summary>
/// Unit tests for nested record types and internal helpers declared in PlayerViewModel.cs.
/// </summary>
[Trait("Category", "Unit")]
public class EpgProgrammeRefTests
{
    [Fact]
    public void Constructor_PopulatesAllProperties()
    {
        var start = new DateTimeOffset(2024, 6, 15, 20, 0, 0, TimeSpan.Zero);
        var end = new DateTimeOffset(2024, 6, 15, 21, 0, 0, TimeSpan.Zero);

        var epg = new EpgProgrammeRef("News Tonight", start, end);

        epg.Title.Should().Be("News Tonight");
        epg.StartTime.Should().Be(start);
        epg.EndTime.Should().Be(end);
    }

    [Fact]
    public void RecordEquality_TwoIdenticalRefs_AreEqual()
    {
        var start = DateTimeOffset.UtcNow;
        var end = start.AddHours(1);

        var a = new EpgProgrammeRef("News", start, end);
        var b = new EpgProgrammeRef("News", start, end);

        a.Should().Be(b);
    }

    [Fact]
    public void RecordEquality_DifferentTitle_AreNotEqual()
    {
        var start = DateTimeOffset.UtcNow;
        var end = start.AddHours(1);

        var a = new EpgProgrammeRef("News", start, end);
        var b = new EpgProgrammeRef("Sports", start, end);

        a.Should().NotBe(b);
    }
}

/// <summary>
/// Unit tests for ChapterMark nested record.
/// </summary>
[Trait("Category", "Unit")]
public class ChapterMarkTests
{
    [Fact]
    public void Constructor_PopulatesAllProperties()
    {
        var position = TimeSpan.FromSeconds(120);

        var chapter = new ChapterMark(position, "Introduction");

        chapter.Position.Should().Be(position);
        chapter.Title.Should().Be("Introduction");
    }

    [Fact]
    public void RecordEquality_TwoIdenticalChapters_AreEqual()
    {
        var pos = TimeSpan.FromSeconds(60);
        var a = new ChapterMark(pos, "Intro");
        var b = new ChapterMark(pos, "Intro");

        a.Should().Be(b);
    }

    [Fact]
    public void RecordEquality_DifferentPosition_AreNotEqual()
    {
        var a = new ChapterMark(TimeSpan.FromSeconds(60), "Intro");
        var b = new ChapterMark(TimeSpan.FromSeconds(120), "Intro");

        a.Should().NotBe(b);
    }
}

/// <summary>
/// Unit tests for the internal SpeedPresets helper class.
/// </summary>
[Trait("Category", "Unit")]
public class SpeedPresetsTests
{
    [Fact]
    public void Next_ReturnsNextPreset_WhenCurrentIsNotLast()
    {
        var result = SpeedPresets.Next(1.0f);

        result.Should().Be(1.25f);
    }

    [Fact]
    public void Next_ReturnsSameValue_WhenCurrentIsLastPreset()
    {
        var result = SpeedPresets.Next(2.0f);

        result.Should().Be(2.0f);
    }

    [Fact]
    public void Next_ReturnsSameValue_WhenCurrentIsNotInPresets()
    {
        var result = SpeedPresets.Next(3.0f);

        result.Should().Be(3.0f);
    }

    [Fact]
    public void Next_ReturnsSecondPreset_WhenCurrentIsFirst()
    {
        var result = SpeedPresets.Next(0.5f);

        result.Should().Be(0.75f);
    }

    [Fact]
    public void Previous_ReturnsPreviousPreset_WhenCurrentIsNotFirst()
    {
        var result = SpeedPresets.Previous(1.0f);

        result.Should().Be(0.75f);
    }

    [Fact]
    public void Previous_ReturnsSameValue_WhenCurrentIsFirstPreset()
    {
        var result = SpeedPresets.Previous(0.5f);

        result.Should().Be(0.5f);
    }

    [Fact]
    public void Previous_ReturnsSameValue_WhenCurrentIsNotInPresets()
    {
        var result = SpeedPresets.Previous(99.0f);

        result.Should().Be(99.0f);
    }

    [Fact]
    public void Previous_ReturnsSecondToLastPreset_WhenCurrentIsLast()
    {
        var result = SpeedPresets.Previous(2.0f);

        result.Should().Be(1.5f);
    }
}
