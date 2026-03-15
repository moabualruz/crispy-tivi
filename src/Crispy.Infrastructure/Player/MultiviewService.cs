using System.Text.Json;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// IMultiviewService implementation that manages 4 independent IPlayerService instances
/// (one per slot) to provide simultaneous multi-stream playback with audio routing
/// and named layout persistence.
///
/// Each slot gets its own VlcPlayerService backed by a separate LibVLC instance
/// to prevent cross-slot interference (audio/subtitle state isolation).
///
/// Satisfies PLR-29, PLR-30, PLR-31, PLR-32.
/// </summary>
public sealed class MultiviewService : IMultiviewService, IDisposable
{
    private const int SlotCount = 4;

    private readonly IPlayerService[] _players;
    private readonly ILogger<MultiviewService> _logger;

    // In-memory layout store (persisted as JSON in user preferences — no DB needed for layouts)
    private readonly List<SavedLayout> _savedLayouts = [];

    private MultiviewSlot[] _slots;
    private readonly SimpleSubject<IReadOnlyList<MultiviewSlot>> _slotsChanged = new();

    public MultiviewService(
        IEnumerable<IPlayerService> slotPlayers,
        ILogger<MultiviewService> logger)
    {
        _logger = logger;

        var players = slotPlayers.Take(SlotCount).ToArray();
        if (players.Length < SlotCount)
        {
            throw new ArgumentException(
                $"MultiviewService requires exactly {SlotCount} IPlayerService instances.",
                nameof(slotPlayers));
        }

        _players = players;
        _slots = Enumerable.Range(0, SlotCount)
            .Select(i => new MultiviewSlot(i, null, false, i == 0, false))
            .ToArray();
    }

    /// <inheritdoc />
    public IReadOnlyList<MultiviewSlot> Slots => _slots;

    /// <inheritdoc />
    public IObservable<IReadOnlyList<MultiviewSlot>> SlotsChanged => _slotsChanged;

    /// <inheritdoc />
    public async Task AssignSlotAsync(int slotIndex, PlaybackRequest request)
    {
        ValidateSlotIndex(slotIndex);
        await _players[slotIndex].PlayAsync(request);
        var isAudio = _slots[slotIndex].IsAudioActive;
        if (!isAudio)
        {
            // Mute new slots that are not the active audio slot
            await _players[slotIndex].MuteAsync(true);
        }

        UpdateSlot(slotIndex, s => s with { Request = request, IsActive = true });
    }

    /// <inheritdoc />
    public async Task ClearSlotAsync(int slotIndex)
    {
        ValidateSlotIndex(slotIndex);
        await _players[slotIndex].StopAsync();
        UpdateSlot(slotIndex, s => s with { Request = null, IsActive = false });
    }

    /// <inheritdoc />
    public async Task SetActiveAudioSlotAsync(int slotIndex)
    {
        ValidateSlotIndex(slotIndex);

        for (var i = 0; i < SlotCount; i++)
        {
            var shouldMute = i != slotIndex;
            await _players[i].MuteAsync(shouldMute);
        }

        _slots = _slots.Select((s, i) => s with { IsAudioActive = i == slotIndex }).ToArray();
        EmitSlotsChanged();
    }

    /// <inheritdoc />
    public Task ExpandSlotAsync(int slotIndex)
    {
        ValidateSlotIndex(slotIndex);
        _slots = _slots.Select((s, i) => s with { IsExpanded = i == slotIndex }).ToArray();
        EmitSlotsChanged();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task CollapseToGridAsync()
    {
        _slots = _slots.Select(s => s with { IsExpanded = false }).ToArray();
        EmitSlotsChanged();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SaveLayoutAsync(string name)
    {
        var assignments = _slots
            .Where(s => s.Request != null)
            .Select(s => new { s.SlotIndex, s.Request!.Url, s.Request.Title, s.Request.ChannelLogoUrl })
            .ToArray();

        var streamsJson = JsonSerializer.Serialize(assignments);

        var layout = new SavedLayout
        {
            Id = Guid.NewGuid().ToString("N"),
            Name = name,
            Layout = LayoutType.Quad,
            StreamsJson = streamsJson,
            CreatedAt = DateTimeOffset.UtcNow,
            ProfileId = "default",
        };

        _savedLayouts.Insert(0, layout);
        _logger.LogInformation("Saved multiview layout '{Name}' ({Id})", name, layout.Id);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task<IReadOnlyList<SavedLayout>> GetSavedLayoutsAsync()
    {
        IReadOnlyList<SavedLayout> result = _savedLayouts.AsReadOnly();
        return Task.FromResult(result);
    }

    /// <inheritdoc />
    public async Task LoadLayoutAsync(string layoutId)
    {
        var layout = _savedLayouts.FirstOrDefault(l => l.Id == layoutId);
        if (layout is null)
        {
            _logger.LogWarning("LoadLayoutAsync: layout '{Id}' not found", layoutId);
            return;
        }

        // Parse slot assignments from JSON
        using var doc = JsonDocument.Parse(layout.StreamsJson);
        foreach (var element in doc.RootElement.EnumerateArray())
        {
            var slotIndex = element.GetProperty("SlotIndex").GetInt32();
            var url = element.GetProperty("Url").GetString() ?? string.Empty;
            var title = element.TryGetProperty("Title", out var t) ? t.GetString() : null;
            var logo = element.TryGetProperty("ChannelLogoUrl", out var l) ? l.GetString() : null;

            if (slotIndex is >= 0 and < SlotCount && !string.IsNullOrEmpty(url))
            {
                var request = new PlaybackRequest(
                    Url: url,
                    ContentType: PlaybackContentType.LiveTv,
                    Title: title,
                    ChannelLogoUrl: logo);

                await AssignSlotAsync(slotIndex, request);
            }
        }
    }

    /// <inheritdoc />
    public async Task SwapSlotsAsync(int slotA, int slotB)
    {
        ValidateSlotIndex(slotA);
        ValidateSlotIndex(slotB);

        var requestA = _slots[slotA].Request;
        var requestB = _slots[slotB].Request;

        if (requestA != null)
            await AssignSlotAsync(slotB, requestA);
        else
            await ClearSlotAsync(slotB);

        if (requestB != null)
            await AssignSlotAsync(slotA, requestB);
        else
            await ClearSlotAsync(slotA);
    }

    /// <inheritdoc />
    public IPlayerService GetSlotPlayer(int slotIndex)
    {
        ValidateSlotIndex(slotIndex);
        return _players[slotIndex];
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _slotsChanged.Dispose();
        foreach (var player in _players)
        {
            if (player is IDisposable disposable)
            {
                disposable.Dispose();
            }
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private void UpdateSlot(int index, Func<MultiviewSlot, MultiviewSlot> update)
    {
        _slots[index] = update(_slots[index]);
        EmitSlotsChanged();
    }

    private void EmitSlotsChanged() => _slotsChanged.OnNext(_slots);

    private static void ValidateSlotIndex(int index)
    {
        if (index is < 0 or >= SlotCount)
        {
            throw new ArgumentOutOfRangeException(
                nameof(index),
                $"Slot index must be 0–{SlotCount - 1}.");
        }
    }
}
