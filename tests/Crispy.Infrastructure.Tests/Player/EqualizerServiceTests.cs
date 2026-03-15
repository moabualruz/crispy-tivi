using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Player;
using Crispy.Infrastructure.Tests.Helpers;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class EqualizerServiceTests
{
    private sealed class FakePlayerService : IPlayerService
    {
        public PlayerState State => PlayerState.Empty;
        public IObservable<PlayerState> StateChanged => new NullObservable<PlayerState>();
        public IObservable<float[]> AudioSamples => new NullObservable<float[]>();
        public IReadOnlyList<TrackInfo> AudioTracks => [];
        public IReadOnlyList<TrackInfo> SubtitleTracks => [];

        public Task PlayAsync(PlaybackRequest request, CancellationToken ct = default) => Task.CompletedTask;
        public Task PauseAsync() => Task.CompletedTask;
        public Task ResumeAsync() => Task.CompletedTask;
        public Task StopAsync() => Task.CompletedTask;
        public Task SeekAsync(TimeSpan position) => Task.CompletedTask;
        public Task SetRateAsync(float rate) => Task.CompletedTask;
        public Task SetAudioTrackAsync(int trackId) => Task.CompletedTask;
        public Task SetSubtitleTrackAsync(int trackId) => Task.CompletedTask;
        public Task AddSubtitleFileAsync(string filePath) => Task.CompletedTask;
        public Task SetVolumeAsync(float volume) => Task.CompletedTask;
        public Task MuteAsync(bool mute) => Task.CompletedTask;
        public Task SetAspectRatioAsync(string? ratio) => Task.CompletedTask;
    }

    private static EqualizerService CreateSut() =>
        new(new FakePlayerService(), NullLogger<EqualizerService>.Instance);

    [Fact]
    public void IsEnabled_DefaultsFalse()
    {
        using var sut = CreateSut();

        sut.IsEnabled.Should().BeFalse();
    }

    [Fact]
    public void CurrentBands_IsNonNull_OnConstruction()
    {
        using var sut = CreateSut();

        sut.CurrentBands.Should().NotBeNull();
    }

    [Fact]
    public void CurrentBands_HasTenBands_OnConstruction()
    {
        using var sut = CreateSut();

        sut.CurrentBands.Should().HaveCount(10);
    }

    [Fact]
    public void CurrentBands_AllZero_OnConstruction()
    {
        using var sut = CreateSut();

        sut.CurrentBands.Should().AllSatisfy(b => b.Should().Be(0f));
    }

    [Fact]
    public void Presets_IsNonEmpty()
    {
        using var sut = CreateSut();

        sut.Presets.Should().NotBeEmpty();
    }

    [Fact]
    public void Presets_ContainsFlatPreset()
    {
        using var sut = CreateSut();

        sut.Presets.Should().Contain(p => p.Name == "Flat");
    }

    [Fact]
    public void BandsChanged_IsNotNull()
    {
        using var sut = CreateSut();

        sut.BandsChanged.Should().NotBeNull();
    }

    [Fact]
    public async Task SetEnabledAsync_True_SetsIsEnabledTrue()
    {
        using var sut = CreateSut();

        await sut.SetEnabledAsync(true);

        sut.IsEnabled.Should().BeTrue();
    }

    [Fact]
    public async Task SetEnabledAsync_False_SetsIsEnabledFalse()
    {
        using var sut = CreateSut();
        await sut.SetEnabledAsync(true);

        await sut.SetEnabledAsync(false);

        sut.IsEnabled.Should().BeFalse();
    }

    [Fact]
    public async Task SetBandAsync_UpdatesCurrentBands_ForValidIndex()
    {
        using var sut = CreateSut();

        await sut.SetBandAsync(0, 3.0f);

        sut.CurrentBands[0].Should().Be(3.0f);
    }

    [Fact]
    public async Task SetBandAsync_ClampsValueAbove12dB()
    {
        using var sut = CreateSut();

        await sut.SetBandAsync(5, 99.0f);

        sut.CurrentBands[5].Should().Be(12.0f);
    }

    [Fact]
    public async Task SetBandAsync_ClampsValueBelowMinus12dB()
    {
        using var sut = CreateSut();

        await sut.SetBandAsync(5, -99.0f);

        sut.CurrentBands[5].Should().Be(-12.0f);
    }

    [Fact]
    public async Task SetBandAsync_ThrowsArgumentOutOfRange_ForNegativeIndex()
    {
        using var sut = CreateSut();

        var act = async () => await sut.SetBandAsync(-1, 0f);

        await act.Should().ThrowAsync<ArgumentOutOfRangeException>();
    }

    [Fact]
    public async Task SetBandAsync_ThrowsArgumentOutOfRange_ForIndexAbove9()
    {
        using var sut = CreateSut();

        var act = async () => await sut.SetBandAsync(10, 0f);

        await act.Should().ThrowAsync<ArgumentOutOfRangeException>();
    }

    [Fact]
    public async Task ResetAsync_SetsAllBandsToZero()
    {
        using var sut = CreateSut();
        await sut.SetBandAsync(0, 6.0f);
        await sut.SetBandAsync(9, -6.0f);

        await sut.ResetAsync();

        sut.CurrentBands.Should().AllSatisfy(b => b.Should().Be(0f));
    }

    [Fact]
    public async Task ApplyPresetAsync_UpdatesBands_ForKnownPreset()
    {
        using var sut = CreateSut();

        await sut.ApplyPresetAsync("Bass Boost");

        // Bass Boost has non-zero low bands
        sut.CurrentBands[0].Should().Be(6f);
    }

    [Fact]
    public async Task ApplyPresetAsync_DoesNotThrow_ForUnknownPreset()
    {
        using var sut = CreateSut();

        var act = async () => await sut.ApplyPresetAsync("NonExistentPreset");

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public void Dispose_DoesNotThrow()
    {
        var sut = CreateSut();

        var act = () => sut.Dispose();

        act.Should().NotThrow();
    }

    [Fact]
    public async Task BandsChanged_EmitsOnSetBand()
    {
        using var sut = CreateSut();
        float[]? emitted = null;
        using var _ = sut.BandsChanged.Subscribe(bands => emitted = bands);

        await sut.SetBandAsync(3, 5.0f);

        emitted.Should().NotBeNull();
        emitted![3].Should().Be(5.0f);
    }
}
