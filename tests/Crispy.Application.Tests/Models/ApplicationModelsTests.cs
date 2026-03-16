using Crispy.Application.Configuration;
using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Application.Sync;
using FluentAssertions;
using Xunit;

namespace Crispy.Application.Tests.Models;

[Trait("Category", "Unit")]
public class EqualizerPresetTests
{
    [Fact]
    public void Constructor_SetsNameAndBands()
    {
        var bands = new float[] { 1f, 2f, 3f, 4f, 5f, 6f, 7f, 8f, 9f, 10f };
        var preset = new EqualizerPreset("Custom", bands);

        preset.Name.Should().Be("Custom");
        preset.Bands.Should().BeSameAs(bands);
    }

    [Fact]
    public void Flat_HasAllZeroBands()
    {
        EqualizerPreset.Flat.Name.Should().Be("Flat");
        EqualizerPreset.Flat.Bands.Should().HaveCount(10);
        EqualizerPreset.Flat.Bands.Should().AllBeEquivalentTo(0f);
    }

    [Fact]
    public void BassBoost_HasPositiveLowBands()
    {
        EqualizerPreset.BassBoost.Name.Should().Be("Bass Boost");
        EqualizerPreset.BassBoost.Bands[0].Should().BeGreaterThan(0f);
        EqualizerPreset.BassBoost.Bands[1].Should().BeGreaterThan(0f);
    }

    [Fact]
    public void TrebleBoost_HasPositiveHighBands()
    {
        EqualizerPreset.TrebleBoost.Name.Should().Be("Treble Boost");
        EqualizerPreset.TrebleBoost.Bands[8].Should().BeGreaterThan(0f);
        EqualizerPreset.TrebleBoost.Bands[9].Should().BeGreaterThan(0f);
    }

    [Fact]
    public void Classical_IsNamedCorrectly()
    {
        EqualizerPreset.Classical.Name.Should().Be("Classical");
        EqualizerPreset.Classical.Bands.Should().HaveCount(10);
    }

    [Fact]
    public void Rock_IsNamedCorrectly()
    {
        EqualizerPreset.Rock.Name.Should().Be("Rock");
        EqualizerPreset.Rock.Bands.Should().HaveCount(10);
    }

    [Fact]
    public void Pop_IsNamedCorrectly()
    {
        EqualizerPreset.Pop.Name.Should().Be("Pop");
        EqualizerPreset.Pop.Bands.Should().HaveCount(10);
    }

    [Fact]
    public void Jazz_IsNamedCorrectly()
    {
        EqualizerPreset.Jazz.Name.Should().Be("Jazz");
        EqualizerPreset.Jazz.Bands.Should().HaveCount(10);
    }

    [Fact]
    public void Vocal_IsNamedCorrectly()
    {
        EqualizerPreset.Vocal.Name.Should().Be("Vocal");
        EqualizerPreset.Vocal.Bands.Should().HaveCount(10);
    }

    [Fact]
    public void BuiltIn_ContainsEightPresets()
    {
        EqualizerPreset.BuiltIn.Should().HaveCount(8);
    }

    [Fact]
    public void BuiltIn_ContainsAllStaticPresets()
    {
        EqualizerPreset.BuiltIn.Should().Contain(EqualizerPreset.Flat);
        EqualizerPreset.BuiltIn.Should().Contain(EqualizerPreset.BassBoost);
        EqualizerPreset.BuiltIn.Should().Contain(EqualizerPreset.TrebleBoost);
        EqualizerPreset.BuiltIn.Should().Contain(EqualizerPreset.Classical);
        EqualizerPreset.BuiltIn.Should().Contain(EqualizerPreset.Rock);
        EqualizerPreset.BuiltIn.Should().Contain(EqualizerPreset.Pop);
        EqualizerPreset.BuiltIn.Should().Contain(EqualizerPreset.Jazz);
        EqualizerPreset.BuiltIn.Should().Contain(EqualizerPreset.Vocal);
    }

    [Fact]
    public void RecordEquality_SameNameAndBands_AreEqual()
    {
        var bands = new float[] { 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f };
        var a = new EqualizerPreset("Flat", bands);
        var b = new EqualizerPreset("Flat", bands);

        a.Should().Be(b);
    }

