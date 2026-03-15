using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;

using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;
using Crispy.Application.Security;
using Crispy.UI.Navigation;

namespace Crispy.UI.ViewModels;

/// <summary>
/// Message published when a source is successfully saved.
/// </summary>
/// <param name="Source">The newly created source.</param>
public record SourceSavedMessage(Source Source);

/// <summary>
/// ViewModel for the Add Source wizard.
/// </summary>
public partial class AddSourceViewModel : ViewModelBase
{
    private readonly ISourceRepository _sourceRepository;
    private readonly ICredentialEncryption _credentialEncryption;
    private readonly IMessenger _messenger;
    private readonly INavigationService _navigationService;

    /// <summary>
    /// Creates a new AddSourceViewModel.
    /// </summary>
    public AddSourceViewModel(
        ISourceRepository sourceRepository,
        ICredentialEncryption credentialEncryption,
        IMessenger messenger,
        INavigationService navigationService)
    {
        Title = "Add Source";
        _sourceRepository = sourceRepository;
        _credentialEncryption = credentialEncryption;
        _messenger = messenger;
        _navigationService = navigationService;
        _selectedSourceType = SourceType.M3U;
    }

    /// <summary>
    /// Display name for the source.
    /// </summary>
    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(SaveCommand))]
    private string _name = string.Empty;

    /// <summary>
    /// URL / server address.
    /// </summary>
    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(SaveCommand))]
    private string _url = string.Empty;

    /// <summary>
    /// The selected source type.
    /// </summary>
    [ObservableProperty]
    private SourceType _selectedSourceType;

    /// <summary>
    /// Optional username (used for Xtream Codes, Stalker Portal, Jellyfin).
    /// </summary>
    [ObservableProperty]
    private string _username = string.Empty;

    /// <summary>
    /// Optional password (used for Xtream Codes, Stalker Portal, Jellyfin).
    /// </summary>
    [ObservableProperty]
    private string _password = string.Empty;

    /// <summary>
    /// Whether the save operation is in progress.
    /// </summary>
    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(SaveCommand))]
    private bool _isSaving;

    /// <summary>
    /// Error message to display, or null if no error.
    /// </summary>
    [ObservableProperty]
    private string? _errorMessage;

    /// <summary>
    /// All available source types for the ComboBox.
    /// </summary>
    public SourceType[] AvailableSourceTypes { get; } =
        [SourceType.M3U, SourceType.XtreamCodes, SourceType.StalkerPortal, SourceType.Jellyfin];

    /// <summary>
    /// Whether credential fields should be visible (all types except M3U).
    /// </summary>
    public bool AreCredentialsVisible => SelectedSourceType != SourceType.M3U;

    partial void OnSelectedSourceTypeChanged(SourceType value)
    {
        OnPropertyChanged(nameof(AreCredentialsVisible));
    }

    private bool CanSave() =>
        !IsSaving &&
        !string.IsNullOrWhiteSpace(Name) &&
        !string.IsNullOrWhiteSpace(Url);

    /// <summary>
    /// Saves the new source and navigates back.
    /// </summary>
    [RelayCommand(CanExecute = nameof(CanSave))]
    private async Task SaveAsync()
    {
        ErrorMessage = null;
        IsSaving = true;

        try
        {
            var source = new Source
            {
                Name = Name.Trim(),
                Url = Url.Trim(),
                SourceType = SelectedSourceType,
                IsEnabled = true,
            };

            if (!string.IsNullOrWhiteSpace(Username))
            {
                source.EncryptedUsername = _credentialEncryption.Encrypt(Username);
            }

            if (!string.IsNullOrWhiteSpace(Password))
            {
                source.EncryptedPassword = _credentialEncryption.Encrypt(Password);
            }

            var created = await _sourceRepository.CreateAsync(source);
            _messenger.Send(new SourceSavedMessage(created));

            if (_navigationService.CanGoBack)
            {
                _navigationService.GoBack();
            }
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Failed to save source: {ex.Message}";
        }
        finally
        {
            IsSaving = false;
        }
    }

    /// <summary>
    /// Cancels and navigates back without saving.
    /// </summary>
    [RelayCommand]
    private void Cancel()
    {
        if (_navigationService.CanGoBack)
        {
            _navigationService.GoBack();
        }
    }
}
