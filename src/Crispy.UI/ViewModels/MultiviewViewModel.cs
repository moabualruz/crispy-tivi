using System.Collections.ObjectModel;

using Avalonia.Threading;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the Multiview 4-up grid screen.
/// Manages slot state, audio routing, fullscreen expansion, drag-to-swap,
/// and saved layout operations.
///
/// Satisfies PLR-29, PLR-30, PLR-31, PLR-32.
/// </summary>
public partial class MultiviewViewModel : ViewModelBase, IDisposable
{
    private readonly IMultiviewService _multiviewService;
    private IDisposable? _slotsSubscription;

    // ─── Slots ───────────────────────────────────────────────────────────────

    /// <summary>Observable collection of slot view-models (always 4 items).</summary>
    public ObservableCollection<MultiviewSlotViewModel> Slots { get; } = [];

    // ─── Layout state ────────────────────────────────────────────────────────

    [ObservableProperty]
    private bool _isGridMode = true;

    [ObservableProperty]
    private int _expandedSlotIndex = -1;

    // ─── Saved layouts ───────────────────────────────────────────────────────

    public ObservableCollection<SavedLayout> SavedLayouts { get; } = [];

    [ObservableProperty]
    private string _newLayoutName = string.Empty;

    // ─── Constructor ─────────────────────────────────────────────────────────

    public MultiviewViewModel(IMultiviewService multiviewService)
    {
        Title = "Multiview";
        _multiviewService = multiviewService;

        // Initialise slot view-models from current service state
        foreach (var slot in multiviewService.Slots)
        {
            var player = multiviewService.GetSlotPlayer(slot.SlotIndex);
            Slots.Add(new MultiviewSlotViewModel(slot, player));
        }

        _slotsSubscription = multiviewService.SlotsChanged.Subscribe(OnSlotsChanged);

        _ = LoadSavedLayoutsAsync();
    }

    // ─── State sync ──────────────────────────────────────────────────────────

    private void OnSlotsChanged(IReadOnlyList<MultiviewSlot> slots)
    {
        RunOnUiThread(() =>
        {
            for (var i = 0; i < slots.Count && i < Slots.Count; i++)
            {
                Slots[i].Update(slots[i]);
            }

            var expanded = slots.FirstOrDefault(s => s.IsExpanded);
            IsGridMode = expanded is null;
            ExpandedSlotIndex = expanded?.SlotIndex ?? -1;
        });
    }

    private async Task LoadSavedLayoutsAsync()
    {
        var layouts = await _multiviewService.GetSavedLayoutsAsync();
        RunOnUiThread(() =>
        {
            SavedLayouts.Clear();
            foreach (var layout in layouts)
            {
                SavedLayouts.Add(layout);
            }
        });
    }

    // ─── Commands ────────────────────────────────────────────────────────────

    [RelayCommand]
    private async Task ClearSlotAsync(int slotIndex) =>
        await _multiviewService.ClearSlotAsync(slotIndex);

    [RelayCommand]
    private async Task SetAudioSlotAsync(int slotIndex) =>
        await _multiviewService.SetActiveAudioSlotAsync(slotIndex);

    [RelayCommand]
    private async Task ExpandSlotAsync(int slotIndex) =>
        await _multiviewService.ExpandSlotAsync(slotIndex);

    [RelayCommand]
    private async Task CollapseAsync() =>
        await _multiviewService.CollapseToGridAsync();

    [RelayCommand]
    private async Task SaveLayoutAsync()
    {
        var name = NewLayoutName.Trim();
        if (string.IsNullOrEmpty(name))
        {
            return;
        }

        await _multiviewService.SaveLayoutAsync(name);
        NewLayoutName = string.Empty;
        await LoadSavedLayoutsAsync();
    }

    [RelayCommand]
    private async Task LoadLayoutAsync(string layoutId)
    {
        await _multiviewService.LoadLayoutAsync(layoutId);
    }

    [RelayCommand]
    private async Task SwapSlotsAsync((int SlotA, int SlotB) args) =>
        await _multiviewService.SwapSlotsAsync(args.SlotA, args.SlotB);

    // ─── Channel assign request (raised for UI to handle dialog) ─────────────

    /// <summary>
    /// Raised when the user requests to assign a channel to a slot.
    /// UI code-behind should open a channel-picker and call
    /// IMultiviewService.AssignSlotAsync with the chosen request.
    /// </summary>
    public event EventHandler<int>? AssignChannelRequested;

    [RelayCommand]
    private void AssignChannel(int slotIndex) =>
        AssignChannelRequested?.Invoke(this, slotIndex);

    // ─── Cleanup ─────────────────────────────────────────────────────────────

    public void Dispose() => _slotsSubscription?.Dispose();

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static void RunOnUiThread(Action action)
    {
        try
        {
            if (Dispatcher.UIThread.CheckAccess())
                action();
            else
                Dispatcher.UIThread.Post(action);
        }
        catch (Exception)
        {
            action();
        }
    }
}

// ─── Slot ViewModel ──────────────────────────────────────────────────────────

/// <summary>
/// Wraps a MultiviewSlot for per-slot data binding in the Multiview grid.
/// </summary>
public partial class MultiviewSlotViewModel : ObservableObject
{
    private readonly IPlayerService _playerService;

    [ObservableProperty]
    private int _slotIndex;

    [ObservableProperty]
    private bool _isActive;

    [ObservableProperty]
    private bool _isAudioActive;

    [ObservableProperty]
    private bool _isExpanded;

    [ObservableProperty]
    private string? _channelName;

    [ObservableProperty]
    private string? _channelLogoUrl;

    /// <summary>Exposes the backing player service so code-behind can wire VideoView.</summary>
    public IPlayerService PlayerService => _playerService;

    public MultiviewSlotViewModel(MultiviewSlot slot, IPlayerService playerService)
    {
        _playerService = playerService;
        Update(slot);
    }

    /// <summary>Synchronises all properties from a new slot snapshot.</summary>
    public void Update(MultiviewSlot slot)
    {
        SlotIndex = slot.SlotIndex;
        IsActive = slot.IsActive;
        IsAudioActive = slot.IsAudioActive;
        IsExpanded = slot.IsExpanded;
        ChannelName = slot.Request?.Title;
        ChannelLogoUrl = slot.Request?.ChannelLogoUrl;
    }
}