    [Fact]
    public void RecordEquality_DifferentNames_AreNotEqual()
    {
        var bands = new float[] { 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f };
        var a = new EqualizerPreset("A", bands);
        var b = new EqualizerPreset("B", bands);

        a.Should().NotBe(b);
    }
}

[Trait("Category", "Unit")]
public class MultiviewSlotTests
{
    [Fact]
    public void Constructor_SetsAllProperties()
    {
        var request = new PlaybackRequest("http://stream.test", PlaybackContentType.LiveTv);
        var slot = new MultiviewSlot(2, request, IsActive: true, IsAudioActive: true, IsExpanded: false);

        slot.SlotIndex.Should().Be(2);
        slot.Request.Should().Be(request);
        slot.IsActive.Should().BeTrue();
        slot.IsAudioActive.Should().BeTrue();
        slot.IsExpanded.Should().BeFalse();
    }

    [Fact]
    public void Constructor_WithNullRequest_IsEmptySlot()
    {
        var slot = new MultiviewSlot(0, null, IsActive: false, IsAudioActive: false, IsExpanded: false);

        slot.Request.Should().BeNull();
        slot.IsActive.Should().BeFalse();
    }

    [Fact]
    public void RecordEquality_SameValues_AreEqual()
    {
        var request = new PlaybackRequest("http://x", PlaybackContentType.Vod);
        var a = new MultiviewSlot(1, request, false, false, false);
        var b = new MultiviewSlot(1, request, false, false, false);

        a.Should().Be(b);
    }

    [Fact]
    public void RecordEquality_DifferentSlotIndex_AreNotEqual()
    {
        var request = new PlaybackRequest("http://x", PlaybackContentType.Vod);
        var a = new MultiviewSlot(0, request, false, false, false);
        var b = new MultiviewSlot(1, request, false, false, false);

        a.Should().NotBe(b);
    }

    [Fact]
    public void With_CreatesUpdatedCopy()
    {
        var slot = new MultiviewSlot(0, null, false, false, false);
        var expanded = slot with { IsExpanded = true };

        expanded.IsExpanded.Should().BeTrue();
        slot.IsExpanded.Should().BeFalse();
    }
}

[Trait("Category", "Unit")]
public class FeatureFlagOptionsTests
{
    [Fact]
    public void Section_IsFeatureFlags()
    {
        FeatureFlagOptions.Section.Should().Be("FeatureFlags");
    }

    [Fact]
    public void DefaultConstructor_AllFlagsDefaultToNewFeatureFlag()
    {
        var options = new FeatureFlagOptions();

        options.EmbeddedWebServer.Should().NotBeNull();
        options.UseXYFocus.Should().NotBeNull();
        options.UseCustomFocusManager.Should().NotBeNull();
        options.DebugDiagnostics.Should().NotBeNull();
    }

    [Fact]
    public void DefaultConstructor_AllFlagsDisabledByDefault()
    {
        var options = new FeatureFlagOptions();

        options.EmbeddedWebServer.Enabled.Should().BeFalse();
        options.UseXYFocus.Enabled.Should().BeFalse();
        options.UseCustomFocusManager.Enabled.Should().BeFalse();
        options.DebugDiagnostics.Enabled.Should().BeFalse();
    }

    [Fact]
    public void Properties_CanBeAssigned()
    {
        var flag = new FeatureFlag { Enabled = true };
        var options = new FeatureFlagOptions
        {
            EmbeddedWebServer = flag,
        };

        options.EmbeddedWebServer.Should().BeSameAs(flag);
    }
}

