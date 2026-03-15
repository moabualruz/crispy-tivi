using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.VisualTree;

namespace Crispy.UI.Views;

/// <summary>
/// Two-panel settings view with category list and settings content.
/// </summary>
public partial class SettingsView : UserControl
{
    /// <summary>
    /// Creates a new SettingsView.
    /// </summary>
    public SettingsView()
    {
        InitializeComponent();
    }

    /// <inheritdoc />
    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);

        // Determine the "forward" key based on FlowDirection (RTL-aware)
        var forwardKey = FlowDirection == Avalonia.Media.FlowDirection.RightToLeft
            ? Key.Left
            : Key.Right;

        if ((e.Key == forwardKey || e.Key == Key.Enter) && IsFocusInCategoryList())
        {
            MoveFocusToRightPanel();
            e.Handled = true;
        }
    }

    private bool IsFocusInCategoryList()
    {
        var focused = TopLevel.GetTopLevel(this)?.FocusManager?.GetFocusedElement() as Visual;
        if (focused is null)
        {
            return false;
        }

        // Find the category ListBox (first ListBox inside the first column)
        var categoryList = this.FindDescendantOfType<Controls.SettingsCategoryList>();
        return categoryList is not null
            && (focused == categoryList
                || focused.GetVisualAncestors().Contains(categoryList));
    }

    private void MoveFocusToRightPanel()
    {
        // The right panel is the ScrollViewer in column 1
        var scrollViewer = this.GetVisualDescendants()
            .OfType<ScrollViewer>()
            .FirstOrDefault();

        if (scrollViewer is null)
        {
            return;
        }

        // Find first focusable control inside the scroll viewer
        var focusable = scrollViewer
            .GetVisualDescendants()
            .OfType<InputElement>()
            .FirstOrDefault(el => el.Focusable && el.IsEffectivelyVisible);

        focusable?.Focus(NavigationMethod.Directional);
    }
}
