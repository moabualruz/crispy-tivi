using Crispy.Domain.Entities;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

[Trait("Category", "Integration")]
public sealed class EpgRepositoryTests : IDisposable
{
    private readonly TestEpgDbContextFactory _factory = new();
    private readonly EpgRepository _sut;

    private static readonly DateTime Base = new(2025, 6, 1, 12, 0, 0, DateTimeKind.Utc);

    public EpgRepositoryTests()
    {
        _sut = new EpgRepository(_factory);
    }

    public void Dispose() => _factory.Dispose();

    private static EpgProgramme MakeProgramme(
        string channelId,
        DateTime start,
        DateTime stop,
        string title = "Show") => new()
        {
            ChannelId = channelId,
            StartUtc = start,
            StopUtc = stop,
            Title = title,
        };

    // ── GetProgrammesAsync ───────────────────────────────────────────────────

    [Fact]
    public async Task GetProgrammesAsync_ReturnsEmpty_WhenNoProgrammesExist()
    {
        var result = await _sut.GetProgrammesAsync("ch1", Base, Base.AddHours(2));

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetProgrammesAsync_ReturnsProgrammesInWindow_OrderedByStartUtc()
    {
        var p1 = MakeProgramme("ch1", Base, Base.AddHours(1), "First");
        var p2 = MakeProgramme("ch1", Base.AddHours(1), Base.AddHours(2), "Second");
        var p3 = MakeProgramme("ch1", Base.AddHours(3), Base.AddHours(4), "Outside");

        await _sut.UpsertRangeAsync([p1, p2, p3]);

        var result = await _sut.GetProgrammesAsync("ch1", Base, Base.AddHours(2));

        result.Should().HaveCount(2);
        result[0].Title.Should().Be("First");
        result[1].Title.Should().Be("Second");
    }

    [Fact]
    public async Task GetProgrammesAsync_ReturnsOnly_ProgrammesMatchingChannelId()
    {
        await _sut.UpsertRangeAsync([
            MakeProgramme("ch1", Base, Base.AddHours(1), "Ch1 Show"),
            MakeProgramme("ch2", Base, Base.AddHours(1), "Ch2 Show"),
        ]);

        var result = await _sut.GetProgrammesAsync("ch1", Base.AddHours(-1), Base.AddHours(2));

        result.Should().ContainSingle(p => p.Title == "Ch1 Show");
    }

    // ── GetCurrentAsync ──────────────────────────────────────────────────────

    [Fact]
    public async Task GetCurrentAsync_ReturnsNull_WhenNoProgrammeIsAiring()
    {
        var result = await _sut.GetCurrentAsync("ch1", Base);

        result.Should().BeNull();
    }

    [Fact]
    public async Task GetCurrentAsync_ReturnsProgramme_WhenAtUtcFallsWithinWindow()
    {
        await _sut.UpsertRangeAsync([
            MakeProgramme("ch1", Base, Base.AddHours(1), "Airing Now"),
        ]);

        var result = await _sut.GetCurrentAsync("ch1", Base.AddMinutes(30));

        result.Should().NotBeNull();
        result!.Title.Should().Be("Airing Now");
    }

    [Fact]
    public async Task GetCurrentAsync_ReturnsNull_WhenAtUtcIsExactlyAtStop()
    {
        await _sut.UpsertRangeAsync([
            MakeProgramme("ch1", Base, Base.AddHours(1), "Ended"),
        ]);

        // StopUtc is exclusive (p.StopUtc > atUtc is the filter)
        var result = await _sut.GetCurrentAsync("ch1", Base.AddHours(1));

        result.Should().BeNull();
    }

    [Fact]
    public async Task GetCurrentAsync_ReturnsProgramme_WhenAtUtcEqualsStartUtc()
    {
        await _sut.UpsertRangeAsync([
            MakeProgramme("ch1", Base, Base.AddHours(1), "Just Started"),
        ]);

        var result = await _sut.GetCurrentAsync("ch1", Base);

        result.Should().NotBeNull();
        result!.Title.Should().Be("Just Started");
    }

    // ── UpsertRangeAsync ─────────────────────────────────────────────────────

    [Fact]
    public async Task UpsertRangeAsync_InsertsNewProgrammes_AndReturnsCount()
    {
        var programmes = new[]
        {
            MakeProgramme("ch1", Base, Base.AddHours(1), "Show A"),
            MakeProgramme("ch1", Base.AddHours(1), Base.AddHours(2), "Show B"),
        };

        var count = await _sut.UpsertRangeAsync(programmes);

        count.Should().Be(2);
    }

    [Fact]
    public async Task UpsertRangeAsync_UpdatesExistingProgramme_WhenChannelIdAndStartMatch()
    {
        await _sut.UpsertRangeAsync([MakeProgramme("ch1", Base, Base.AddHours(1), "Original")]);

        var updated = MakeProgramme("ch1", Base, Base.AddHours(1), "Updated Title");
        updated.Description = "New Description";
        await _sut.UpsertRangeAsync([updated]);

        var result = await _sut.GetCurrentAsync("ch1", Base.AddMinutes(30));
        result!.Title.Should().Be("Updated Title");
        result.Description.Should().Be("New Description");
    }

    [Fact]
    public async Task UpsertRangeAsync_ReturnsZero_WhenEmptyCollectionProvided()
    {
        var count = await _sut.UpsertRangeAsync([]);

        count.Should().Be(0);
    }

    // ── PurgeBeforeAsync ─────────────────────────────────────────────────────

    [Fact]
    public async Task PurgeBeforeAsync_RemovesProgrammesWithStopUtcBeforeCutoff()
    {
        await _sut.UpsertRangeAsync([
            MakeProgramme("ch1", Base.AddHours(-3), Base.AddHours(-2), "Old Show"),
            MakeProgramme("ch1", Base, Base.AddHours(1), "Current Show"),
        ]);

        await _sut.PurgeBeforeAsync(Base);

        var remaining = await _sut.GetProgrammesAsync("ch1", Base.AddHours(-10), Base.AddHours(10));
        remaining.Should().ContainSingle(p => p.Title == "Current Show");
        remaining.Should().NotContain(p => p.Title == "Old Show");
    }

    [Fact]
    public async Task PurgeBeforeAsync_DoesNotThrow_WhenNoProgrammesMatchCutoff()
    {
        await _sut.UpsertRangeAsync([
            MakeProgramme("ch1", Base, Base.AddHours(1), "Future Show"),
        ]);

        var act = async () => await _sut.PurgeBeforeAsync(Base.AddHours(-1));

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task PurgeBeforeAsync_DoesNotThrow_WhenTableIsEmpty()
    {
        var act = async () => await _sut.PurgeBeforeAsync(Base);

        await act.Should().NotThrowAsync();
    }
}
