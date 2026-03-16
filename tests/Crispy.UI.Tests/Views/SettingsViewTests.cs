using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Input;

using Crispy.UI.Tests.Helpers;
using Crispy.UI.Themes;
using Crispy.UI.Views;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Views;

/// <summary>
/// Tests for SettingsView code-behind (OnKeyDown, IsFocusInCategoryList,
/// MoveFocusToRightPanel) and DesignTokens constants surfaced by the settings UI.
/// </summary>
[Trait("Category", "UI")]
public class SettingsViewTests
{
    // ── DesignTokens — surfaced in the settings accent palette and theme panels ──

    [Fact]
    public void AccentPalette_HasNineColors()
    {
        DesignTokens.AccentPalette.Should().HaveCount(9,
            "settings UI must expose exactly 9 accent color swatches");
    }

    [Fact]
    public void SpacingTokens_AreCorrect()
    {
        DesignTokens.SpacingXs.Should().Be(4);
        DesignTokens.SpacingSm.Should().Be(8);
        DesignTokens.SpacingMd.Should().Be(16);
        DesignTokens.SpacingLg.Should().Be(24);
    }

    [Fact]
    public void RadiusMd_IsEight()
    {
        DesignTokens.RadiusMd.Should().Be(8);
    }

    [Fact]
    public void DefaultDuration_Is250ms()
    {
        DesignTokens.DefaultDuration.Should().Be(TimeSpan.FromMilliseconds(250));
    }

    // ── SettingsView rendering ─────────────────────────────────────────────────

    [AvaloniaFact]
    public void SettingsView_RendersWithoutException_WithNullDataContext()
    {
        var view = new SettingsView();
        var window = new Window { Content = view, Width = 1280, Height = 720 };

        var act = () => window.Show();

        act.Should().NotThrow("SettingsView must render without a DataContext");
        window.Close();
    }

    [AvaloniaFact]
    public void SettingsView_OnKeyDown_RightArrow_DoesNotThrow_WhenNoFocusedElement()
    {
        var view = new SettingsView { Focusable = true };
        var window = new Window { Content = view, Width = 1280, Height = 720 };
        window.Show();

        view.Focus();

        // Right arrow with no category list focused — must not throw
        var act = () =>
            window.KeyPressQwerty(PhysicalKey.ArrowRight, RawInputModifiers.None);

        act.Should().NotThrow("Right arrow key must be handled gracefully when category list has no focus");
        window.Close();
    }

    [AvaloniaFact]
    public void SettingsView_OnKeyDown_EnterKey_DoesNotThrow()
    {
        var view = new SettingsView { Focusable = true };
        var window = new Window { Content = view, Width = 1280, Height = 720 };
        window.Show();

        view.Focus();

        var act = () =>
            window.KeyPressQwerty(PhysicalKey.Enter, RawInputModifiers.None);

        act.Should().NotThrow("Enter key must be handled gracefully");
        window.Close();
    }

    [AvaloniaFact]
    public void SettingsView_OnKeyDown_UnrelatedKey_DoesNotThrow()
    {
        var view = new SettingsView { Focusable = true };
        var window = new Window { Content = view, Width = 1280, Height = 720 };
        window.Show();

        view.Focus();

        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.Tab, RawInputModifiers.None);
            window.KeyPressQwerty(PhysicalKey.Escape, RawInputModifiers.None);
            window.KeyPressQwerty(PhysicalKey.Space, RawInputModifiers.None);
        };

        act.Should().NotThrow("unrelated keys must fall through without error");
        window.Close();
    }

    [AvaloniaFact]
    public void SettingsView_OnKeyDown_LeftArrow_DoesNotThrow_WhenRtl()
    {
        var view = new SettingsView
        {
            Focusable = true,
            FlowDirection = Avalonia.Media.FlowDirection.RightToLeft
        };
        var window = new Window { Content = view, Width = 1280, Height = 720 };
        window.Show();

        view.Focus();

        // In RTL mode Left is the "forward" key
        var act = () =>
            window.KeyPressQwerty(PhysicalKey.ArrowLeft, RawInputModifiers.None);

        act.Should().NotThrow("Left arrow in RTL mode must be handled gracefully");
        window.Close();
    }
}
