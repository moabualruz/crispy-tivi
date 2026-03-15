using Avalonia;
using Avalonia.Headless;
using Avalonia.Themes.Fluent;

using Crispy.Application.Configuration;
using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Application.Services;
using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;
using Crispy.UI.Services;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

using NSubstitute;

namespace Crispy.UI.Tests;

/// <summary>
/// Minimal Avalonia application for headless UI tests.
/// Provides a DI container with NSubstitute mocks for all ViewModel dependencies.
/// Services are singletons so tests can retrieve and re-configure mocks via <see cref="Services"/>.
/// </summary>
public class TestApp : Avalonia.Application
{
    /// <summary>
    /// Avalonia app builder discovered by convention from <c>[AvaloniaFact]</c> tests.
    /// Must be a public static method returning <see cref="AppBuilder"/> named exactly
    /// <c>BuildAvaloniaApp</c> on the Application type for the headless runner to find it.
    /// </summary>
    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<TestApp>()
            .UseHeadless(new AvaloniaHeadlessPlatformOptions());

    private static IServiceProvider? _services;

    /// <summary>
    /// The test DI container. Available after <see cref="OnFrameworkInitializationCompleted"/> runs.
    /// </summary>
    public static IServiceProvider Services =>
        _services ?? throw new InvalidOperationException(
            "TestApp has not been initialized. Ensure the test uses [AvaloniaFact].");

    /// <inheritdoc />
    public override void Initialize()
    {
        // No AXAML — add FluentTheme programmatically so headless controls can render.
        Styles.Add(new FluentTheme());
    }

    /// <inheritdoc />
    public override void OnFrameworkInitializationCompleted()
    {
        _services = BuildTestServices();
        base.OnFrameworkInitializationCompleted();
    }

    private static ServiceProvider BuildTestServices()
    {
        var services = new ServiceCollection();

        // ── Navigation ────────────────────────────────────────────────────────
        var navigationService = Substitute.For<INavigationService>();
        services.AddSingleton(navigationService);

        // ── Theme ─────────────────────────────────────────────────────────────
        var themeService = Substitute.For<IThemeService>();
        themeService.CurrentTheme.Returns(Domain.Enums.ThemeVariant.Dark);
        themeService.SelectedAccentIndex.Returns(0);
        themeService.IsReducedMotion.Returns(false);
        themeService.InitializeAsync().Returns(Task.CompletedTask);
        services.AddSingleton(themeService);

        // ── Localization ──────────────────────────────────────────────────────
        var localizationService = Substitute.For<ILocalizationService>();
        localizationService.CurrentLocale.Returns("en");
        localizationService.IsRightToLeft.Returns(false);
        localizationService.InitializeAsync().Returns(Task.CompletedTask);
        services.AddSingleton(localizationService);

        // ── Settings ──────────────────────────────────────────────────────────
        var settingsService = Substitute.For<ISettingsService>();
        settingsService.GetThemeAsync(Arg.Any<int?>())
            .Returns(Domain.Enums.ThemeVariant.Dark);
        services.AddSingleton(settingsService);

        // ── Player ────────────────────────────────────────────────────────────
        var playerService = Substitute.For<IPlayerService>();
        playerService.State.Returns(PlayerState.Empty);
        playerService.StateChanged.Returns(new TestSubject<PlayerState>());
        playerService.AudioSamples.Returns(new TestSubject<float[]>());
        playerService.AudioTracks.Returns([]);
        playerService.SubtitleTracks.Returns([]);
        services.AddSingleton(playerService);

        // ── Timeshift ─────────────────────────────────────────────────────────
        var timeshiftService = Substitute.For<ITimeshiftService>();
        timeshiftService.StateChanged.Returns(new TestSubject<TimeshiftState>());
        timeshiftService.State.Returns(new TimeshiftState(
            BufferDuration: TimeSpan.Zero,
            Offset: TimeSpan.Zero,
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: string.Empty,
            IsAtLiveEdge: true,
            IsBufferFull: false));
        services.AddSingleton(timeshiftService);

        // ── Sleep Timer ───────────────────────────────────────────────────────
        var sleepTimerService = Substitute.For<ISleepTimerService>();
        sleepTimerService.RemainingChanged.Returns(new TestSubject<TimeSpan?>());
        sleepTimerService.Remaining.Returns((TimeSpan?)null);
        services.AddSingleton(sleepTimerService);

        // ── Repositories ──────────────────────────────────────────────────────
        var sourceRepository = Substitute.For<ISourceRepository>();
        sourceRepository.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        services.AddSingleton(sourceRepository);

        var channelRepository = Substitute.For<IChannelRepository>();
        channelRepository.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));
        services.AddSingleton(channelRepository);

        // ── Feature Flags ─────────────────────────────────────────────────────
        services.AddSingleton<IOptions<FeatureFlagOptions>>(
            Options.Create(new FeatureFlagOptions()));

        // ── ViewModels ────────────────────────────────────────────────────────
        services.AddTransient<HomeViewModel>();
        services.AddTransient<LiveTvViewModel>();
        services.AddTransient<SourcesViewModel>();
        services.AddTransient<SettingsViewModel>();
        services.AddTransient<PlayerViewModel>();

        return services.BuildServiceProvider();
    }
}