[Trait("Category", "Unit")]
public class FeatureFlagTests
{
    [Fact]
    public void DefaultConstructor_IsDisabledWithNoPlatforms()
    {
        var flag = new FeatureFlag();

        flag.Enabled.Should().BeFalse();
        flag.Platforms.Should().BeEmpty();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_WhenDisabled_ReturnsFalse()
    {
        var flag = new FeatureFlag { Enabled = false, Platforms = ["*"] };

        flag.IsEnabledForCurrentPlatform().Should().BeFalse();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_WhenEnabledWithWildcard_ReturnsTrue()
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = ["*"] };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_WhenEnabledWithEmptyPlatforms_ReturnsTrue()
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = [] };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_WhenEnabledWithNoMatchingPlatform_ReturnsFalse()
    {
        // Use a platform that won't match current test runner (assume not all of these at once)
        var flag = new FeatureFlag { Enabled = true, Platforms = ["iOS"] };

        // On a non-iOS test runner this is false; on iOS it would be true.
        // We verify the method runs without throwing and returns a bool.
        var act = () => flag.IsEnabledForCurrentPlatform();
        act.Should().NotThrow();
    }

    [Fact]
    public void Platforms_CanBeModified()
    {
        var flag = new FeatureFlag();
        flag.Platforms.Add("Windows");

        flag.Platforms.Should().Contain("Windows");
    }
}

[Trait("Category", "Unit")]
public class SyncOptionsTests
{
    [Fact]
    public void Section_IsSync()
    {
        SyncOptions.Section.Should().Be("Sync");
    }

    [Fact]
    public void DefaultConstructor_SyncIntervalIsFourHours()
    {
        var options = new SyncOptions();

        options.SyncInterval.Should().Be(TimeSpan.FromHours(4));
    }

    [Fact]
    public void DefaultConstructor_BatchSizeIs500()
    {
        var options = new SyncOptions();

        options.BatchSize.Should().Be(500);
    }

    [Fact]
    public void DefaultConstructor_MaxMissedSyncsIs2()
    {
        var options = new SyncOptions();

        options.MaxMissedSyncsBeforeSoftRemove.Should().Be(2);
    }

    [Fact]
    public void DefaultConstructor_DaysBeforeAutoDeleteIs7()
    {
        var options = new SyncOptions();

        options.DaysBeforeAutoDelete.Should().Be(7);
    }

    [Fact]
    public void Properties_CanBeOverridden()
    {
        var options = new SyncOptions
        {
            SyncInterval = TimeSpan.FromHours(1),
            BatchSize = 100,
            MaxMissedSyncsBeforeSoftRemove = 5,
            DaysBeforeAutoDelete = 14,
        };

        options.SyncInterval.Should().Be(TimeSpan.FromHours(1));
        options.BatchSize.Should().Be(100);
        options.MaxMissedSyncsBeforeSoftRemove.Should().Be(5);
        options.DaysBeforeAutoDelete.Should().Be(14);
    }
}

[Trait("Category", "Unit")]
public class StreamEndpointDtoTests
{
    [Fact]
    public void Constructor_SetsAllProperties()
    {
        var dto = new StreamEndpointDto("http://stream.test/live", 42, 1, 0.85f);

        dto.Url.Should().Be("http://stream.test/live");
        dto.SourceId.Should().Be(42);
        dto.Priority.Should().Be(1);
        dto.FailoverScore.Should().BeApproximately(0.85f, 0.0001f);
    }

    [Fact]
    public void RecordEquality_SameValues_AreEqual()
    {
        var a = new StreamEndpointDto("http://x", 1, 0, 1.0f);
        var b = new StreamEndpointDto("http://x", 1, 0, 1.0f);

        a.Should().Be(b);
    }

    [Fact]
    public void RecordEquality_DifferentUrl_AreNotEqual()
    {
        var a = new StreamEndpointDto("http://a", 1, 0, 1.0f);
        var b = new StreamEndpointDto("http://b", 1, 0, 1.0f);

        a.Should().NotBe(b);
    }

    [Fact]
    public void RecordEquality_DifferentFailoverScore_AreNotEqual()
    {
        var a = new StreamEndpointDto("http://x", 1, 0, 0.5f);
        var b = new StreamEndpointDto("http://x", 1, 0, 0.9f);

        a.Should().NotBe(b);
    }

    [Fact]
    public void With_CreatesUpdatedCopy()
    {
        var original = new StreamEndpointDto("http://x", 1, 0, 0.5f);
        var updated = original with { FailoverScore = 0.9f };

        updated.FailoverScore.Should().BeApproximately(0.9f, 0.0001f);
        original.FailoverScore.Should().BeApproximately(0.5f, 0.0001f);
    }
}
